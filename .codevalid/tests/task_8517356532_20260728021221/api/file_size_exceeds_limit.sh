#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"

COOKIE_JAR="/tmp/file_size_exceeds_limit_cookie_${CASE_SUFFIX}.txt"
GIVEN_HEADERS="/tmp/file_size_exceeds_limit_given_headers_${CASE_SUFFIX}.txt"
GIVEN_BODY="/tmp/file_size_exceeds_limit_given_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/file_size_exceeds_limit_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/file_size_exceeds_limit_when_body_${CASE_SUFFIX}.txt"
DRAWING_FILE="/tmp/file_size_exceeds_limit_drawing_${CASE_SUFFIX}.jpg"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$GIVEN_HEADERS" "$GIVEN_BODY" "$WHEN_HEADERS" "$WHEN_BODY" "$DRAWING_FILE"
}
trap cleanup_files EXIT

python3 - <<'PY' > "$DRAWING_FILE"
import sys
sys.stdout.buffer.write(b'\xff\xd8\xff\xe0' + b'A' * (1024 * 1024 + 128) + b'\xff\xd9')
PY

# Given
echo "STEP: Given — create an authenticated session and prepare an oversized JPEG payload"
echo "PREREQ: bootstrapping anonymous session cookie"
echo "REQUEST_HEADERS: Accept: */*"
echo "REQUEST_BODY: empty"
GIVEN_STATUS=$(curl -sS -D "$GIVEN_HEADERS" -o "$GIVEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" "$BASE_URL/auth/anonymous")
echo "RESPONSE_HEADERS:"
cat "$GIVEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$GIVEN_BODY"
echo "RESPONSE_STATUS: $GIVEN_STATUS"
[ "$GIVEN_STATUS" = "200" ] || [ "$GIVEN_STATUS" = "201" ] || [ "$GIVEN_STATUS" = "302" ] || [ "$GIVEN_STATUS" = "303" ] || { echo "ASSERTION_FAILED: expected auth bootstrap HTTP 200/201/302/303 got ${GIVEN_STATUS}"; exit 1; }
[ -s "$COOKIE_JAR" ] || { echo "ASSERTION_FAILED: expected cookie jar to be populated"; exit 1; }
echo "PREREQ: verifying oversized drawing file exceeds 1MB"
FILE_SIZE=$(wc -c < "$DRAWING_FILE")
[ "$FILE_SIZE" -gt 1048576 ] || { echo "ASSERTION_FAILED: expected oversized test file to be greater than 1MB"; exit 1; }

# When
echo "STEP: When — upload an oversized JPEG drawing to POST /api/upload"
echo "REQUEST_HEADERS: Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@${DRAWING_FILE};type=image/jpeg"
WHEN_STATUS=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" -X POST "$BASE_URL/api/upload" -F "drawing=@${DRAWING_FILE};type=image/jpeg")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $WHEN_STATUS"

# Then
echo "STEP: Then — request is rejected for exceeding the 1MB size limit"
[ "$WHEN_STATUS" = "400" ] || [ "$WHEN_STATUS" = "413" ] || { echo "ASSERTION_FAILED: expected HTTP 400/413 got ${WHEN_STATUS}"; exit 1; }
grep -Eiq '1MB|size|max|too large|payload' "$WHEN_BODY" || { echo "ASSERTION_FAILED: expected response body to mention size limit"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files for this test invocation"

printf 'CODEVALID_TEST_ASSERTION_OK:file_size_exceeds_limit\n'
