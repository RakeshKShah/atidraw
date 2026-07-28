#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/upload_file_size_exceeded_cookie_${CASE_SUFFIX}.txt"
DRAWING_FILE="/tmp/upload_file_size_exceeded_drawing_${CASE_SUFFIX}.jpg"
ANON_HEADERS="/tmp/upload_file_size_exceeded_anon_headers_${CASE_SUFFIX}.txt"
ANON_BODY="/tmp/upload_file_size_exceeded_anon_body_${CASE_SUFFIX}.txt"
RESPONSE_HEADERS="/tmp/upload_file_size_exceeded_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/upload_file_size_exceeded_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$DRAWING_FILE" "$ANON_HEADERS" "$ANON_BODY" "$RESPONSE_HEADERS" "$RESPONSE_BODY"
}
trap cleanup_files EXIT

python3 - "$DRAWING_FILE" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_bytes(b'\xff\xd8\xff\xe0' + (b'A' * (1100 * 1024)) + b'\xff\xd9')
PY

# Given
echo "STEP: Given — create a session and prepare a JPEG larger than 1MB"
echo "PREREQ: create an application session via anonymous auth"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: {}"
anon_code=$(curl -sS -D "$ANON_HEADERS" -o "$ANON_BODY" -w '%{http_code}' \
  -c "$COOKIE_JAR" \
  -H 'Accept: application/json' \
  -X POST "$BASE_URL/auth/anonymous")
echo "RESPONSE_HEADERS:"
cat "$ANON_HEADERS"
echo "RESPONSE_BODY:"
cat "$ANON_BODY"
echo "RESPONSE_STATUS: $anon_code"
[ "$anon_code" = "200" ] || [ "$anon_code" = "201" ] || [ "$anon_code" = "204" ] || { echo "ASSERTION_FAILED: expected anonymous auth HTTP 200/201/204 got ${anon_code}"; exit 1; }

# When
echo "STEP: When — upload the oversized JPEG to POST /api/upload"
echo "REQUEST_HEADERS: Cookie jar=$COOKIE_JAR ; Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@$DRAWING_FILE;type=image/jpeg"
code=$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -b "$COOKIE_JAR" \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=large-${CASE_SUFFIX}.jpg" \
  "$BASE_URL/api/upload")
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — verify size validation rejects the upload"
[ "$code" = "400" ] || [ "$code" = "413" ] || [ "$code" = "422" ] || { echo "ASSERTION_FAILED: expected oversized upload HTTP 400/413/422 got ${code}"; exit 1; }
grep -Ei '1MB|max|size|too large' "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected oversized upload error message to mention size limit"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup required because the request was rejected"

echo "CODEVALID_TEST_ASSERTION_OK:upload_file_size_exceeded"
