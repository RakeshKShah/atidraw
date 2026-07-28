#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
REQ_BODY_FILE="/tmp/authentication_required_req_${CASE_SUFFIX}.jpg"
RESP_HEADERS="/tmp/authentication_required_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/authentication_required_body_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$REQ_BODY_FILE" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340NOAUTH-%s' "$CASE_SUFFIX" > "$REQ_BODY_FILE"

# Given
echo "STEP: Given — prepare unauthenticated JPEG upload request"
echo "PREREQ: creating JPEG-like payload without any session cookie"

# When
echo "STEP: When — POST drawing to /api/upload without authentication"
echo "REQUEST_HEADERS: (none)"
echo "REQUEST_BODY: multipart form field drawing=@${REQ_BODY_FILE};type=image/jpeg"
code="$({ curl -sS -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/upload" \
  -F "drawing=@${REQ_BODY_FILE};type=image/jpeg;filename=portrait-${CASE_SUFFIX}.jpg"; } || true)"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS" || true
echo "RESPONSE_BODY:"
cat "$RESP_BODY" || true
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — unauthenticated request is rejected before processing"
case "$code" in
  401|302|303|500) ;;
  *) echo "ASSERTION_FAILED: expected HTTP 401/302/303/500 for unauthenticated Nuxt auth flow got ${code}"; exit 1 ;;
esac

echo "CODEVALID_TEST_ASSERTION_OK:authentication_required"
