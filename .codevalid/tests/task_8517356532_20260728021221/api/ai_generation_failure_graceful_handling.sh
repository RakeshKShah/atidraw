#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"

COOKIE_JAR="/tmp/ai_generation_failure_graceful_handling_cookie_${CASE_SUFFIX}.txt"
GIVEN_HEADERS="/tmp/ai_generation_failure_graceful_handling_given_headers_${CASE_SUFFIX}.txt"
GIVEN_BODY="/tmp/ai_generation_failure_graceful_handling_given_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/ai_generation_failure_graceful_handling_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/ai_generation_failure_graceful_handling_when_body_${CASE_SUFFIX}.txt"
DRAWING_FILE="/tmp/ai_generation_failure_graceful_handling_drawing_${CASE_SUFFIX}.jpg"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$GIVEN_HEADERS" "$GIVEN_BODY" "$WHEN_HEADERS" "$WHEN_BODY" "$DRAWING_FILE"
}
trap cleanup_files EXIT

printf '\377\330\377\341Graceful AI failure JPEG %s\377\331' "$CASE_SUFFIX" > "$DRAWING_FILE"

# Given
echo "STEP: Given — create an authenticated session and prepare a valid JPEG drawing"
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
echo "STEP: When — upload a valid JPEG even if AI description generation fails internally"
echo "REQUEST_HEADERS: Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@${DRAWING_FILE};type=image/jpeg"
WHEN_STATUS=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" -X POST "$BASE_URL/api/upload" -F "drawing=@${DRAWING_FILE};type=image/jpeg")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $WHEN_STATUS"

# Then
echo "STEP: Then — upload still succeeds because description generation errors are caught gracefully"
[ "$WHEN_STATUS" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${WHEN_STATUS}"; exit 1; }
grep -qi '^content-type: image/' "$WHEN_HEADERS" || { echo "ASSERTION_FAILED: expected image content-type in response headers"; exit 1; }
[ -s "$WHEN_BODY" ] || { echo "ASSERTION_FAILED: expected non-empty response body despite AI description fallback"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files for this test invocation"

printf 'CODEVALID_TEST_ASSERTION_OK:ai_generation_failure_graceful_handling\n'
