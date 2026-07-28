#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/upload_original_drawing_success_cookie_${CASE_SUFFIX}.txt"
DRAWING_FILE="/tmp/upload_original_drawing_success_drawing_${CASE_SUFFIX}.jpg"
ANON_HEADERS="/tmp/upload_original_drawing_success_anon_headers_${CASE_SUFFIX}.txt"
ANON_BODY="/tmp/upload_original_drawing_success_anon_body_${CASE_SUFFIX}.txt"
RESPONSE_HEADERS="/tmp/upload_original_drawing_success_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/upload_original_drawing_success_response_body_${CASE_SUFFIX}.txt"
DRAWINGS_HEADERS="/tmp/upload_original_drawing_success_drawings_headers_${CASE_SUFFIX}.txt"
DRAWINGS_BODY="/tmp/upload_original_drawing_success_drawings_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$DRAWING_FILE" "$ANON_HEADERS" "$ANON_BODY" "$RESPONSE_HEADERS" "$RESPONSE_BODY" "$DRAWINGS_HEADERS" "$DRAWINGS_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340CODEVALID-JPEG-%s\377\331' "$CASE_SUFFIX" > "$DRAWING_FILE"

# Given
echo "STEP: Given — bootstrap an authenticated session and prepare a valid JPEG drawing"
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
echo "STEP: When — upload the original drawing through POST /api/upload"
echo "REQUEST_HEADERS: Cookie jar=$COOKIE_JAR ; Content-Type: multipart/form-data"
echo "REQUEST_BODY: drawing=@$DRAWING_FILE;type=image/jpeg"
upload_code=$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=test-artwork-${CASE_SUFFIX}.jpg" \
  "$BASE_URL/api/upload")
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"
echo "RESPONSE_STATUS: $upload_code"

# Then
echo "STEP: Then — verify upload succeeds"
[ "$upload_code" = "200" ] || [ "$upload_code" = "201" ] || [ "$upload_code" = "302" ] || [ "$upload_code" = "303" ] || { echo "ASSERTION_FAILED: expected upload HTTP 200/201/302/303 got ${upload_code}"; exit 1; }
if [ "$upload_code" = "302" ] || [ "$upload_code" = "303" ]; then
  grep -i '^location: /' "$RESPONSE_HEADERS" >/dev/null || { echo "ASSERTION_FAILED: expected redirect Location header to /"; exit 1; }
fi

echo "STEP: Then — verify the uploaded creation is retrievable from synchronized storage"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
drawings_code=$(curl -sS -D "$DRAWINGS_HEADERS" -o "$DRAWINGS_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/drawings")
echo "RESPONSE_HEADERS:"
cat "$DRAWINGS_HEADERS"
echo "RESPONSE_BODY:"
cat "$DRAWINGS_BODY"
echo "RESPONSE_STATUS: $drawings_code"
[ "$drawings_code" = "200" ] || { echo "ASSERTION_FAILED: expected drawings list HTTP 200 got ${drawings_code}"; exit 1; }
grep -F 'drawings/' "$DRAWINGS_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected drawings list to include a drawings/ pathname"; exit 1; }
grep -F 'customMetadata' "$DRAWINGS_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected drawings list to include customMetadata"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no public delete endpoint exists for uploaded blob assets"

echo "CODEVALID_TEST_ASSERTION_OK:upload_original_drawing_success"
