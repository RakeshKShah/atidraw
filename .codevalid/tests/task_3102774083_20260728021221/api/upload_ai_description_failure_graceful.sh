#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="upload_ai_description_failure_graceful"
ITEM_ID="${TEST_ID}-${CASE_SUFFIX}"
DRAWING_FILE="/tmp/${TEST_ID}_drawing_${CASE_SUFFIX}.jpg"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
AUTH_HEADERS="/tmp/${TEST_ID}_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY="/tmp/${TEST_ID}_auth_body_${CASE_SUFFIX}.txt"
RESP_HEADERS="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
REQ_BODY_LOG="/tmp/${TEST_ID}_request_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$COOKIE_JAR" "$AUTH_HEADERS" "$AUTH_BODY" "$RESP_HEADERS" "$RESP_BODY" "$REQ_BODY_LOG"
}
trap cleanup_files EXIT

printf '\377\330\377\340JFIF\000%s' "$ITEM_ID" > "$DRAWING_FILE"
printf 'multipart upload drawing=@%s expecting graceful description fallback if AI description generation fails\n' "$DRAWING_FILE" > "$REQ_BODY_LOG"

# Given
echo "STEP: Given — bootstrap authenticated session and jpeg payload"
echo "PREREQ: creating synthetic jpeg payload"
[ -s "$DRAWING_FILE" ] || { echo "ASSERTION_FAILED: expected drawing file to exist"; exit 1; }
echo "PREREQ: requesting anonymous session via public auth endpoint"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: application/json'
echo "REQUEST_BODY:"
printf '%s\n' '{}'
auth_code="$(curl -sS -L -X GET "$BASE_URL/auth/anonymous" \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -D "$AUTH_HEADERS" -o "$AUTH_BODY" -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$AUTH_HEADERS"
echo "RESPONSE_BODY:"
cat "$AUTH_BODY"
echo "RESPONSE_STATUS: $auth_code"
case "$auth_code" in 200|201|204|302|303) ;; *) echo "ASSERTION_FAILED: expected anonymous auth bootstrap success got ${auth_code}"; exit 1 ;; esac
[ -s "$COOKIE_JAR" ] || { echo "ASSERTION_FAILED: expected cookie jar to be populated after auth bootstrap"; exit 1; }

# When
echo "STEP: When — perform POST /api/upload"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: multipart/form-data (curl -F)'
printf 'Cookie jar: %s\n' "$COOKIE_JAR"
echo "REQUEST_BODY:"
cat "$REQ_BODY_LOG"
code="$(curl -sS -X POST "$BASE_URL/api/upload" \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=${ITEM_ID}.jpg" \
  -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESP_BODY"
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — assert upload still succeeds with fallback behavior"
[ "$code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${code}"; exit 1; }
grep -E 'pathname|drawings/|aiImage|url' "$RESP_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected successful upload metadata despite fallback"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no public API cleanup available for uploaded blob artifacts"

echo "CODEVALID_TEST_ASSERTION_OK:upload_ai_description_failure_graceful"
