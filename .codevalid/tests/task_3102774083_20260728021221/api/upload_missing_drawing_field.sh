#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="upload_missing_drawing_field"
ITEM_ID="${TEST_ID}-${CASE_SUFFIX}"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
AUTH_HEADERS="/tmp/${TEST_ID}_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY="/tmp/${TEST_ID}_auth_body_${CASE_SUFFIX}.txt"
RESP_HEADERS="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
REQ_BODY_LOG="/tmp/${TEST_ID}_request_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$AUTH_HEADERS" "$AUTH_BODY" "$RESP_HEADERS" "$RESP_BODY" "$REQ_BODY_LOG"
}
trap cleanup_files EXIT

printf 'multipart request without drawing field marker=%s\n' "$ITEM_ID" > "$REQ_BODY_LOG"

# Given
echo "STEP: Given — bootstrap authenticated session but intentionally omit drawing field"
echo "PREREQ: requesting anonymous session via public auth endpoint"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: application/json'
echo "REQUEST_BODY:"
printf '%s\n' '{}'
auth_code="$(curl -sS -X POST "$BASE_URL/auth/anonymous" \
  -H 'Content-Type: application/json' \
  -d '{}' \
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
echo "STEP: When — perform POST /api/upload without drawing form field"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: multipart/form-data (curl -F)'
printf 'Cookie jar: %s\n' "$COOKIE_JAR"
echo "REQUEST_BODY:"
cat "$REQ_BODY_LOG"
code="$(curl -sS -X POST "$BASE_URL/api/upload" \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -F "note=${ITEM_ID}-no-drawing-field" \
  -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
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
echo "STEP: Cleanup — stateless validation failure, nothing to clean"

echo "CODEVALID_TEST_ASSERTION_OK:upload_missing_drawing_field"
