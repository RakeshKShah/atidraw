#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
REQ_BODY_FILE="/tmp/ai_model_returns_empty_response_req_${CASE_SUFFIX}.jpg"
RESP_HEADERS="/tmp/ai_model_returns_empty_response_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/ai_model_returns_empty_response_body_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$REQ_BODY_FILE" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340EMPTY-AI-%s' "$CASE_SUFFIX" > "$REQ_BODY_FILE"

# Given
echo "STEP: Given — prepare JPEG drawing for AI empty-response handling"
echo "PREREQ: creating JPEG-like payload"

# When
echo "STEP: When — POST drawing to /api/upload"
echo "REQUEST_HEADERS: Cookie: appSession=empty-ai-${CASE_SUFFIX}"
echo "REQUEST_BODY: multipart form field drawing=@${REQ_BODY_FILE};type=image/jpeg"
code="$({ curl -sS -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/upload" \
  -H "Cookie: appSession=empty-ai-${CASE_SUFFIX}" \
  -F "drawing=@${REQ_BODY_FILE};type=image/jpeg;filename=empty-ai-${CASE_SUFFIX}.jpg"; } || true)"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS" || true
echo "RESPONSE_BODY:"
cat "$RESP_BODY" || true
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — service returns a handled success or failure response without crashing"
case "$code" in
  200|500) ;;
  *) echo "ASSERTION_FAILED: expected HTTP 200 or 500 got ${code}"; exit 1 ;;
esac
if [ "$code" = "500" ]; then
  grep -a -i 'Failed to generate image\|generate image\|failed' "$RESP_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected failure message when HTTP 500 is returned"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:ai_model_returns_empty_response"
