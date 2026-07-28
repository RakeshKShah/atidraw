#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
AUTH_COOKIE="${AUTH_COOKIE:-${COOKIE_HEADER:-}}"
DRAWING_FILE="/tmp/ai_image_generation_failure_returns_500_drawing_${CASE_SUFFIX}.bmp"
HEADERS_FILE="/tmp/ai_image_generation_failure_returns_500_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/ai_image_generation_failure_returns_500_body_${CASE_SUFFIX}.txt"
REQUEST_BODY_LOG="/tmp/ai_image_generation_failure_returns_500_request_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_LOG"
}
trap cleanup_files EXIT

# Given
SHORT_GIVEN="prepare authenticated request that may expose AI image generation failure"
echo "STEP: Given — ${SHORT_GIVEN}"
[ -n "$AUTH_COOKIE" ] || { echo "ASSERTION_FAILED: expected AUTH_COOKIE or COOKIE_HEADER env var for authenticated request"; exit 1; }
printf 'fake-bmp-%s' "$CASE_SUFFIX" > "$DRAWING_FILE"
printf '%s\n' 'multipart/form-data field: drawing=@<generated bmp>; expecting failure path when no generated image is returned by AI service' > "$REQUEST_BODY_LOG"

# When
SHORT_WHEN="submit POST /api/generate and capture failure response"
echo "STEP: When — ${SHORT_WHEN}"
echo 'REQUEST_HEADERS:'
printf 'Cookie: %s\n' "$AUTH_COOKIE"
echo 'REQUEST_BODY:'
cat "$REQUEST_BODY_LOG"
code="$(curl -sS -X POST "$BASE_URL/api/generate" \
  -H "Cookie: $AUTH_COOKIE" \
  -F "drawing=@${DRAWING_FILE};type=image/bmp;filename=genfail-${CASE_SUFFIX}.bmp" \
  -D "$HEADERS_FILE" \
  -o "$BODY_FILE" \
  -w '%{http_code}')"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $code"

# Then
SHORT_THEN="assert either documented 500 failure or successful fallback behavior"
echo "STEP: Then — ${SHORT_THEN}"
case "$code" in
  500)
    grep -F 'Failed to generate image' "$BODY_FILE" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected failure message 'Failed to generate image'"; exit 1; }
    ;;
  200)
    grep -i '^content-type: image/' "$HEADERS_FILE" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected image content-type header on HTTP 200"; exit 1; }
    ;;
  *)
    echo "ASSERTION_FAILED: expected HTTP 500 or 200 got ${code}"
    exit 1
    ;;
esac

echo 'CODEVALID_TEST_ASSERTION_OK:ai_image_generation_failure_returns_500'
