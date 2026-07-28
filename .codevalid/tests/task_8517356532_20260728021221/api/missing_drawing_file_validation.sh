#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"

COOKIE_JAR="/tmp/missing_drawing_file_validation_cookie_${CASE_SUFFIX}.txt"
GIVEN_HEADERS="/tmp/missing_drawing_file_validation_given_headers_${CASE_SUFFIX}.txt"
GIVEN_BODY="/tmp/missing_drawing_file_validation_given_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/missing_drawing_file_validation_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/missing_drawing_file_validation_when_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$GIVEN_HEADERS" "$GIVEN_BODY" "$WHEN_HEADERS" "$WHEN_BODY"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — create an authenticated session without preparing a drawing file"
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

# When
echo "STEP: When — submit POST /api/upload without the required drawing field"
echo "REQUEST_HEADERS: Content-Type: multipart/form-data"
echo "REQUEST_BODY: empty multipart form"
WHEN_STATUS=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" -X POST "$BASE_URL/api/upload")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $WHEN_STATUS"

# Then
echo "STEP: Then — request is rejected because drawing input is missing"
[ "$WHEN_STATUS" = "400" ] || [ "$WHEN_STATUS" = "422" ] || [ "$WHEN_STATUS" = "500" ] || { echo "ASSERTION_FAILED: expected HTTP 400/422/500 got ${WHEN_STATUS}"; exit 1; }
grep -Eiq 'drawing|file|blob|invalid|missing|form' "$WHEN_BODY" || { echo "ASSERTION_FAILED: expected error body to mention missing or invalid drawing input"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files for this test invocation"

printf 'CODEVALID_TEST_ASSERTION_OK:missing_drawing_file_validation\n'
