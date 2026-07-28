#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="upload_content_moderation_rejection"
COOKIE_JAR="${COOKIE_JAR:-/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt}"
AUTH_HEADER="${AUTH_HEADER:-}"
DRAWING_FILE="/tmp/${TEST_ID}_drawing_${CASE_SUFFIX}.jpg"
REQ_BODY_LOG="/tmp/${TEST_ID}_request_body_${CASE_SUFFIX}.txt"
RESP_HEADERS="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
RESP_BODY="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$DRAWING_FILE" "$REQ_BODY_LOG" "$RESP_HEADERS" "$RESP_BODY"
}
trap cleanup_files EXIT

printf '\377\330\377\340JFIF\000moderation-reject-%s' "$CASE_SUFFIX" > "$DRAWING_FILE"
printf 'multipart upload expecting moderation rejection @%s\n' "$DRAWING_FILE" > "$REQ_BODY_LOG"

# Given
echo "STEP: Given — prepare authenticated jpeg expected to trigger moderation"
echo "PREREQ: caller must provide authenticated session and an environment where AI description includes prohibited text"
[ -s "$DRAWING_FILE" ] || { echo "ASSERTION_FAILED: expected drawing file to exist"; exit 1; }
if [ ! -s "$COOKIE_JAR" ] && [ -z "$AUTH_HEADER" ]; then
  echo "ASSERTION_FAILED: this scenario requires COOKIE_JAR or AUTH_HEADER for an authenticated session"
  exit 1
fi

# When
echo "STEP: When — POST drawing to /api/upload expecting moderation rejection"
echo "REQUEST_HEADERS:"
printf '%s\n' 'Content-Type: multipart/form-data (curl -F)'
if [ -n "$AUTH_HEADER" ]; then printf '%s\n' "$AUTH_HEADER"; else printf '%s\n' "Cookie jar: $COOKIE_JAR"; fi
echo "REQUEST_BODY:"
cat "$REQ_BODY_LOG"
if [ -n "$AUTH_HEADER" ]; then
  code="$(curl -sS -X POST "$BASE_URL/api/upload" -H "$AUTH_HEADER" -b "$COOKIE_JAR" -c "$COOKIE_JAR" -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=drawing.jpeg" -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
else
  code="$(curl -sS -X POST "$BASE_URL/api/upload" -b "$COOKIE_JAR" -c "$COOKIE_JAR" -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=drawing.jpeg" -D "$RESP_HEADERS" -o "$RESP_BODY" -w '%{http_code}')"
fi

echo "RESPONSE_HEADERS:"
cat "$RESP_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESP_BODY"
echo "RESPONSE_STATUS: $code"

# Then
echo "STEP: Then — assert inappropriate content is rejected"
[ "$code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${code}"; exit 1; }
grep -F 'You cannot upload this kind of drawings.' "$RESP_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected moderation rejection message"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup available through public API"
echo "CODEVALID_TEST_ASSERTION_OK:upload_content_moderation_rejection"
