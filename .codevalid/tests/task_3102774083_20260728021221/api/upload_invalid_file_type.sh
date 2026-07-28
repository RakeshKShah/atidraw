#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="upload_invalid_file_type"
ITEM_ID="${TEST_ID}-${CASE_SUFFIX}"
DRAWING_FILE="/tmp/${TEST_ID}_drawing_${CASE_SUFFIX}.png"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
AUTH_HEADERS="/tmp/${TEST_ID}_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY="/tmp/${TEST_ID}_auth_body_${CASE_SUFFIX}.txt"
RESP_HEADERS="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
REQ_BODY_LOG="/tmp/${TEST_ID}_request_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$COOKIE_JAR" "$AUTH_HEADERS" "$AUTH_BODY" "$RESP_HEADERS" "$RESP_BODY" "$REQ_BODY_LOG"
}
trap cleanup_files EXIT

printf '\211PNG\r\n\032\n%s' "$ITEM_ID" > "$DRAWING_FILE"
printf 'multipart upload png drawing=@%s expecting jpeg-only validation\n' "$DRAWING_FILE" > "$REQ_BODY_LOG"

# Given
echo "STEP: Given — bootstrap authenticated session and png payload"
echo "PREREQ: creating non-JPEG PNG payload"
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
case "$auth_code" in 200|201|204|302|303) ;; *) echo "ASSERTION_FAILED: expected anonymous auth bootstrap success got ${auth_code}"; exit 1 ;; esac
[ -s "$COOKIE_JAR" ] || { echo "ASSERTION_FAILED: expected cookie jar to be populated after auth bootstrap"; exit 1; }

# When
echo "STEP: When — perform POST /api/upload with png payload"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: multipart/form-data (curl -F)'
printf 'Cookie jar: %s\n' "$COOKIE_JAR"
echo "REQUEST_BODY:"
cat "$REQ_BODY_LOG"
code="$(curl -sS -X POST "$BASE_URL/api/upload" \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -F "drawing=@${DRAWING_FILE};type=image/png;filename=${ITEM_ID}.png" \
  -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESP_BODY"
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — assert non-JPEG file type is rejected"
[ "$code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${code}"; exit 1; }
grep -Ei 'jpeg|image/jpeg|type|invalid' "$RESP_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected jpeg type validation error"; exit 1; }

# Cleanup
echo "STEP: Cleanup — stateless validation failure, nothing to clean"

echo "CODEVALID_TEST_ASSERTION_OK:upload_invalid_file_type"
