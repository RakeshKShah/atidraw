#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="drawing_file_missing_from_request"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
LOGIN_HEADERS="/tmp/${TEST_ID}_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY="/tmp/${TEST_ID}_login_body_${CASE_SUFFIX}.txt"
RESPONSE_HEADERS="/tmp/${TEST_ID}_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/${TEST_ID}_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$LOGIN_HEADERS" "$LOGIN_BODY" "$RESPONSE_HEADERS" "$RESPONSE_BODY"
}
trap cleanup_files EXIT

echo "STEP: Given — bootstrap authenticated session"
echo "PREREQ: create anonymous auth session for protected endpoint"
echo "REQUEST_HEADERS: Accept: */*"
echo "REQUEST_BODY: <empty>"
login_code=$(curl -sS -D "$LOGIN_HEADERS" -o "$LOGIN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" "$BASE_URL/auth/anonymous")
echo "RESPONSE_HEADERS:"
cat "$LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$LOGIN_BODY"
echo "RESPONSE_STATUS: $login_code"
[ "$login_code" = "200" ] || [ "$login_code" = "302" ] || [ "$login_code" = "303" ] || { echo "ASSERTION_FAILED: expected auth bootstrap HTTP 200/302/303 got ${login_code}"; exit 1; }

echo "STEP: When — submit multipart request without drawing field"
echo "REQUEST_HEADERS: Cookie jar=$COOKIE_JAR; Content-Type: multipart/form-data"
echo "REQUEST_BODY: otherField=value"
response_code=$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST -F "otherField=value" "$BASE_URL/api/generate")
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"
echo "RESPONSE_STATUS: $response_code"

echo "STEP: Then — missing drawing causes server error response"
[ "$response_code" = "500" ] || [ "$response_code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 or 500 got ${response_code}"; exit 1; }

echo "STEP: Cleanup — no persistent cleanup required"
echo "CODEVALID_TEST_ASSERTION_OK:drawing_file_missing_from_request"
