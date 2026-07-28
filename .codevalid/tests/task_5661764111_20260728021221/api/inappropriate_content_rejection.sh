#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
REQ_BODY_FILE="/tmp/inappropriate_content_rejection_req_${CASE_SUFFIX}.jpg"
RESP_HEADERS="/tmp/inappropriate_content_rejection_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/inappropriate_content_rejection_body_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$REQ_BODY_FILE" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340INAPPROPRIATE-%s' "$CASE_SUFFIX" > "$REQ_BODY_FILE"

# Given
echo "STEP: Given — prepare JPEG upload expected to be moderated as inappropriate"
echo "PREREQ: creating JPEG-like payload for moderation rejection scenario"

# When
echo "STEP: When — POST drawing to /api/upload"
echo "REQUEST_HEADERS: Cookie: appSession=inappropriate-${CASE_SUFFIX}"
echo "REQUEST_BODY: multipart form field drawing=@${REQ_BODY_FILE};type=image/jpeg"
code="$({ curl -sS -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/upload" \
  -H "Cookie: appSession=inappropriate-${CASE_SUFFIX}" \
  -F "drawing=@${REQ_BODY_FILE};type=image/jpeg;filename=inappropriate-${CASE_SUFFIX}.jpg"; } || true)"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS" || true
echo "RESPONSE_BODY:"
cat "$RESP_BODY" || true
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — inappropriate drawing is rejected"
[ "$code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${code}"; exit 1; }
grep -a -F 'You cannot upload this kind of drawings.' "$RESP_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected inappropriate drawing rejection message"; exit 1; }

echo "CODEVALID_TEST_ASSERTION_OK:inappropriate_content_rejection"
