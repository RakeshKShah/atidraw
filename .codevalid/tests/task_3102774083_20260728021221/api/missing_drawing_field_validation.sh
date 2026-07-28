#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="missing_drawing_field_validation"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
AUTH_HEADERS="/tmp/${TEST_ID}_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY="/tmp/${TEST_ID}_auth_body_${CASE_SUFFIX}.txt"
GEN_HEADERS="/tmp/${TEST_ID}_generate_headers_${CASE_SUFFIX}.txt"
GEN_BODY="/tmp/${TEST_ID}_generate_body_${CASE_SUFFIX}.txt"
AUTH_REQUEST_BODY='{}'

cleanup_files() {
  rm -f "$COOKIE_JAR" "$AUTH_HEADERS" "$AUTH_BODY" "$GEN_HEADERS" "$GEN_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — bootstrap authenticated anonymous session without preparing drawing field"
echo "PREREQ: create anonymous authenticated session"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY: ${AUTH_REQUEST_BODY}"
auth_code="$(curl -sS -L -D "$AUTH_HEADERS" -o "$AUTH_BODY" -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" -X GET "$BASE_URL/auth/anonymous")"
echo "RESPONSE_HEADERS:"
cat "$AUTH_HEADERS"
echo "RESPONSE_BODY:"
cat "$AUTH_BODY"
echo "RESPONSE_STATUS: ${auth_code}"
[ "$auth_code" = "200" ] || [ "$auth_code" = "302" ] || [ "$auth_code" = "303" ] || { echo "ASSERTION_FAILED: expected auth bootstrap HTTP 200/302/303 got ${auth_code}"; exit 1; }
[ -s "$COOKIE_JAR" ] || { echo "ASSERTION_FAILED: expected cookie jar to be populated"; exit 1; }

# When — perform the action under test
echo "STEP: When — call POST /api/generate with multipart form missing drawing field"
echo "REQUEST_HEADERS: multipart/form-data (curl generated); Cookie jar: ${COOKIE_JAR}"
echo "REQUEST_BODY: unrelated=value"
code="$(curl -sS -D "$GEN_HEADERS" -o "$GEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" -F "unrelated=value" "$BASE_URL/api/generate")"
echo "RESPONSE_HEADERS:"
cat "$GEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$GEN_BODY"
echo "RESPONSE_STATUS: ${code}"

# Then — HTTP/body assertions
echo "STEP: Then — verify request fails when drawing field is absent"
[ "$code" = "400" ] || [ "$code" = "500" ] || { echo "ASSERTION_FAILED: expected HTTP 400 or 500 for missing drawing field got ${code}"; exit 1; }
[ "$code" = "200" ] && { echo "ASSERTION_FAILED: unexpected HTTP 200 when drawing field is missing"; exit 1; } || true

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove temporary files only"

echo "CODEVALID_TEST_ASSERTION_OK:missing_drawing_field_validation"
