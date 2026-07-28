#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
REQ_BODY_FILE="/tmp/invalid_image_type_req_${CASE_SUFFIX}.png"
RESP_HEADERS="/tmp/invalid_image_type_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/invalid_image_type_body_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$REQ_BODY_FILE" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

printf '\211PNG\r\n\032\nCODEVALID-PNG-%s' "$CASE_SUFFIX" > "$REQ_BODY_FILE"

# Given
echo "STEP: Given — prepare a non-JPEG drawing payload"
echo "PREREQ: creating PNG-like payload to trigger ensureBlob type validation"

# When
echo "STEP: When — POST PNG drawing to /api/upload"
echo "REQUEST_HEADERS: Cookie: appSession=invalid-image-type-${CASE_SUFFIX}"
echo "REQUEST_BODY: multipart form field drawing=@${REQ_BODY_FILE};type=image/png"
code="$({ curl -sS -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/upload" \
  -H "Cookie: appSession=invalid-image-type-${CASE_SUFFIX}" \
  -F "drawing=@${REQ_BODY_FILE};type=image/png;filename=sketch-${CASE_SUFFIX}.png"; } || true)"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS" || true
echo "RESPONSE_BODY:"
cat "$RESP_BODY" || true
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — invalid image type is rejected"
[ "$code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${code}"; exit 1; }
if ! grep -a -i 'image\|type\|jpeg\|mime' "$RESP_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: expected body to mention invalid image type or jpeg requirement"
  exit 1
fi

echo "CODEVALID_TEST_ASSERTION_OK:invalid_image_type"
