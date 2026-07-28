#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
REQ_BODY_FILE="/tmp/file_too_large_req_${CASE_SUFFIX}.jpg"
RESP_HEADERS="/tmp/file_too_large_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/file_too_large_body_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$REQ_BODY_FILE" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

python3 - <<'PY' "$REQ_BODY_FILE"
import sys
path = sys.argv[1]
with open(path, 'wb') as f:
    f.write(b'\xff\xd8\xff\xe0')
    f.write(b'A' * (1100 * 1024))
PY

# Given
echo "STEP: Given — prepare oversized JPEG payload larger than 1MB"
echo "PREREQ: creating >1MB JPEG-like file to trigger ensureBlob size validation"

# When
echo "STEP: When — POST oversized drawing to /api/upload"
echo "REQUEST_HEADERS: Cookie: appSession=file-too-large-${CASE_SUFFIX}"
echo "REQUEST_BODY: multipart form field drawing=@${REQ_BODY_FILE};type=image/jpeg"
code="$({ curl -sS -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/upload" \
  -H "Cookie: appSession=file-too-large-${CASE_SUFFIX}" \
  -F "drawing=@${REQ_BODY_FILE};type=image/jpeg;filename=large-${CASE_SUFFIX}.jpg"; } || true)"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS" || true
echo "RESPONSE_BODY:"
cat "$RESP_BODY" || true
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — oversized file is rejected"
[ "$code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${code}"; exit 1; }
if ! grep -a -i 'size\|1mb\|too large\|max' "$RESP_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: expected body to mention size limit"
  exit 1
fi

echo "CODEVALID_TEST_ASSERTION_OK:file_too_large"
