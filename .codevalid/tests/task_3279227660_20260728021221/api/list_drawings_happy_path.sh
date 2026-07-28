#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="list_drawings_happy_path"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — prepare to list drawings from synchronized storage"
echo "PREREQ: No direct blob seeding seam is available in this repo; exercising public retrieval API only"

echo "STEP: When — GET /api/drawings without cursor"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -H 'Accept: application/json' "$BASE_URL/api/drawings")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $status"

echo "STEP: Then — assert 200 and drawings payload shape"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  jq -e '.blobs | type == "array"' "$BODY_FILE" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected JSON body with blobs array"; exit 1; }
  jq -e '. | type == "object"' "$BODY_FILE" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected top-level JSON object"; exit 1; }
else
  grep -F '"blobs"' "$BODY_FILE" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected response body to contain blobs field"; exit 1; }
fi

echo "STEP: Cleanup — no cleanup required for stateless GET"
echo "CODEVALID_TEST_ASSERTION_OK:list_drawings_happy_path"
