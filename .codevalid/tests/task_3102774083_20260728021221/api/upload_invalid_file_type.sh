#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="upload_invalid_file_type"
COOKIE_JAR="${COOKIE_JAR:-/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt}"
AUTH_HEADER="${AUTH_HEADER:-}"
DRAWING_FILE="/tmp/${TEST_ID}_drawing_${CASE_SUFFIX}.png"
REQ_BODY_LOG="/tmp/${TEST_ID}_request_body_${CASE_SUFFIX}.txt"
RESP_HEADERS="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$REQ_BODY_LOG" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

printf '\211PNG\r\n\032\ninvalid-type-%s' "$CASE_SUFFIX" > "$DRAWING_FILE"
printf 'multipart upload png @%s expecting jpeg-only validation\n' "$DRAWING_FILE" > "$REQ_BODY_LOG"

# Given
echo "STEP: Given — prepare authenticated png upload"
echo "PREREQ: creating png payload and requiring authenticated session"
[ -s "$DRAWING_FILE" ] || { echo "ASSERTION_FAILED: expected drawing file to exist"; exit 1; }
if [ ! -s "$COOKIE_JAR" ] && [ -z "$AUTH_HEADER" ]; then
  echo "ASSERTION_FAILED: this scenario requires COOKIE_JAR or AUTH_HEADER for an authenticated session"
  exit 1
fi

# When
echo "STEP: When — POST png drawing to /api/upload"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: multipart/form-data (curl -F)'
if [ -n "$AUTH_HEADER" ]; then printf '%s\n' "$AUTH_HEADER"; else printf '%s\n' "Cookie jar: $COOKIE_JAR"; fi
echo "REQUEST_BODY:"
cat "$REQ_BODY_LOG"
if [ -n "$AUTH_HEADER" ]; then
  code="$(curl -sS -X POST "$BASE_URL/api/upload" -H "$AUTH_HEADER" -b "$COOKIE_JAR" -c "$COOKIE_JAR" -F "drawing=@${DRAWING_FILE};type=image/png;filename=drawing.png" -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
else
  code="$(curl -sS -X POST "$BASE_URL/api/upload" -b "$COOKIE_JAR" -c "$COOKIE_JAR" -F "drawing=@${DRAWING_FILE};type=image/png;filename=drawing.png" -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
fi

echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESP_BODY"
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — assert non-jpeg file type is rejected"
[ "$code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${code}"; exit 1; }
grep -Ei 'jpeg|image/jpeg|type|invalid' "$RESP_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected jpeg type validation error"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup available through public API"
echo "CODEVALID_TEST_ASSERTION_OK:upload_invalid_file_type"
