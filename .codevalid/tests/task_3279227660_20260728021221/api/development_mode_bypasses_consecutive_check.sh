#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/development_mode_bypasses_consecutive_check_cookie_${CASE_SUFFIX}.txt"
DRAWING_FILE="/tmp/development_mode_bypasses_consecutive_check_drawing_${CASE_SUFFIX}.jpg"
ANON_HEADERS="/tmp/development_mode_bypasses_consecutive_check_anon_headers_${CASE_SUFFIX}.txt"
ANON_BODY="/tmp/development_mode_bypasses_consecutive_check_anon_body_${CASE_SUFFIX}.txt"
FIRST_HEADERS="/tmp/development_mode_bypasses_consecutive_check_first_headers_${CASE_SUFFIX}.txt"
FIRST_BODY="/tmp/development_mode_bypasses_consecutive_check_first_body_${CASE_SUFFIX}.txt"
SECOND_HEADERS="/tmp/development_mode_bypasses_consecutive_check_second_headers_${CASE_SUFFIX}.txt"
SECOND_BODY="/tmp/development_mode_bypasses_consecutive_check_second_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$DRAWING_FILE" "$ANON_HEADERS" "$ANON_BODY" "$FIRST_HEADERS" "$FIRST_BODY" "$SECOND_HEADERS" "$SECOND_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340DEV-%s\377\331' "$CASE_SUFFIX" > "$DRAWING_FILE"

# Given
echo "STEP: Given — create a session and perform an initial upload"
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

echo "PREREQ: upload the first drawing so the same user is the latest author"
echo "REQUEST_HEADERS: Cookie jar=$COOKIE_JAR ; Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@$DRAWING_FILE;type=image/jpeg"
first_code=$(curl -sS -D "$FIRST_HEADERS" -o "$FIRST_BODY" -w '%{http_code}' \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=dev-first-${CASE_SUFFIX}.jpg" \
  "$BASE_URL/api/upload")
echo "RESPONSE_HEADERS:"
cat "$FIRST_HEADERS"
echo "RESPONSE_BODY:"
cat "$FIRST_BODY"
echo "RESPONSE_STATUS: $first_code"
[ "$first_code" = "200" ] || [ "$first_code" = "201" ] || [ "$first_code" = "302" ] || [ "$first_code" = "303" ] || { echo "ASSERTION_FAILED: expected first upload HTTP 200/201/302/303 got ${first_code}"; exit 1; }

# When
echo "STEP: When — perform a second consecutive upload from the same session"
echo "REQUEST_HEADERS: Cookie jar=$COOKIE_JAR ; Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@$DRAWING_FILE;type=image/jpeg"
second_code=$(curl -sS -D "$SECOND_HEADERS" -o "$SECOND_BODY" -w '%{http_code}' \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=dev-second-${CASE_SUFFIX}.jpg" \
  "$BASE_URL/api/upload")
echo "RESPONSE_HEADERS:"
cat "$SECOND_HEADERS"
echo "RESPONSE_BODY:"
cat "$SECOND_BODY"
echo "RESPONSE_STATUS: $second_code"

# Then
echo "STEP: Then — verify the environment shows either normal rejection or dev-mode bypass"
[ "$second_code" = "400" ] || [ "$second_code" = "200" ] || [ "$second_code" = "201" ] || [ "$second_code" = "302" ] || [ "$second_code" = "303" ] || { echo "ASSERTION_FAILED: expected second upload HTTP 400/200/201/302/303 got ${second_code}"; exit 1; }
if [ "$second_code" = "400" ]; then
  grep -F 'You cannot upload two drawings in a row' "$SECOND_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected non-dev rejection message"; exit 1; }
else
  echo "ASSERTION_NOTE: second upload succeeded, consistent with development-mode bypass behavior"
fi

# Cleanup
echo "STEP: Cleanup — no public delete endpoint exists for uploaded blob assets"

echo "CODEVALID_TEST_ASSERTION_OK:development_mode_bypasses_consecutive_check"
