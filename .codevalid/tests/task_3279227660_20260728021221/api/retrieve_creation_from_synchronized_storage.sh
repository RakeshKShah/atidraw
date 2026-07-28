#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DRAWINGS_HEADERS="/tmp/retrieve_creation_from_synchronized_storage_headers_${CASE_SUFFIX}.txt"
DRAWINGS_BODY="/tmp/retrieve_creation_from_synchronized_storage_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWINGS_HEADERS" "$DRAWINGS_BODY"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — no additional setup is required because retrieval reads synchronized storage directly"

# When
echo "STEP: When — request saved creations from GET /api/drawings"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
code=$(curl -sS -D "$DRAWINGS_HEADERS" -o "$DRAWINGS_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/drawings")
echo "RESPONSE_HEADERS:"
cat "$DRAWINGS_HEADERS"
echo "RESPONSE_BODY:"
cat "$DRAWINGS_BODY"
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — verify creations are returned from synchronized storage with metadata"
[ "$code" = "200" ] || { echo "ASSERTION_FAILED: expected drawings retrieval HTTP 200 got ${code}"; exit 1; }
grep -F '"blobs"' "$DRAWINGS_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected drawings response to contain blobs array"; exit 1; }
grep -F 'customMetadata' "$DRAWINGS_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected drawings response to contain customMetadata"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup required for read-only retrieval"

echo "CODEVALID_TEST_ASSERTION_OK:retrieve_creation_from_synchronized_storage"
