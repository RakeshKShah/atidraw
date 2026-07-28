#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/happy_path_ai_image_generation_cookie_${CASE_SUFFIX}.txt"
REQ_BODY_FILE="/tmp/happy_path_ai_image_generation_req_${CASE_SUFFIX}.jpg"
RESP_HEADERS="/tmp/happy_path_ai_image_generation_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/happy_path_ai_image_generation_body_${CASE_SUFFIX}.bin"
cleanup_files() {
  rm -f "$COOKIE_JAR" "$REQ_BODY_FILE" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340CODEVALID-JPEG-%s' "$CASE_SUFFIX" > "$REQ_BODY_FILE"

# Given
echo "STEP: Given — prepare a JPEG drawing payload and authenticated-style request context"
echo "PREREQ: creating unique JPEG-like payload for upload"
: > "$COOKIE_JAR"
printf 'appSession=happy-path-%s\n' "$CASE_SUFFIX" > "$COOKIE_JAR"

# When
echo "STEP: When — POST drawing to /api/upload"
echo "REQUEST_HEADERS: Cookie: appSession=happy-path-${CASE_SUFFIX}"
echo "REQUEST_BODY: multipart form field drawing=@${REQ_BODY_FILE};type=image/jpeg"
code="$({ curl -sS -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/upload" \
  -H "Cookie: appSession=happy-path-${CASE_SUFFIX}" \
  -F "drawing=@${REQ_BODY_FILE};type=image/jpeg;filename=landscape-${CASE_SUFFIX}.jpg"; } || true)"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS" || true
echo "RESPONSE_BODY:"
cat "$RESP_BODY" || true
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — response is returned and is not an auth redirect HTML page"
[ "$code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${code}"; exit 1; }
content_type="$(grep -i '^content-type:' "$RESP_HEADERS" | tail -n 1 | tr -d '\r' || true)"
[ -n "$content_type" ] || { echo "ASSERTION_FAILED: expected Content-Type header"; exit 1; }
body_size="$(wc -c < "$RESP_BODY" | tr -d ' ')"
[ "$body_size" -gt 0 ] || { echo "ASSERTION_FAILED: expected non-empty AI image response body"; exit 1; }
if grep -a -i '<!DOCTYPE html>' "$RESP_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: expected binary/image response, got HTML"
  exit 1
fi

echo "CODEVALID_TEST_ASSERTION_OK:happy_path_ai_image_generation"
