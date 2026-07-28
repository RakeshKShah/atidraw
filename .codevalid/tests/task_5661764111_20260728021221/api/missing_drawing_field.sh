#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
RESP_HEADERS="/tmp/missing_drawing_field_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/missing_drawing_field_body_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare authenticated-style request with no drawing field"
echo "PREREQ: no multipart drawing part will be sent"

# When
echo "STEP: When — POST empty multipart form to /api/upload"
echo "REQUEST_HEADERS: Cookie: appSession=missing-drawing-${CASE_SUFFIX}"
echo "REQUEST_BODY: multipart form with no drawing field"
code="$({ curl -sS -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/upload" \
  -H "Cookie: appSession=missing-drawing-${CASE_SUFFIX}" \
  -F "placeholder="; } || true)"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS" || true
echo "RESPONSE_BODY:"
cat "$RESP_BODY" || true
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — request without drawing field is rejected with an error"
case "$code" in
  400|500) ;;
  *) echo "ASSERTION_FAILED: expected HTTP 400 or 500 got ${code}"; exit 1 ;;
esac

echo "CODEVALID_TEST_ASSERTION_OK:missing_drawing_field"
