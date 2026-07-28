#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
REQ_BODY_FILE="/tmp/ai_description_failure_graceful_handling_req_${CASE_SUFFIX}.jpg"
RESP_HEADERS="/tmp/ai_description_failure_graceful_handling_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/ai_description_failure_graceful_handling_body_${CASE_SUFFIX}.bin"
cleanup_files() {
  rm -f "$REQ_BODY_FILE" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340ABSTRACT-%s' "$CASE_SUFFIX" > "$REQ_BODY_FILE"

# Given
echo "STEP: Given — prepare authenticated-style JPEG drawing for graceful description failure path"
echo "PREREQ: creating JPEG-like payload"

# When
echo "STEP: When — POST drawing to /api/upload expecting description generation fallback to allow processing"
echo "REQUEST_HEADERS: Cookie: appSession=desc-fallback-${CASE_SUFFIX}"
echo "REQUEST_BODY: multipart form field drawing=@${REQ_BODY_FILE};type=image/jpeg"
code="$({ curl -sS -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/upload" \
  -H "Cookie: appSession=desc-fallback-${CASE_SUFFIX}" \
  -F "drawing=@${REQ_BODY_FILE};type=image/jpeg;filename=abstract-${CASE_SUFFIX}.jpg"; } || true)"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS" || true
echo "RESPONSE_BODY:"
cat "$RESP_BODY" || true
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — upload still succeeds with AI generation output"
[ "$code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${code}"; exit 1; }
body_size="$(wc -c < "$RESP_BODY" | tr -d ' ')"
[ "$body_size" -gt 0 ] || { echo "ASSERTION_FAILED: expected non-empty response body"; exit 1; }
if grep -a -i '<!DOCTYPE html>' "$RESP_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: expected AI response body, got HTML"
  exit 1
fi

echo "CODEVALID_TEST_ASSERTION_OK:ai_description_failure_graceful_handling"
