#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="upload_consecutive_blocked"
ITEM_ID="${TEST_ID}-${CASE_SUFFIX}"
DRAWING_FILE="/tmp/${TEST_ID}_drawing_${CASE_SUFFIX}.jpg"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
AUTH_HEADERS="/tmp/${TEST_ID}_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY="/tmp/${TEST_ID}_auth_body_${CASE_SUFFIX}.txt"
FIRST_HEADERS="/tmp/${TEST_ID}_first_headers_${CASE_SUFFIX}.txt"
FIRST_BODY="/tmp/${TEST_ID}_first_body_${CASE_SUFFIX}.txt"
RESP_HEADERS="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
REQ_BODY_LOG="/tmp/${TEST_ID}_request_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$COOKIE_JAR" "$AUTH_HEADERS" "$AUTH_BODY" "$FIRST_HEADERS" "$FIRST_BODY" "$RESP_HEADERS" "$RESP_BODY" "$REQ_BODY_LOG"
}
trap cleanup_files EXIT

printf '\377\330\377\340JFIF\000%s' "$ITEM_ID" > "$DRAWING_FILE"
printf 'multipart upload expecting same-session consecutive block drawing=@%s\n' "$DRAWING_FILE" > "$REQ_BODY_LOG"

# Given
echo "STEP: Given — bootstrap one authenticated session and create the immediately previous upload"
echo "PREREQ: creating synthetic jpeg payload for same-user consecutive upload scenario"
[ -s "$DRAWING_FILE" ] || { echo "ASSERTION_FAILED: expected drawing file to exist"; exit 1; }
echo "PREREQ: requesting anonymous session via public auth endpoint"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: application/json'
echo "REQUEST_BODY:"
printf '%s\n' '{}'
auth_code="$(curl -sS -L -X GET "$BASE_URL/auth/anonymous" \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -D "$AUTH_HEADERS" -o "$AUTH_BODY" -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$AUTH_HEADERS"
echo "RESPONSE_BODY:"
cat "$AUTH_BODY"
echo "RESPONSE_STATUS: $auth_code"
case "$auth_code" in
  200|201|204|302|303) ;;
  *) echo "ASSERTION_FAILED: expected anonymous auth bootstrap success got ${auth_code}"; exit 1 ;;
esac
[ -s "$COOKIE_JAR" ] || { echo "ASSERTION_FAILED: expected cookie jar to be populated after auth bootstrap"; exit 1; }
echo "PREREQ: performing first upload so the same session becomes the last uploader"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: multipart/form-data (curl -F)'
printf 'Cookie jar: %s\n' "$COOKIE_JAR"
echo "REQUEST_BODY:"
cat "$REQ_BODY_LOG"
first_code="$(curl -sS -X POST "$BASE_URL/api/upload" \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=${ITEM_ID}-first.jpg" \
  -D "$FIRST_HEADERS" -o "$FIRST_BODY" -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$FIRST_HEADERS"
echo "RESPONSE_BODY:"
cat "$FIRST_BODY"
echo "RESPONSE_STATUS: $first_code"
[ "$first_code" = "200" ] || { echo "ASSERTION_FAILED: expected first upload HTTP 200 got ${first_code}"; exit 1; }

# When
echo "STEP: When — perform second POST /api/upload with same authenticated session"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: multipart/form-data (curl -F)'
printf 'Cookie jar: %s\n' "$COOKIE_JAR"
echo "REQUEST_BODY:"
cat "$REQ_BODY_LOG"
code="$(curl -sS -X POST "$BASE_URL/api/upload" \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=${ITEM_ID}-second.jpg" \
  -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESP_BODY"
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — assert consecutive upload is rejected for the same session"
[ "$code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${code}"; exit 1; }
grep -F 'You cannot upload two drawings in a row. Please wait for someone else to draw an image.' "$RESP_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected consecutive upload rejection message"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no public API cleanup available for uploaded blob artifacts"

echo "CODEVALID_TEST_ASSERTION_OK:upload_consecutive_blocked"
