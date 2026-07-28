#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="minimal_drawing_processing"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
AUTH_HEADERS="/tmp/${TEST_ID}_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY="/tmp/${TEST_ID}_auth_body_${CASE_SUFFIX}.txt"
GEN_HEADERS="/tmp/${TEST_ID}_generate_headers_${CASE_SUFFIX}.txt"
GEN_BODY="/tmp/${TEST_ID}_generate_body_${CASE_SUFFIX}.bin"
DRAWING_FILE="/tmp/${TEST_ID}_drawing_${CASE_SUFFIX}.png"
AUTH_REQUEST_BODY='{}'

cleanup_files() {
  rm -f "$COOKIE_JAR" "$AUTH_HEADERS" "$AUTH_BODY" "$GEN_HEADERS" "$GEN_BODY" "$DRAWING_FILE"
}
trap cleanup_files EXIT

printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WnSUs8AAAAASUVORK5CYII=' | base64 -d > "$DRAWING_FILE"

# Given — bring the system to the required state
echo "STEP: Given — bootstrap authenticated anonymous session and prepare minimal 1x1 PNG drawing"
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
echo "STEP: When — upload minimal drawing to POST /api/generate"
echo "REQUEST_HEADERS: multipart/form-data (curl generated); Cookie jar: ${COOKIE_JAR}"
echo "REQUEST_BODY: drawing=@${DRAWING_FILE};type=image/png"
code="$(curl -sS -D "$GEN_HEADERS" -o "$GEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" -b "$COOKIE_JAR" -F "drawing=@${DRAWING_FILE};type=image/png;filename=blank-canvas.png" "$BASE_URL/api/generate")"
echo "RESPONSE_HEADERS:"
cat "$GEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$GEN_BODY"
echo "RESPONSE_STATUS: ${code}"

# Then — HTTP/body assertions
echo "STEP: Then — verify minimal drawing is processed successfully"
[ "$code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${code}"; exit 1; }
grep -i '^x-description:' "$GEN_HEADERS" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected x-description header"; exit 1; }
[ -s "$GEN_BODY" ] || { echo "ASSERTION_FAILED: expected non-empty generated image body"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove temporary files only"

echo "CODEVALID_TEST_ASSERTION_OK:minimal_drawing_processing"
