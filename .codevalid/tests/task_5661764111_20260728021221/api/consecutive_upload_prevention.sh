#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
REQ_BODY_FILE="/tmp/consecutive_upload_prevention_req_${CASE_SUFFIX}.jpg"
RESP_HEADERS="/tmp/consecutive_upload_prevention_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/consecutive_upload_prevention_body_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$REQ_BODY_FILE" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340SECOND-UPLOAD-%s' "$CASE_SUFFIX" > "$REQ_BODY_FILE"

# Given
echo "STEP: Given — prepare authenticated upload intended to trigger same-user consecutive upload rule"
echo "PREREQ: creating JPEG-like payload for consecutive upload prevention scenario"

# When
echo "STEP: When — POST drawing to /api/upload as same logical user"
echo "REQUEST_HEADERS: Cookie: appSession=consecutive-upload-${CASE_SUFFIX}"
echo "REQUEST_BODY: multipart form field drawing=@${REQ_BODY_FILE};type=image/jpeg"
code="$({ curl -sS -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/upload" \
  -H "Cookie: appSession=consecutive-upload-${CASE_SUFFIX}" \
  -F "drawing=@${REQ_BODY_FILE};type=image/jpeg;filename=second-drawing-${CASE_SUFFIX}.jpg"; } || true)"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS" || true
echo "RESPONSE_BODY:"
cat "$RESP_BODY" || true
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — request is blocked with the consecutive upload error when state matches seed setup"
[ "$code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${code}"; exit 1; }
grep -a -F 'You cannot upload two drawings in a row. Please wait for someone else to draw an image.' "$RESP_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected consecutive upload restriction message"; exit 1; }

echo "CODEVALID_TEST_ASSERTION_OK:consecutive_upload_prevention"
