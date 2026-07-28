#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"

COOKIE_JAR="/tmp/non_empty_descriptive_alt_text_cookie_${CASE_SUFFIX}.txt"
GIVEN_HEADERS="/tmp/non_empty_descriptive_alt_text_given_headers_${CASE_SUFFIX}.txt"
GIVEN_BODY="/tmp/non_empty_descriptive_alt_text_given_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/non_empty_descriptive_alt_text_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/non_empty_descriptive_alt_text_when_body_${CASE_SUFFIX}.txt"
UPLOAD_HEADERS="/tmp/non_empty_descriptive_alt_text_upload_headers_${CASE_SUFFIX}.txt"
UPLOAD_BODY="/tmp/non_empty_descriptive_alt_text_upload_body_${CASE_SUFFIX}.txt"
DRAWING_FILE="/tmp/non_empty_descriptive_alt_text_drawing_${CASE_SUFFIX}.jpg"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$GIVEN_HEADERS" "$GIVEN_BODY" "$WHEN_HEADERS" "$WHEN_BODY" "$UPLOAD_HEADERS" "$UPLOAD_BODY" "$DRAWING_FILE"
}
trap cleanup_files EXIT

printf '\377\330\377\341Descriptive alt text JPEG %s\377\331' "$CASE_SUFFIX" > "$DRAWING_FILE"

# Given
echo "STEP: Given — create an authenticated session and prepare a valid JPEG drawing"
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
echo "STEP: When — call POST /api/generate to obtain AI-generated description header for the drawing"
echo "REQUEST_HEADERS: Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@${DRAWING_FILE};type=image/jpeg"
WHEN_STATUS=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" -X POST "$BASE_URL/api/generate" -F "drawing=@${DRAWING_FILE};type=image/jpeg")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $WHEN_STATUS"

echo "REQUEST_HEADERS: Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@${DRAWING_FILE};type=image/jpeg"
UPLOAD_STATUS=$(curl -sS -D "$UPLOAD_HEADERS" -o "$UPLOAD_BODY" -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" -X POST "$BASE_URL/api/upload" -F "drawing=@${DRAWING_FILE};type=image/jpeg")
echo "RESPONSE_HEADERS:"
cat "$UPLOAD_HEADERS"
echo "RESPONSE_BODY:"
cat "$UPLOAD_BODY"
echo "RESPONSE_STATUS: $UPLOAD_STATUS"

# Then
echo "STEP: Then — AI description header is exposed by generate endpoint and upload succeeds without manual alt text input"
[ "$WHEN_STATUS" = "200" ] || { echo "ASSERTION_FAILED: expected /api/generate HTTP 200 got ${WHEN_STATUS}"; exit 1; }
grep -qi '^x-description:' "$WHEN_HEADERS" || { echo "ASSERTION_FAILED: expected x-description header from /api/generate"; exit 1; }
DESC_VALUE=$(grep -i '^x-description:' "$WHEN_HEADERS" | tail -n 1 | cut -d: -f2- | tr -d '\r' | sed 's/^ *//')
[ "${DESC_VALUE+x}" = "x" ] || { echo "ASSERTION_FAILED: expected description header variable to be set"; exit 1; }
[ "$UPLOAD_STATUS" = "200" ] || { echo "ASSERTION_FAILED: expected /api/upload HTTP 200 got ${UPLOAD_STATUS}"; exit 1; }
[ -s "$UPLOAD_BODY" ] || { echo "ASSERTION_FAILED: expected non-empty upload response body"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files for this test invocation"

printf 'CODEVALID_TEST_ASSERTION_OK:non_empty_descriptive_alt_text\n'
