#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="upload_file_too_large"
COOKIE_JAR="${COOKIE_JAR:-/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt}"
AUTH_HEADER="${AUTH_HEADER:-}"
DRAWING_FILE="/tmp/${TEST_ID}_drawing_${CASE_SUFFIX}.jpg"
REQ_BODY_LOG="/tmp/${TEST_ID}_request_body_${CASE_SUFFIX}.txt"
RESP_HEADERS="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$REQ_BODY_LOG" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

python3 - <<'PY' > "$DRAWING_FILE"
import sys
payload = b'\xff\xd8\xff\xe0JFIF\x00' + (b'A' * (1024 * 1024 + 60000))
sys.stdout.buffer.write(payload)
PY
printf 'multipart upload oversized jpeg @%s (>1MB)\n' "$DRAWING_FILE" > "$REQ_BODY_LOG"

# Given
echo "STEP: Given — prepare authenticated oversized jpeg upload"
echo "PREREQ: creating >1MB jpeg payload and requiring authenticated session"
[ -s "$DRAWING_FILE" ] || { echo "ASSERTION_FAILED: expected drawing file to exist"; exit 1; }
if [ ! -s "$COOKIE_JAR" ] && [ -z "$AUTH_HEADER" ]; then
  echo "ASSERTION_FAILED: this scenario requires COOKIE_JAR or AUTH_HEADER for an authenticated session"
  exit 1
fi

# When
echo "STEP: When — POST oversized drawing to /api/upload"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: multipart/form-data (curl -F)'
if [ -n "$AUTH_HEADER" ]; then printf '%s\n' "$AUTH_HEADER"; else printf '%s\n' "Cookie jar: $COOKIE_JAR"; fi
echo "REQUEST_BODY:"
cat "$REQ_BODY_LOG"
if [ -n "$AUTH_HEADER" ]; then
  code="$(curl -sS -X POST "$BASE_URL/api/upload" -H "$AUTH_HEADER" -b "$COOKIE_JAR" -c "$COOKIE_JAR" -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=drawing.jpeg" -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
else
  code="$(curl -sS -X POST "$BASE_URL/api/upload" -b "$COOKIE_JAR" -c "$COOKIE_JAR" -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=drawing.jpeg" -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
fi

echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESP_BODY"
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — assert oversized file is rejected"
[ "$code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${code}"; exit 1; }
grep -Ei '1MB|max|size|too large|exceed' "$RESP_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected size validation error in response body"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup available through public API"
echo "CODEVALID_TEST_ASSERTION_OK:upload_file_too_large"
