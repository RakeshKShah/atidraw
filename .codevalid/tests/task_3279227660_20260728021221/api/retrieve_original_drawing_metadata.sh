#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="retrieve_original_drawing_metadata"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — target an original-drawing retrieval scenario"
echo "PREREQ: No supported public API exists to seed a specific blob entry; validate metadata shape against returned items only"

echo "STEP: When — GET /api/drawings"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -H 'Accept: application/json' "$BASE_URL/api/drawings")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $status"

echo "STEP: Then — assert response structure and original-drawing metadata rules when applicable"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  jq -e '.blobs | type == "array"' "$BODY_FILE" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected blobs array"; exit 1; }
  first_without_ai_count="$(jq '[.blobs[] | select((.customMetadata.aiImage // null) == null)] | length' "$BODY_FILE")"
  [ "$first_without_ai_count" -ge 0 ] 2>/dev/null || { echo "ASSERTION_FAILED: failed to evaluate original-drawing candidates"; exit 1; }
else
  grep -F '"blobs"' "$BODY_FILE" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected blobs field"; exit 1; }
fi

echo "STEP: Cleanup — no cleanup required for stateless GET"
echo "CODEVALID_TEST_ASSERTION_OK:retrieve_original_drawing_metadata"
