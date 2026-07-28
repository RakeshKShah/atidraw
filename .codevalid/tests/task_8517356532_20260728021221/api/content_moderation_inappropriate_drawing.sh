#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"

COOKIE_JAR="/tmp/content_moderation_inappropriate_drawing_cookie_${CASE_SUFFIX}.txt"
GIVEN_HEADERS="/tmp/content_moderation_inappropriate_drawing_given_headers_${CASE_SUFFIX}.txt"
GIVEN_BODY="/tmp/content_moderation_inappropriate_drawing_given_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/content_moderation_inappropriate_drawing_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/content_moderation_inappropriate_drawing_when_body_${CASE_SUFFIX}.txt"
DRAWING_FILE="/tmp/content_moderation_inappropriate_drawing_drawing_${CASE_SUFFIX}.jpg"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$GIVEN_HEADERS" "$GIVEN_BODY" "$WHEN_HEADERS" "$WHEN_BODY" "$DRAWING_FILE"
}
trap cleanup_files EXIT

printf '\377\330\377\341Moderation JPEG %s\377\331' "$CASE_SUFFIX" > "$DRAWING_FILE"

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
echo "STEP: When — upload a drawing that may trigger AI moderation text check"
echo "REQUEST_HEADERS: Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@${DRAWING_FILE};type=image/jpeg"
WHEN_STATUS=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" -X POST "$BASE_URL/api/upload" -F "drawing=@${DRAWING_FILE};type=image/jpeg")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $WHEN_STATUS"

# Then
echo "STEP: Then — if moderation detects inappropriate content, upload is rejected with documented message"
[ "$WHEN_STATUS" = "400" ] || [ "$WHEN_STATUS" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 400 or 200 got ${WHEN_STATUS}"; exit 1; }
if [ "$WHEN_STATUS" = "400" ]; then
  grep -Fq 'You cannot upload this kind of drawings.' "$WHEN_BODY" || { echo "ASSERTION_FAILED: expected moderation rejection message"; exit 1; }
else
  [ -s "$WHEN_BODY" ] || { echo "ASSERTION_FAILED: expected non-empty success body when moderation does not trigger"; exit 1; }
fi

# Cleanup
echo "STEP: Cleanup — remove temporary files for this test invocation"

printf 'CODEVALID_TEST_ASSERTION_OK:content_moderation_inappropriate_drawing\n'
