#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/large_drawing_file_processed_successfully_cookie_${CASE_SUFFIX}.txt"
AUTH_HEADERS="/tmp/large_drawing_file_processed_successfully_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY="/tmp/large_drawing_file_processed_successfully_auth_body_${CASE_SUFFIX}.txt"
DRAWING_FILE="/tmp/large_drawing_file_processed_successfully_${CASE_SUFFIX}.png"
HEADERS_FILE="/tmp/large_drawing_file_processed_successfully_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/large_drawing_file_processed_successfully_body_${CASE_SUFFIX}.bin"
REQUEST_BODY_FILE="/tmp/large_drawing_file_processed_successfully_request_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$COOKIE_JAR" "$AUTH_HEADERS" "$AUTH_BODY" "$DRAWING_FILE" "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_FILE"
}
trap cleanup_files EXIT

# Create a moderately large payload without relying on extra binaries.
awk 'BEGIN { for (i = 0; i < 250000; i++) print "PNG-LARGE-PLACEHOLDER-LINE" }' > "$DRAWING_FILE"
printf '%s\n' "drawing=@${DRAWING_FILE};type=image/png" > "$REQUEST_BODY_FILE"

# Given — bootstrap an authenticated session via /auth/anonymous
SHORT_DESC="authenticated user with larger drawing payload"
echo "STEP: Given — ${SHORT_DESC}"
echo "PREREQ: bootstrapping anonymous session via /auth/anonymous"
AUTH_STATUS=$(curl -sS -L -D "$AUTH_HEADERS" -o "$AUTH_BODY" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  "$BASE_URL/auth/anonymous")
echo "RESPONSE_STATUS: $AUTH_STATUS"
[ -s "$COOKIE_JAR" ] || { echo "ASSERTION_FAILED: expected session cookie to be set after /auth/anonymous"; exit 1; }
[ -s "$DRAWING_FILE" ] || { echo "ASSERTION_FAILED: large drawing file was not created"; exit 1; }

# When — perform the action under test
SHORT_DESC="POST /api/generate with larger multipart payload"
echo "STEP: When — ${SHORT_DESC}"
echo "REQUEST_HEADERS: Cookie: (from cookie jar)"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
status="$(curl -sS --max-time 30 -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -X POST \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -F "drawing=@${DRAWING_FILE};type=image/png;filename=detailed-artwork.png" \
  "$BASE_URL/api/generate")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE" || true
echo
echo "RESPONSE_STATUS: $status"

# Then — HTTP/body assertions
SHORT_DESC="large payload completes successfully with alt text and image"
echo "STEP: Then — ${SHORT_DESC}"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
description_header="$(awk 'BEGIN{IGNORECASE=1} /^x-description:/ {sub(/^x-description:[[:space:]]*/, ""); sub(/\r$/, ""); print; exit}' "$HEADERS_FILE")"
[ -n "$description_header" ] || { echo "ASSERTION_FAILED: expected non-empty x-description header"; exit 1; }
content_type_header="$(awk 'BEGIN{IGNORECASE=1} /^content-type:/ {sub(/^content-type:[[:space:]]*/, ""); sub(/\r$/, ""); print; exit}' "$HEADERS_FILE")"
case "$content_type_header" in
  image/*) ;;
  *) echo "ASSERTION_FAILED: expected image/* content-type got ${content_type_header}"; exit 1 ;;
esac
[ -s "$BODY_FILE" ] || { echo "ASSERTION_FAILED: expected non-empty generated image body"; exit 1; }

# Cleanup — undo Given side effects
SHORT_DESC="remove temporary files"
echo "STEP: Cleanup — ${SHORT_DESC}"
echo "CODEVALID_TEST_ASSERTION_OK:large_drawing_file_processed_successfully"
