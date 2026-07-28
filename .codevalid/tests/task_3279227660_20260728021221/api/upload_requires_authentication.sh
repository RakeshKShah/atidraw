#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DRAWING_FILE="/tmp/upload_requires_authentication_drawing_${CASE_SUFFIX}.jpg"
RESPONSE_HEADERS="/tmp/upload_requires_authentication_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/upload_requires_authentication_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$RESPONSE_HEADERS" "$RESPONSE_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340AUTH-%s\377\331' "$CASE_SUFFIX" > "$DRAWING_FILE"

# Given
echo "STEP: Given — prepare a valid JPEG drawing without any authenticated session"

# When
echo "STEP: When — call POST /api/upload without authentication"
echo "REQUEST_HEADERS: Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@$DRAWING_FILE;type=image/jpeg"
code=$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=unauth-${CASE_SUFFIX}.jpg" \
  "$BASE_URL/api/upload")
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — verify upload is rejected for unauthenticated callers"
[ "$code" = "401" ] || [ "$code" = "302" ] || [ "$code" = "303" ] || [ "$code" = "500" ] || { echo "ASSERTION_FAILED: expected unauthenticated upload HTTP 401/302/303/500 got ${code}"; exit 1; }
if [ "$code" = "401" ]; then
  grep -Ei 'auth|unauth|session|login' "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected unauthorized body to mention auth/session"; exit 1; }
fi

# Cleanup
echo "STEP: Cleanup — no cleanup required because the request was rejected"

echo "CODEVALID_TEST_ASSERTION_OK:upload_requires_authentication"
