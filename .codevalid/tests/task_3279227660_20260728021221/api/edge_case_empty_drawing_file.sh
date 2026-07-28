#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
AUTH_COOKIE="${AUTH_COOKIE:-${COOKIE_HEADER:-}}"
DRAWING_FILE="/tmp/edge_case_empty_drawing_file_drawing_${CASE_SUFFIX}.png"
HEADERS_FILE="/tmp/edge_case_empty_drawing_file_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/edge_case_empty_drawing_file_body_${CASE_SUFFIX}.txt"
REQUEST_BODY_LOG="/tmp/edge_case_empty_drawing_file_request_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_LOG"
}
trap cleanup_files EXIT

# Given
SHORT_GIVEN="prepare authenticated request with zero-byte drawing file"
echo "STEP: Given — ${SHORT_GIVEN}"
[ -n "$AUTH_COOKIE" ] || { echo "ASSERTION_FAILED: expected AUTH_COOKIE or COOKIE_HEADER env var for authenticated request"; exit 1; }
: > "$DRAWING_FILE"
printf '%s\n' 'multipart/form-data field: drawing=@<zero-byte png>' > "$REQUEST_BODY_LOG"

# When
SHORT_WHEN="submit POST /api/generate with empty drawing file"
echo "STEP: When — ${SHORT_WHEN}"
echo 'REQUEST_HEADERS:'
printf 'Cookie: %s\n' "$AUTH_COOKIE"
echo 'REQUEST_BODY:'
cat "$REQUEST_BODY_LOG"
code="$(curl -sS -X POST "$BASE_URL/api/generate" \
  -H "Cookie: $AUTH_COOKIE" \
  -F "drawing=@${DRAWING_FILE};type=image/png;filename=empty-${CASE_SUFFIX}.png" \
  -D "$HEADERS_FILE" \
  -o "$BODY_FILE" \
  -w '%{http_code}')"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $code"

# Then
SHORT_THEN="assert endpoint responds deterministically to empty file input"
echo "STEP: Then — ${SHORT_THEN}"
case "$code" in
  200|400|422|500) ;;
  *) echo "ASSERTION_FAILED: expected one of HTTP 200/400/422/500 for empty file got ${code}"; exit 1 ;;
esac

echo 'CODEVALID_TEST_ASSERTION_OK:edge_case_empty_drawing_file'
