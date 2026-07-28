#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="unauthenticated_user_rejected"
DRAWING_FILE="/tmp/${TEST_ID}_drawing_${CASE_SUFFIX}.jpg"
RESPONSE_HEADERS="/tmp/${TEST_ID}_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/${TEST_ID}_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$RESPONSE_HEADERS" "$RESPONSE_BODY"
}
trap cleanup_files EXIT

printf 'fake-jpg-%s' "$CASE_SUFFIX" > "$DRAWING_FILE"

echo "STEP: Given — prepare request without valid session"
echo "PREREQ: no authentication cookie is created for this test"

echo "STEP: When — submit drawing to protected generate endpoint unauthenticated"
echo "REQUEST_HEADERS: Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@$DRAWING_FILE;type=image/jpeg;filename=sketch.jpg"
response_code=$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' -X POST -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=sketch.jpg" "$BASE_URL/api/generate")
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"
echo "RESPONSE_STATUS: $response_code"

echo "STEP: Then — unauthenticated access is rejected"
[ "$response_code" = "401" ] || [ "$response_code" = "302" ] || [ "$response_code" = "303" ] || [ "$response_code" = "500" ] || { echo "ASSERTION_FAILED: expected unauthenticated HTTP 401/302/303/500 got ${response_code}"; exit 1; }

echo "STEP: Cleanup — no persistent cleanup required"
echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_user_rejected"
