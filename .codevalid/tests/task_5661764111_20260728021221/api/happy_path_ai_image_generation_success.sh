#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="happy_path_ai_image_generation_success"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
DRAWING_FILE="/tmp/${TEST_ID}_drawing_${CASE_SUFFIX}.png"
LOGIN_HEADERS="/tmp/${TEST_ID}_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY="/tmp/${TEST_ID}_login_body_${CASE_SUFFIX}.txt"
RESPONSE_HEADERS="/tmp/${TEST_ID}_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/${TEST_ID}_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$DRAWING_FILE" "$LOGIN_HEADERS" "$LOGIN_BODY" "$RESPONSE_HEADERS" "$RESPONSE_BODY"
}
trap cleanup_files EXIT

printf 'fake-png-%s' "$CASE_SUFFIX" > "$DRAWING_FILE"

echo "STEP: Given — bootstrap authenticated user session"
echo "PREREQ: create anonymous auth session for protected generate endpoint"
echo "REQUEST_HEADERS: Accept: */*"
echo "REQUEST_BODY: <empty>"
login_code=$(curl -sS -D "$LOGIN_HEADERS" -o "$LOGIN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" "$BASE_URL/auth/anonymous")
echo "RESPONSE_HEADERS:"
cat "$LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$LOGIN_BODY"
echo "RESPONSE_STATUS: $login_code"
[ "$login_code" = "200" ] || [ "$login_code" = "302" ] || [ "$login_code" = "303" ] || { echo "ASSERTION_FAILED: expected auth bootstrap HTTP 200/302/303 got ${login_code}"; exit 1; }

echo "STEP: When — submit drawing to AI image generation endpoint"
echo "REQUEST_HEADERS: Cookie jar=$COOKIE_JAR; Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@$DRAWING_FILE;type=image/png;filename=my-drawing.png"
response_code=$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST -F "drawing=@${DRAWING_FILE};type=image/png;filename=my-drawing.png" "$BASE_URL/api/generate")
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"
echo "RESPONSE_STATUS: $response_code"

echo "STEP: Then — generated image response includes headers and non-empty body"
[ "$response_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${response_code}"; exit 1; }
grep -iq '^x-description:' "$RESPONSE_HEADERS" || { echo "ASSERTION_FAILED: expected x-description header"; exit 1; }
grep -iq '^content-type: image/' "$RESPONSE_HEADERS" || { echo "ASSERTION_FAILED: expected image content-type header"; exit 1; }
[ -s "$RESPONSE_BODY" ] || { echo "ASSERTION_FAILED: expected non-empty generated image body"; exit 1; }

echo "STEP: Cleanup — no persistent cleanup required"
echo "CODEVALID_TEST_ASSERTION_OK:happy_path_ai_image_generation_success"
