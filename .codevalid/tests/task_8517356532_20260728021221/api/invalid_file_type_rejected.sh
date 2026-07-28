#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"

COOKIE_JAR="/tmp/invalid_file_type_rejected_cookie_${CASE_SUFFIX}.txt"
GIVEN_HEADERS="/tmp/invalid_file_type_rejected_given_headers_${CASE_SUFFIX}.txt"
GIVEN_BODY="/tmp/invalid_file_type_rejected_given_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/invalid_file_type_rejected_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/invalid_file_type_rejected_when_body_${CASE_SUFFIX}.txt"
DRAWING_FILE="/tmp/invalid_file_type_rejected_drawing_${CASE_SUFFIX}.png"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$GIVEN_HEADERS" "$GIVEN_BODY" "$WHEN_HEADERS" "$WHEN_BODY" "$DRAWING_FILE"
}
trap cleanup_files EXIT

printf '\211PNG\r\n\032\nCodeValid PNG %s' "$CASE_SUFFIX" > "$DRAWING_FILE"

# Given
echo "STEP: Given — create an authenticated session and prepare a PNG file"
echo "PREREQ: bootstrapping anonymous session cookie"
echo "REQUEST_HEADERS: Accept: */*"
echo "REQUEST_BODY: empty"
GIVEN_STATUS=$(curl -sS -L -D "$GIVEN_HEADERS" -o "$GIVEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" "$BASE_URL/auth/anonymous")
echo "RESPONSE_HEADERS:"
cat "$GIVEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$GIVEN_BODY"
echo "RESPONSE_STATUS: $GIVEN_STATUS"
[ "$GIVEN_STATUS" = "200" ] || [ "$GIVEN_STATUS" = "201" ] || [ "$GIVEN_STATUS" = "302" ] || [ "$GIVEN_STATUS" = "303" ] || { echo "ASSERTION_FAILED: expected auth bootstrap HTTP 200/201/302/303 got ${GIVEN_STATUS}"; exit 1; }
[ -s "$COOKIE_JAR" ] || { echo "ASSERTION_FAILED: expected cookie jar to be populated"; exit 1; }

# When
echo "STEP: When — upload a non-JPEG image to POST /api/upload"
echo "REQUEST_HEADERS: Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@${DRAWING_FILE};type=image/png"
WHEN_STATUS=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" -X POST "$BASE_URL/api/upload" -F "drawing=@${DRAWING_FILE};type=image/png")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $WHEN_STATUS"

# Then
echo "STEP: Then — request is rejected because only JPEG drawings are accepted"
[ "$WHEN_STATUS" = "400" ] || [ "$WHEN_STATUS" = "415" ] || { echo "ASSERTION_FAILED: expected HTTP 400/415 got ${WHEN_STATUS}"; exit 1; }
grep -Eiq 'jpeg|jpg|image/jpeg|type|invalid' "$WHEN_BODY" || { echo "ASSERTION_FAILED: expected response body to mention JPEG-only validation"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files for this test invocation"

printf 'CODEVALID_TEST_ASSERTION_OK:invalid_file_type_rejected\n'
