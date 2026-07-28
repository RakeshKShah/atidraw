#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="upload_missing_drawing_field"
COOKIE_JAR="${COOKIE_JAR:-/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt}"
AUTH_HEADER="${AUTH_HEADER:-}"
REQ_BODY_LOG="/tmp/${TEST_ID}_request_body_${CASE_SUFFIX}.txt"
RESP_HEADERS="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$REQ_BODY_LOG" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

printf 'multipart upload without drawing field\n' > "$REQ_BODY_LOG"

# Given
echo "STEP: Given — prepare authenticated multipart request missing drawing field"
echo "PREREQ: requiring authenticated session while intentionally omitting drawing form field"
if [ ! -s "$COOKIE_JAR" ] && [ -z "$AUTH_HEADER" ]; then
  echo "ASSERTION_FAILED: this scenario requires COOKIE_JAR or AUTH_HEADER for an authenticated session"
  exit 1
fi

# When
echo "STEP: When — POST multipart request without drawing field to /api/upload"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: multipart/form-data (curl -F)'
if [ -n "$AUTH_HEADER" ]; then printf '%s\n' "$AUTH_HEADER"; else printf '%s\n' "Cookie jar: $COOKIE_JAR"; fi
echo "REQUEST_BODY:"
cat "$REQ_BODY_LOG"
if [ -n "$AUTH_HEADER" ]; then
  code="$(curl -sS -X POST "$BASE_URL/api/upload" -H "$AUTH_HEADER" -b "$COOKIE_JAR" -c "$COOKIE_JAR" -F "note=no-drawing-field" -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
else
  code="$(curl -sS -X POST "$BASE_URL/api/upload" -b "$COOKIE_JAR" -c "$COOKIE_JAR" -F "note=no-drawing-field" -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
fi

echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESP_BODY"
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — assert missing drawing field is rejected"
case "$code" in
  400|500) ;;
  *) echo "ASSERTION_FAILED: expected missing-field status 400 or 500 got ${code}"; exit 1 ;;
esac
grep -Ei 'drawing|field|undefined|null|error' "$RESP_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected missing drawing field error details"; exit 1; }

# Cleanup
echo "STEP: Cleanup — stateless request, nothing to clean"
echo "CODEVALID_TEST_ASSERTION_OK:upload_missing_drawing_field"
