#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
REQ_BODY_FILE="/tmp/ai_image_available_for_sharing_flows_req_${CASE_SUFFIX}.jpg"
RESP_HEADERS="/tmp/ai_image_available_for_sharing_flows_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/ai_image_available_for_sharing_flows_body_${CASE_SUFFIX}.bin"
cleanup_files() {
  rm -f "$REQ_BODY_FILE" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340SHAREABLE-%s' "$CASE_SUFFIX" > "$REQ_BODY_FILE"

# Given
echo "STEP: Given — prepare shareable JPEG drawing payload"
echo "PREREQ: creating JPEG-like payload for storage/sharing availability scenario"

# When
echo "STEP: When — POST drawing to /api/upload"
echo "REQUEST_HEADERS: Cookie: appSession=shareable-${CASE_SUFFIX}"
echo "REQUEST_BODY: multipart form field drawing=@${REQ_BODY_FILE};type=image/jpeg"
code="$({ curl -sS -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/upload" \
  -H "Cookie: appSession=shareable-${CASE_SUFFIX}" \
  -F "drawing=@${REQ_BODY_FILE};type=image/jpeg;filename=shareable-${CASE_SUFFIX}.jpg"; } || true)"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS" || true
echo "RESPONSE_BODY:"
cat "$RESP_BODY" || true
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — AI-generated image response is returned for later viewing/sharing flows"
[ "$code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${code}"; exit 1; }
content_type="$(grep -i '^content-type:' "$RESP_HEADERS" | tail -n 1 | tr -d '\r' || true)"
[ -n "$content_type" ] || { echo "ASSERTION_FAILED: expected Content-Type header"; exit 1; }
body_size="$(wc -c < "$RESP_BODY" | tr -d ' ')"
[ "$body_size" -gt 0 ] || { echo "ASSERTION_FAILED: expected non-empty response body"; exit 1; }

echo "CODEVALID_TEST_ASSERTION_OK:ai_image_available_for_sharing_flows"
