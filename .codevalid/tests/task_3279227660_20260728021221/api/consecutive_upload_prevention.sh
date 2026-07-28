#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/consecutive_upload_prevention_cookie_${CASE_SUFFIX}.txt"
DRAWING_FILE="/tmp/consecutive_upload_prevention_drawing_${CASE_SUFFIX}.jpg"
ANON_HEADERS="/tmp/consecutive_upload_prevention_anon_headers_${CASE_SUFFIX}.txt"
ANON_BODY="/tmp/consecutive_upload_prevention_anon_body_${CASE_SUFFIX}.txt"
FIRST_HEADERS="/tmp/consecutive_upload_prevention_first_headers_${CASE_SUFFIX}.txt"
FIRST_BODY="/tmp/consecutive_upload_prevention_first_body_${CASE_SUFFIX}.txt"
SECOND_HEADERS="/tmp/consecutive_upload_prevention_second_headers_${CASE_SUFFIX}.txt"
SECOND_BODY="/tmp/consecutive_upload_prevention_second_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$DRAWING_FILE" "$ANON_HEADERS" "$ANON_BODY" "$FIRST_HEADERS" "$FIRST_BODY" "$SECOND_HEADERS" "$SECOND_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340CONSEC-%s\377\331' "$CASE_SUFFIX" > "$DRAWING_FILE"

# Given
echo "STEP: Given — create a session and perform an initial upload from that same user"
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

echo "PREREQ: upload the first drawing so this user becomes the latest author"
echo "REQUEST_HEADERS: Cookie jar=$COOKIE_JAR ; Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@$DRAWING_FILE;type=image/jpeg"
first_code=$(curl -sS -D "$FIRST_HEADERS" -o "$FIRST_BODY" -w '%{http_code}' \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=first-${CASE_SUFFIX}.jpg" \
  "$BASE_URL/api/upload")
echo "RESPONSE_HEADERS:"
cat "$FIRST_HEADERS"
echo "RESPONSE_BODY:"
cat "$FIRST_BODY"
echo "RESPONSE_STATUS: $first_code"
[ "$first_code" = "200" ] || [ "$first_code" = "201" ] || [ "$first_code" = "302" ] || [ "$first_code" = "303" ] || { echo "ASSERTION_FAILED: expected first upload HTTP 200/201/302/303 got ${first_code}"; exit 1; }

# When
echo "STEP: When — attempt a second consecutive upload from the same session"
echo "REQUEST_HEADERS: Cookie jar=$COOKIE_JAR ; Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@$DRAWING_FILE;type=image/jpeg"
second_code=$(curl -sS -D "$SECOND_HEADERS" -o "$SECOND_BODY" -w '%{http_code}' \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=second-${CASE_SUFFIX}.jpg" \
  "$BASE_URL/api/upload")
echo "RESPONSE_HEADERS:"
cat "$SECOND_HEADERS"
echo "RESPONSE_BODY:"
cat "$SECOND_BODY"
echo "RESPONSE_STATUS: $second_code"

# Then
echo "STEP: Then — verify the consecutive upload rule rejects the second upload"
[ "$second_code" = "400" ] || { echo "ASSERTION_FAILED: expected consecutive upload rejection HTTP 400 got ${second_code}"; exit 1; }
grep -F 'You cannot upload two drawings in a row' "$SECOND_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected consecutive upload rejection message"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no public delete endpoint exists for uploaded blob assets"

echo "CODEVALID_TEST_ASSERTION_OK:consecutive_upload_prevention"
