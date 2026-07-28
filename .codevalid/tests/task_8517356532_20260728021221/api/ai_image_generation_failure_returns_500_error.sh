#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/ai_image_generation_failure_returns_500_error_cookie_${CASE_SUFFIX}.txt"
AUTH_HEADERS="/tmp/ai_image_generation_failure_returns_500_error_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY="/tmp/ai_image_generation_failure_returns_500_error_auth_body_${CASE_SUFFIX}.txt"
DRAWING_FILE="/tmp/ai_image_generation_failure_returns_500_error_${CASE_SUFFIX}.png"
HEADERS_FILE="/tmp/ai_image_generation_failure_returns_500_error_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/ai_image_generation_failure_returns_500_error_body_${CASE_SUFFIX}.txt"
REQUEST_BODY_FILE="/tmp/ai_image_generation_failure_returns_500_error_request_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$COOKIE_JAR" "$AUTH_HEADERS" "$AUTH_BODY" "$DRAWING_FILE" "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_FILE"
}
trap cleanup_files EXIT

printf 'PNG PLACEHOLDER %s\n' "$CASE_SUFFIX" > "$DRAWING_FILE"
printf '%s\n' "drawing=@${DRAWING_FILE};type=image/png" > "$REQUEST_BODY_FILE"

# Given — bootstrap an authenticated session via /auth/anonymous
SHORT_DESC="authenticated request prepared to observe image-generation failure path"
echo "STEP: Given — ${SHORT_DESC}"
echo "PREREQ: bootstrapping anonymous session via /auth/anonymous"
AUTH_STATUS=$(curl -sS -L -D "$AUTH_HEADERS" -o "$AUTH_BODY" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  "$BASE_URL/auth/anonymous")
echo "RESPONSE_STATUS: $AUTH_STATUS"
[ -s "$COOKIE_JAR" ] || { echo "ASSERTION_FAILED: expected session cookie to be set after /auth/anonymous"; exit 1; }
[ -s "$DRAWING_FILE" ] || { echo "ASSERTION_FAILED: drawing file was not created"; exit 1; }
echo "PREREQ: no mock seam exists for hubAI, so this script validates the failure response shape only when the environment causes image generation to fail"

# When — perform the action under test
SHORT_DESC="POST /api/generate and inspect server error behavior"
echo "STEP: When — ${SHORT_DESC}"
echo "REQUEST_HEADERS: Cookie: (from cookie jar)"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -X POST \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -F "drawing=@${DRAWING_FILE};type=image/png;filename=test-art.png" \
  "$BASE_URL/api/generate")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE" || true
echo
echo "RESPONSE_STATUS: $status"

# Then — HTTP/body assertions
SHORT_DESC="server returns 500 with failed-to-generate-image message"
echo "STEP: Then — ${SHORT_DESC}"
[ "$status" = "500" ] || { echo "ASSERTION_FAILED: expected HTTP 500 got ${status}"; exit 1; }
grep -F 'Failed to generate image' "$BODY_FILE" >/dev/null 2>&1 || {
  echo "ASSERTION_FAILED: expected error message 'Failed to generate image'"
  exit 1
}

# Cleanup — undo Given side effects
SHORT_DESC="remove temporary files"
echo "STEP: Cleanup — ${SHORT_DESC}"
echo "CODEVALID_TEST_ASSERTION_OK:ai_image_generation_failure_returns_500_error"
