#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
AUTH_COOKIE="${AUTH_COOKIE:-${COOKIE_HEADER:-}}"
HEADERS_FILE="/tmp/validation_missing_drawing_field_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/validation_missing_drawing_field_body_${CASE_SUFFIX}.txt"
REQUEST_BODY_LOG="/tmp/validation_missing_drawing_field_request_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_LOG"
}
trap cleanup_files EXIT

# Given
SHORT_GIVEN="prepare authenticated multipart request without drawing field"
echo "STEP: Given — ${SHORT_GIVEN}"
[ -n "$AUTH_COOKIE" ] || { echo "ASSERTION_FAILED: expected AUTH_COOKIE or COOKIE_HEADER env var for authenticated request"; exit 1; }
printf '%s\n' 'multipart/form-data request intentionally omits drawing field' > "$REQUEST_BODY_LOG"

# When
SHORT_WHEN="submit POST /api/generate without drawing field"
echo "STEP: When — ${SHORT_WHEN}"
echo 'REQUEST_HEADERS:'
printf 'Cookie: %s\n' "$AUTH_COOKIE"
echo 'REQUEST_BODY:'
cat "$REQUEST_BODY_LOG"
code="$(curl -sS -X POST "$BASE_URL/api/generate" \
  -H "Cookie: $AUTH_COOKIE" \
  -F "note=missing-drawing-${CASE_SUFFIX}" \
  -D "$HEADERS_FILE" \
  -o "$BODY_FILE" \
  -w '%{http_code}')"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $code"

# Then
SHORT_THEN="assert request fails when drawing field is missing"
echo "STEP: Then — ${SHORT_THEN}"
[ "$code" != "200" ] || { echo "ASSERTION_FAILED: expected non-200 when drawing field is missing"; exit 1; }
body_size="$(wc -c < "$BODY_FILE" | tr -d ' ')"
[ "$body_size" -gt 0 ] || { echo "ASSERTION_FAILED: expected non-empty error response body"; exit 1; }

echo 'CODEVALID_TEST_ASSERTION_OK:validation_missing_drawing_field'
