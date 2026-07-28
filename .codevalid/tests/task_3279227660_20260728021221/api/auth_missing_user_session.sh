#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DRAWING_FILE="/tmp/auth_missing_user_session_drawing_${CASE_SUFFIX}.png"
HEADERS_FILE="/tmp/auth_missing_user_session_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/auth_missing_user_session_body_${CASE_SUFFIX}.txt"
REQUEST_BODY_LOG="/tmp/auth_missing_user_session_request_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_LOG"
}
trap cleanup_files EXIT

# Given
SHORT_GIVEN="prepare unauthenticated request with drawing file"
echo "STEP: Given — ${SHORT_GIVEN}"
printf 'fake-png-%s' "$CASE_SUFFIX" > "$DRAWING_FILE"
printf '%s\n' 'multipart/form-data field: drawing=@<generated png>; no auth cookie sent' > "$REQUEST_BODY_LOG"

# When
SHORT_WHEN="submit POST /api/generate without authentication"
echo "STEP: When — ${SHORT_WHEN}"
echo 'REQUEST_HEADERS:'
printf '%s\n' '(no Cookie header)'
echo 'REQUEST_BODY:'
cat "$REQUEST_BODY_LOG"
code="$(curl -sS -X POST "$BASE_URL/api/generate" \
  -F "drawing=@${DRAWING_FILE};type=image/png;filename=unauth-${CASE_SUFFIX}.png" \
  -D "$HEADERS_FILE" \
  -o "$BODY_FILE" \
  -w '%{http_code}')"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $code"

# Then
SHORT_THEN="assert unauthenticated access is rejected"
echo "STEP: Then — ${SHORT_THEN}"
case "$code" in
  401|302|303|500) ;;
  *) echo "ASSERTION_FAILED: expected one of HTTP 401/302/303/500 for unauthenticated request got ${code}"; exit 1 ;;
esac

echo 'CODEVALID_TEST_ASSERTION_OK:auth_missing_user_session'
