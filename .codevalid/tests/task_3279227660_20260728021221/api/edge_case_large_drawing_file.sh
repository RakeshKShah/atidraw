#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
AUTH_COOKIE="${AUTH_COOKIE:-${COOKIE_HEADER:-}}"
DRAWING_FILE="/tmp/edge_case_large_drawing_file_drawing_${CASE_SUFFIX}.png"
HEADERS_FILE="/tmp/edge_case_large_drawing_file_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/edge_case_large_drawing_file_body_${CASE_SUFFIX}.bin"
REQUEST_BODY_LOG="/tmp/edge_case_large_drawing_file_request_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_LOG"
}
trap cleanup_files EXIT

# Given
SHORT_GIVEN="prepare authenticated request with a large drawing payload"
echo "STEP: Given — ${SHORT_GIVEN}"
[ -n "$AUTH_COOKIE" ] || { echo "ASSERTION_FAILED: expected AUTH_COOKIE or COOKIE_HEADER env var for authenticated request"; exit 1; }
dd if=/dev/zero of="$DRAWING_FILE" bs=1024 count=2048 >/dev/null 2>&1
printf '%s\n' 'multipart/form-data field: drawing=@<generated ~2MiB png payload>' > "$REQUEST_BODY_LOG"

# When
SHORT_WHEN="submit POST /api/generate with large drawing file"
echo "STEP: When — ${SHORT_WHEN}"
echo 'REQUEST_HEADERS:'
printf 'Cookie: %s\n' "$AUTH_COOKIE"
echo 'REQUEST_BODY:'
cat "$REQUEST_BODY_LOG"
code="$(curl -sS -X POST "$BASE_URL/api/generate" \
  -H "Cookie: $AUTH_COOKIE" \
  -F "drawing=@${DRAWING_FILE};type=image/png;filename=large-${CASE_SUFFIX}.png" \
  -D "$HEADERS_FILE" \
  -o "$BODY_FILE" \
  -w '%{http_code}')"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
wc -c < "$BODY_FILE"
printf ' bytes\n'
echo "RESPONSE_STATUS: $code"

# Then
SHORT_THEN="assert large input yields either success or a clear server-side failure"
echo "STEP: Then — ${SHORT_THEN}"
case "$code" in
  200)
    grep -i '^content-type: image/' "$HEADERS_FILE" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected image content-type header on HTTP 200"; exit 1; }
    body_size="$(wc -c < "$BODY_FILE" | tr -d ' ')"
    [ "$body_size" -gt 0 ] || { echo "ASSERTION_FAILED: expected non-empty binary body on HTTP 200"; exit 1; }
    ;;
  400|413|422|500|504)
    body_size="$(wc -c < "$BODY_FILE" | tr -d ' ')"
    [ "$body_size" -gt 0 ] || { echo "ASSERTION_FAILED: expected explanatory error body for large file failure"; exit 1; }
    ;;
  *)
    echo "ASSERTION_FAILED: expected HTTP 200/400/413/422/500/504 for large drawing got ${code}"
    exit 1
    ;;
esac

echo 'CODEVALID_TEST_ASSERTION_OK:edge_case_large_drawing_file'
