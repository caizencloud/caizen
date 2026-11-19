#!/usr/bin/env bash
# Copies the latest successful run of each feed from a Caizen data bucket
# into app/e2e/testdata/raw/, keeping the raw/ layout. Records whose
# ancestors include any EXCLUDE_ANCESTORS entry are dropped. The capture
# fails if any file matches a credential pattern.
#
# Usage:
#   BUCKET=<data bucket> [EXCLUDE_ANCESTORS=folders/123,folders/456] \
#   [FEEDS="gcp-cai-resource gcp-cai-iam-policy gcp-cai-org-policy"] \
#   app/e2e/capture.sh
set -euo pipefail

: "${BUCKET:?Set BUCKET to the Caizen data bucket}"
FEEDS="${FEEDS:-gcp-cai-resource gcp-cai-iam-policy gcp-cai-org-policy oci-image gcp-aa-vulnerability gcp-aa-build gcp-aa-discovery gcp-aa-package}"
EXCLUDE_ANCESTORS="${EXCLUDE_ANCESTORS:-}"

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

pattern='ghu_[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
if grep -rEl "${pattern}" "${OUT}/raw"; then
  echo "Credential pattern found in the files above. Nothing should be committed." >&2
  exit 1
fi

echo "Captured into ${OUT}/raw"
