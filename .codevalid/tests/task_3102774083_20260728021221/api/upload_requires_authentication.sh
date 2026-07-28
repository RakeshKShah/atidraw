#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="upload_requires_authentication"
DRAWING_FILE="/tmp/${TEST_ID}_drawing_${CASE_SUFFIX}.jpg"
REQ_BODY_LOG="/tmp/${TEST_ID}_request_body_${CASE_SUFFIX}.txt"
RESP_HEADERS="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$REQ_BODY_LOG" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340JFIF\000unauth-%s' "$CASE_SUFFIX" > "$DRAWING_FILE"
printf 'multipart upload without authentication using @%s\n' "$DRAWING_FILE" > "$REQ_BODY_LOG"

# Given
echo "STEP: Given — prepare valid jpeg without authentication"
echo "PREREQ: creating synthetic jpeg payload and intentionally omitting session credentials"
[ -s "$DRAWING_FILE" ] || { echo "ASSERTION_FAILED: expected drawing file to exist"; exit 1; }

# When
echo "STEP: When — POST drawing to /api/upload without authentication"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: multipart/form-data (curl -F)'
echo "REQUEST_BODY:"
cat "$REQ_BODY_LOG"
code="$(curl -sS -X POST "$BASE_URL/api/upload" \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=drawing.jpeg" \
  -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"

echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESP_BODY"
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — assert unauthenticated request is rejected"
case "$code" in
  401|302|303|500) ;;
  *) echo "ASSERTION_FAILED: expected unauthenticated status 401/302/303/500 got ${code}"; exit 1 ;;
esac
grep -E 'auth|login|unauth|session|error|Unauthorized' "$RESP_BODY" >/dev/null 2>&1 || grep -Ei 'location:' "$RESP_HEADERS" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected auth-related response body or redirect header"; exit 1; }

# Cleanup
echo "STEP: Cleanup — stateless request, nothing to clean"
echo "CODEVALID_TEST_ASSERTION_OK:upload_requires_authentication"
