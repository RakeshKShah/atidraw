#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
AUTH_COOKIE="${AUTH_COOKIE:-}"
HEADERS_FILE="/tmp/missing_drawing_field_returns_error_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/missing_drawing_field_returns_error_body_${CASE_SUFFIX}.txt"
REQUEST_BODY_FILE="/tmp/missing_drawing_field_returns_error_request_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_FILE"
}
trap cleanup_files EXIT

printf '%s\n' 'multipart/form-data with no drawing field' > "$REQUEST_BODY_FILE"

# Given — bring the system to the required state
SHORT_DESC="authenticated user prepared to submit multipart form without drawing"
echo "STEP: Given — ${SHORT_DESC}"
if [ -z "$AUTH_COOKIE" ]; then
  echo "ASSERTION_FAILED: AUTH_COOKIE must be provided for authenticated generate endpoint tests"
  exit 1
fi

# When — perform the action under test
SHORT_DESC="POST /api/generate without drawing field"
echo "STEP: When — ${SHORT_DESC}"
echo "REQUEST_HEADERS: Cookie: ${AUTH_COOKIE}"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -X POST \
  -H "Cookie: ${AUTH_COOKIE}" \
  -F "note=missing-drawing-${CASE_SUFFIX}" \
  "$BASE_URL/api/generate")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE" || true
echo
echo "RESPONSE_STATUS: $status"

# Then — HTTP/body assertions
SHORT_DESC="server returns error when drawing field is absent"
echo "STEP: Then — ${SHORT_DESC}"
case "$status" in
  400|422|500) ;;
  *) echo "ASSERTION_FAILED: expected HTTP 400/422/500 got ${status}"; exit 1 ;;
esac
grep -Ei 'drawing|arrayBuffer|required|error|file' "$BODY_FILE" >/dev/null 2>&1 || {
  echo "ASSERTION_FAILED: expected error body mentioning missing drawing or file processing failure"
  exit 1
}

# Cleanup — undo Given side effects
SHORT_DESC="remove temporary files"
echo "STEP: Cleanup — ${SHORT_DESC}"
echo "CODEVALID_TEST_ASSERTION_OK:missing_drawing_field_returns_error"
