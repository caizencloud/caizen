#!/usr/bin/env bash
# Copies the latest successful run of each feed from a Caizen data bucket
# into app/e2e/testdata/raw/, keeping the raw/ layout. Records whose
# ancestors include any EXCLUDE_ANCESTORS entry are dropped. The EPSS file
# is cut down to the CVEs in the captured gcp-aa-vulnerability feed, plus
# its header lines, to keep the test data small. The capture
# fails if Poltergeist (github.com/ghostsecurity/poltergeist) finds a secret
# that is not in app/e2e/testdata/poltergeist-allow.json.
#
# Usage:
#   BUCKET=<data bucket> [EXCLUDE_ANCESTORS=folders/123,folders/456] \
#   [FEEDS="gcp-cai-resource gcp-cai-iam-policy gcp-cai-org-policy"] \
#   app/e2e/capture.sh
set -euo pipefail

: "${BUCKET:?Set BUCKET to the Caizen data bucket}"
FEEDS="${FEEDS:-gcp-cai-resource gcp-cai-iam-policy gcp-cai-org-policy oci-image gcp-aa-vulnerability gcp-aa-build gcp-aa-discovery gcp-aa-package cisa-kev first-epss}"
EXCLUDE_ANCESTORS="${EXCLUDE_ANCESTORS:-}"

command -v poltergeist >/dev/null || { echo "poltergeist is not on PATH. See github.com/ghostsecurity/poltergeist/releases." >&2; exit 1; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${ROOT}/app/e2e/testdata"
EXCLUDE_JSON="$(jq -cn --arg s "${EXCLUDE_ANCESTORS}" '$s | split(",") | map(select(. != ""))')"

for feed in ${FEEDS}; do
  # Path fields: gs: / "" / bucket / raw / feed / ingest_dt=... / run=... / _SUCCESS
  latest="$(gcloud storage ls "gs://${BUCKET}/raw/${feed}/*/*/_SUCCESS" \
    | awk -F/ '{print $7 "\t" $0}' | sort | tail -1 | cut -f2)"
  if [ -z "${latest}" ]; then
    echo "No successful run for ${feed}" >&2
    exit 1
  fi

  run_dir="${latest%/_SUCCESS}"
  rel="${run_dir#gs://${BUCKET}/}"
  echo "Capturing ${rel}"

  rm -rf "${OUT}/raw/${feed}"
  mkdir -p "${OUT}/${rel}"
  gcloud storage cp --quiet "${run_dir}/_meta.json" "${run_dir}/_SUCCESS" "${OUT}/${rel}/"

  # Copy only the shards listed in _meta.json. CAI also writes a small
  # placeholder object, containing the text "folder", at every directory
  # level, and those would collide with real directories on disk.
  jq -r '.objects[]' "${OUT}/${rel}/_meta.json" | while read -r uri; do
    dest="${OUT}/${uri#gs://${BUCKET}/}"
    mkdir -p "$(dirname "${dest}")"
    gcloud storage cp --quiet "${uri}" "${dest}"
  done

  # Only CAI records carry ancestors, so only CAI feeds are filtered.
  if [ "${EXCLUDE_JSON}" != "[]" ] && [ -d "${OUT}/${rel}/data" ] && [ "${feed#gcp-cai-}" != "${feed}" ]; then
    find "${OUT}/${rel}/data" -type f | while read -r f; do
      jq -c --argjson ex "${EXCLUDE_JSON}" \
        'select(any((.ancestors // [])[]; IN($ex[])) | not)' "${f}" > "${f}.tmp"
      mv "${f}.tmp" "${f}"
    done
  fi
done

# EPSS scores every published CVE (about 400,000 rows). Keep only the CVEs
# that the captured vulnerability occurrences mention.
epss="$(find "${OUT}/raw/first-epss" -path '*/data/*.csv.gz' -type f 2>/dev/null | head -1)"
if [ -n "${epss}" ]; then
  cves="$(mktemp)"
  find "${OUT}/raw/gcp-aa-vulnerability" -name 'part-*.ndjson' -type f -exec cat {} + 2>/dev/null \
    | jq -r '.noteName | select(test("/notes/CVE-")) | sub(".*/notes/"; "")' | sort -u > "${cves}"
  gzip -dc "${epss}" | awk -F, 'NR==FNR {keep[$1]=1; next} /^#/ || $1=="cve" || ($1 in keep)' "${cves}" - \
    | gzip -n -9 > "${epss}.tmp"
  mv "${epss}.tmp" "${epss}"
  echo "EPSS cut to $(gzip -dc "${epss}" | grep -c '^CVE-') rows for $(wc -l < "${cves}" | tr -d ' ') CVEs"
  rm -f "${cves}"
fi

# Poltergeist exits 1 when it finds anything, so read its JSON instead of
# its exit code. A result is allowed when an allowlist entry matches its
# rule_id (or is "*"), matches its path exactly or by path_prefix (paths have
# ingest_dt= and run= removed), and matches its redacted value when the entry
# pins one. Prefix entries are for public third-party feeds such as KEV.
ALLOW="${OUT}/poltergeist-allow.json"
REPORT="$(mktemp)"
trap 'rm -f "${REPORT}"' EXIT
poltergeist -no-color -format json -output "${REPORT}" "${OUT}/raw" >/dev/null 2>&1 || true
jq -e '.summary' "${REPORT}" >/dev/null || { echo "Poltergeist did not write a report" >&2; exit 1; }

unexpected="$(jq -c --slurpfile allow "${ALLOW}" --arg raw "${OUT}/raw/" '
  [.results[]?
   | .path = (.file_path | ltrimstr($raw) | sub("/ingest_dt=[^/]*/run=[^/]*"; ""))
   | . as $r
   | select(any($allow[0][]; . as $a
       | ($a.rule_id == "*" or $a.rule_id == $r.rule_id)
       and ($a.path == $r.path or (($a.path_prefix // null) != null and ($r.path | startswith($a.path_prefix))))
       and (($a.redacted // null) == null or $a.redacted == $r.redacted)) | not)
   | {rule_id, path, line_number, redacted}]' "${REPORT}")"

allowed="$(jq '.summary.matches_found' "${REPORT}")"
if [ "${unexpected}" != "[]" ]; then
  echo "Poltergeist found secrets that are not in ${ALLOW}:" >&2
  echo "${unexpected}" | jq -r '.[] | "  \(.rule_id)  \(.path):\(.line_number)  \(.redacted)"' >&2
  echo "Fix the source or add a reviewed allowlist entry. Nothing should be committed." >&2
  exit 1
fi
echo "Poltergeist: ${allowed} matches, all in the allowlist"

echo "Captured into ${OUT}/raw"
