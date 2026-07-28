#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
AUTH_COOKIE="${AUTH_COOKIE:-${COOKIE_HEADER:-}}"
DRAWING_FILE="/tmp/happy_path_generate_ai_image_success_drawing_${CASE_SUFFIX}.png"
HEADERS_FILE="/tmp/happy_path_generate_ai_image_success_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/happy_path_generate_ai_image_success_body_${CASE_SUFFIX}.bin"
REQUEST_BODY_LOG="/tmp/happy_path_generate_ai_image_success_request_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_LOG"
}
trap cleanup_files EXIT

# Given
SHORT_GIVEN="prepare authenticated multipart request with a drawing file"
echo "STEP: Given — ${SHORT_GIVEN}"
[ -n "$AUTH_COOKIE" ] || { echo "ASSERTION_FAILED: expected AUTH_COOKIE or COOKIE_HEADER env var for authenticated request"; exit 1; }
printf 'fake-png-%s' "$CASE_SUFFIX" > "$DRAWING_FILE"
printf '%s\n' 'multipart/form-data field: drawing=@<generated png>; authenticated via Cookie header' > "$REQUEST_BODY_LOG"
echo "PREREQ: created synthetic drawing file at $DRAWING_FILE"

# When
SHORT_WHEN="submit POST /api/generate with drawing multipart form"
echo "STEP: When — ${SHORT_WHEN}"
echo 'REQUEST_HEADERS:'
printf 'Cookie: %s\n' "$AUTH_COOKIE"
echo 'REQUEST_BODY:'
cat "$REQUEST_BODY_LOG"
code="$(curl -sS -X POST "$BASE_URL/api/generate" \
  -H "Cookie: $AUTH_COOKIE" \
  -F "drawing=@${DRAWING_FILE};type=image/png;filename=happy-path-${CASE_SUFFIX}.png" \
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
SHORT_THEN="assert generated image success response"
echo "STEP: Then — ${SHORT_THEN}"
[ "$code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${code}"; exit 1; }
grep -i '^x-description:' "$HEADERS_FILE" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected x-description header"; exit 1; }
grep -i '^content-type: image/' "$HEADERS_FILE" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected image content-type header"; exit 1; }
body_size="$(wc -c < "$BODY_FILE" | tr -d ' ')"
[ "$body_size" -gt 0 ] || { echo "ASSERTION_FAILED: expected non-empty binary response body"; exit 1; }

echo 'CODEVALID_TEST_ASSERTION_OK:happy_path_generate_ai_image_success'
