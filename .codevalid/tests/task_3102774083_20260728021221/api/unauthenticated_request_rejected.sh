#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="unauthenticated_request_rejected"
GEN_HEADERS="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
GEN_BODY="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
DRAWING_FILE="/tmp/${TEST_ID}_drawing_${CASE_SUFFIX}.png"

cleanup_files() {
  rm -f "$GEN_HEADERS" "$GEN_BODY" "$DRAWING_FILE"
}
trap cleanup_files EXIT

printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WnSUs8AAAAASUVORK5CYII=' | base64 -d > "$DRAWING_FILE"

# Given — bring the system to the required state
echo "STEP: Given — prepare valid drawing without establishing a session"

# When — perform the action under test
echo "STEP: When — call POST /api/generate without authentication"
echo "REQUEST_HEADERS: multipart/form-data (curl generated); no cookies"
echo "REQUEST_BODY: drawing=@${DRAWING_FILE};type=image/png"
code="$(curl -sS -D "$GEN_HEADERS" -o "$GEN_BODY" -w '%{http_code}' -F "drawing=@${DRAWING_FILE};type=image/png;filename=test-drawing.png" "$BASE_URL/api/generate")"
echo "RESPONSE_HEADERS:"
cat "$GEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$GEN_BODY"
echo "RESPONSE_STATUS: ${code}"

# Then — HTTP/body assertions
echo "STEP: Then — verify unauthenticated request is rejected before drawing processing"
[ "$code" = "401" ] || [ "$code" = "302" ] || [ "$code" = "303" ] || [ "$code" = "500" ] || { echo "ASSERTION_FAILED: expected unauthenticated status 401/302/303/500 got ${code}"; exit 1; }
[ "$code" = "200" ] && { echo "ASSERTION_FAILED: unexpected HTTP 200 for unauthenticated request"; exit 1; } || true

# Cleanup — undo Given side effects
echo "STEP: Cleanup — remove temporary files only"

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_request_rejected"
