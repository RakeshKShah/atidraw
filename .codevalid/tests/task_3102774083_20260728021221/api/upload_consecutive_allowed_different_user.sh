#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="upload_consecutive_allowed_different_user"
ITEM_ID="${TEST_ID}-${CASE_SUFFIX}"
DRAWING_FILE="/tmp/${TEST_ID}_drawing_${CASE_SUFFIX}.jpg"
COOKIE_JAR_A="/tmp/${TEST_ID}_cookies_a_${CASE_SUFFIX}.txt"
COOKIE_JAR_B="/tmp/${TEST_ID}_cookies_b_${CASE_SUFFIX}.txt"
AUTH_A_HEADERS="/tmp/${TEST_ID}_auth_a_headers_${CASE_SUFFIX}.txt"
AUTH_A_BODY="/tmp/${TEST_ID}_auth_a_body_${CASE_SUFFIX}.txt"
AUTH_B_HEADERS="/tmp/${TEST_ID}_auth_b_headers_${CASE_SUFFIX}.txt"
AUTH_B_BODY="/tmp/${TEST_ID}_auth_b_body_${CASE_SUFFIX}.txt"
GIVEN_HEADERS="/tmp/${TEST_ID}_given_headers_${CASE_SUFFIX}.txt"
GIVEN_BODY="/tmp/${TEST_ID}_given_body_${CASE_SUFFIX}.txt"
RESP_HEADERS="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
REQ_BODY_LOG="/tmp/${TEST_ID}_request_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$COOKIE_JAR_A" "$COOKIE_JAR_B" "$AUTH_A_HEADERS" "$AUTH_A_BODY" "$AUTH_B_HEADERS" "$AUTH_B_BODY" "$GIVEN_HEADERS" "$GIVEN_BODY" "$RESP_HEADERS" "$RESP_BODY" "$REQ_BODY_LOG"
}
trap cleanup_files EXIT

printf '\377\330\377\340JFIF\000%s' "$ITEM_ID" > "$DRAWING_FILE"
printf 'multipart upload drawing=@%s for different-session last-uploader scenario\n' "$DRAWING_FILE" > "$REQ_BODY_LOG"

# Given
echo "STEP: Given — bootstrap two independent sessions and seed the last upload from session A"
echo "PREREQ: creating synthetic jpeg payload for different-user upload scenario"
[ -s "$DRAWING_FILE" ] || { echo "ASSERTION_FAILED: expected drawing file to exist"; exit 1; }
echo "PREREQ: requesting anonymous session A"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: application/json'
echo "REQUEST_BODY:"
printf '%s\n' '{}'
auth_a_code="$(curl -sS -L -X GET "$BASE_URL/auth/anonymous" -c "$COOKIE_JAR_A" -b "$COOKIE_JAR_A" -D "$AUTH_A_HEADERS" -o "$AUTH_A_BODY" -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$AUTH_A_HEADERS"
echo "RESPONSE_BODY:"
cat "$AUTH_A_BODY"
echo "RESPONSE_STATUS: $auth_a_code"
case "$auth_a_code" in 200|201|204|302|303) ;; *) echo "ASSERTION_FAILED: expected session A auth success got ${auth_a_code}"; exit 1 ;; esac
[ -s "$COOKIE_JAR_A" ] || { echo "ASSERTION_FAILED: expected session A cookie jar to be populated"; exit 1; }
echo "PREREQ: requesting anonymous session B"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: application/json'
echo "REQUEST_BODY:"
printf '%s\n' '{}'
auth_b_code="$(curl -sS -L -X GET "$BASE_URL/auth/anonymous" -c "$COOKIE_JAR_B" -b "$COOKIE_JAR_B" -D "$AUTH_B_HEADERS" -o "$AUTH_B_BODY" -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$AUTH_B_HEADERS"
echo "RESPONSE_BODY:"
cat "$AUTH_B_BODY"
echo "RESPONSE_STATUS: $auth_b_code"
case "$auth_b_code" in 200|201|204|302|303) ;; *) echo "ASSERTION_FAILED: expected session B auth success got ${auth_b_code}"; exit 1 ;; esac
[ -s "$COOKIE_JAR_B" ] || { echo "ASSERTION_FAILED: expected session B cookie jar to be populated"; exit 1; }
echo "PREREQ: upload once with session A so the latest drawing belongs to another session"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: multipart/form-data (curl -F)'
printf 'Cookie jar: %s\n' "$COOKIE_JAR_A"
echo "REQUEST_BODY:"
cat "$REQ_BODY_LOG"
given_code="$(curl -sS -X POST "$BASE_URL/api/upload" \
  -b "$COOKIE_JAR_A" -c "$COOKIE_JAR_A" \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=${ITEM_ID}-seed.jpg" \
  -D "$GIVEN_HEADERS" -o "$GIVEN_BODY" -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$GIVEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$GIVEN_BODY"
echo "RESPONSE_STATUS: $given_code"
[ "$given_code" = "200" ] || { echo "ASSERTION_FAILED: expected seed upload HTTP 200 got ${given_code}"; exit 1; }

# When
echo "STEP: When — perform POST /api/upload with independent session B"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: multipart/form-data (curl -F)'
printf 'Cookie jar: %s\n' "$COOKIE_JAR_B"
echo "REQUEST_BODY:"
cat "$REQ_BODY_LOG"
code="$(curl -sS -X POST "$BASE_URL/api/upload" \
  -b "$COOKIE_JAR_B" -c "$COOKIE_JAR_B" \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=${ITEM_ID}-when.jpg" \
  -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESP_BODY"
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — assert upload is accepted when previous uploader was different"
[ "$code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${code}"; exit 1; }
grep -E 'pathname|drawings/|description|aiImage|url' "$RESP_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected drawing metadata response"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no public API cleanup available for uploaded blob artifacts"

echo "CODEVALID_TEST_ASSERTION_OK:upload_consecutive_allowed_different_user"
