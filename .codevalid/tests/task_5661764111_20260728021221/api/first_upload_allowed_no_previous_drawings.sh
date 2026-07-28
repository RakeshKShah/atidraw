#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
REQ_BODY_FILE="/tmp/first_upload_allowed_no_previous_drawings_req_${CASE_SUFFIX}.jpg"
RESP_HEADERS="/tmp/first_upload_allowed_no_previous_drawings_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/first_upload_allowed_no_previous_drawings_body_${CASE_SUFFIX}.bin"
cleanup_files() {
  rm -f "$REQ_BODY_FILE" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340FIRST-UPLOAD-%s' "$CASE_SUFFIX" > "$REQ_BODY_FILE"

# Given
echo "STEP: Given — prepare first-upload JPEG payload"
echo "PREREQ: creating JPEG-like payload for empty-blob-list scenario"

# When
echo "STEP: When — POST drawing to /api/upload"
echo "REQUEST_HEADERS: Cookie: appSession=first-upload-${CASE_SUFFIX}"
echo "REQUEST_BODY: multipart form field drawing=@${REQ_BODY_FILE};type=image/jpeg"
code="$({ curl -sS -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/upload" \
  -H "Cookie: appSession=first-upload-${CASE_SUFFIX}" \
  -F "drawing=@${REQ_BODY_FILE};type=image/jpeg;filename=first-${CASE_SUFFIX}.jpg"; } || true)"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS" || true
echo "RESPONSE_BODY:"
cat "$RESP_BODY" || true
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — first upload succeeds when no previous drawings exist"
[ "$code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${code}"; exit 1; }
body_size="$(wc -c < "$RESP_BODY" | tr -d ' ')"
[ "$body_size" -gt 0 ] || { echo "ASSERTION_FAILED: expected non-empty response body"; exit 1; }

echo "CODEVALID_TEST_ASSERTION_OK:first_upload_allowed_no_previous_drawings"
