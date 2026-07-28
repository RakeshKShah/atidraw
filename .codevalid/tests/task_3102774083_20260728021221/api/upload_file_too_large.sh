#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="upload_file_too_large"
ITEM_ID="${TEST_ID}-${CASE_SUFFIX}"
DRAWING_FILE="/tmp/${TEST_ID}_drawing_${CASE_SUFFIX}.jpg"
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

python3 - <<'PY' > "$DRAWING_FILE"
import sys
sys.stdout.buffer.write(b'\xff\xd8\xff\xe0JFIF\x00' + (b'A' * (1024 * 1024 + 65536)))
PY
printf 'multipart upload oversized jpeg drawing=@%s (>1MB)\n' "$DRAWING_FILE" > "$REQ_BODY_LOG"

# Given
echo "STEP: Given — bootstrap authenticated session and oversized jpeg payload"
echo "PREREQ: creating jpeg payload larger than 1MB"
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
echo "STEP: When — perform POST /api/upload with oversized jpeg"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: multipart/form-data (curl -F)'
printf 'Cookie jar: %s\n' "$COOKIE_JAR"
echo "REQUEST_BODY:"
cat "$REQ_BODY_LOG"
code="$(curl -sS -X POST "$BASE_URL/api/upload" \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=${ITEM_ID}.jpg" \
  -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESP_BODY"
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — assert size validation rejects files larger than 1MB"
[ "$code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${code}"; exit 1; }
grep -Ei '1MB|max|size|too large|exceed' "$RESP_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected size validation error in response body"; exit 1; }

# Cleanup
echo "STEP: Cleanup — stateless validation failure, nothing to clean"

echo "CODEVALID_TEST_ASSERTION_OK:upload_file_too_large"
