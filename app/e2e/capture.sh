#!/usr/bin/env bash
# Copies the latest successful run of each feed from a Caizen data bucket
# into app/e2e/testdata/raw/, keeping the raw/ layout. Records whose
# ancestors include any EXCLUDE_ANCESTORS entry are dropped. The capture
# fails if Poltergeist (github.com/ghostsecurity/poltergeist) finds a secret
# that is not in app/e2e/testdata/poltergeist-allow.json.
#
# Usage:
#   BUCKET=<data bucket> [EXCLUDE_ANCESTORS=folders/123,folders/456] \
#   [FEEDS="gcp-cai-resource gcp-cai-iam-policy gcp-cai-org-policy"] \
#   app/e2e/capture.sh
set -euo pipefail

: "${BUCKET:?Set BUCKET to the Caizen data bucket}"
FEEDS="${FEEDS:-gcp-cai-resource gcp-cai-iam-policy gcp-cai-org-policy oci-image gcp-aa-vulnerability gcp-aa-build gcp-aa-discovery gcp-aa-package}"
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

  if [ "${EXCLUDE_JSON}" != "[]" ] && [ -d "${OUT}/${rel}/data" ]; then
    find "${OUT}/${rel}/data" -type f | while read -r f; do
      jq -c --argjson ex "${EXCLUDE_JSON}" \
        'select(any((.ancestors // [])[]; IN($ex[])) | not)' "${f}" > "${f}.tmp"
      mv "${f}.tmp" "${f}"
    done
  fi
done

# Poltergeist exits 1 when it finds anything, so read its JSON instead of
# its exit code. A result is allowed when an allowlist entry has the same
# rule_id and path (with ingest_dt= and run= removed), and the same redacted
# value when the entry pins one.
ALLOW="${OUT}/poltergeist-allow.json"
REPORT="$(mktemp)"
trap 'rm -f "${REPORT}"' EXIT
poltergeist -no-color -format json -output "${REPORT}" "${OUT}/raw" >/dev/null 2>&1 || true
jq -e '.summary' "${REPORT}" >/dev/null || { echo "Poltergeist did not write a report" >&2; exit 1; }

unexpected="$(jq -c --slurpfile allow "${ALLOW}" --arg raw "${OUT}/raw/" '
  [.results[]?
   | .path = (.file_path | ltrimstr($raw) | sub("/ingest_dt=[^/]*/run=[^/]*"; ""))
   | . as $r
   | select(any($allow[0][]; .rule_id == $r.rule_id and .path == $r.path
       and ((.redacted // null) == null or .redacted == $r.redacted)) | not)
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
