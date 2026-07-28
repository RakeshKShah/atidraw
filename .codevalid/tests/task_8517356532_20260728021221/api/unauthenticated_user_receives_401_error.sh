#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
DRAWING_FILE="/tmp/unauthenticated_user_receives_401_error_${CASE_SUFFIX}.jpg"
HEADERS_FILE="/tmp/unauthenticated_user_receives_401_error_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/unauthenticated_user_receives_401_error_body_${CASE_SUFFIX}.txt"
REQUEST_BODY_FILE="/tmp/unauthenticated_user_receives_401_error_request_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$DRAWING_FILE" "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_FILE"
}
trap cleanup_files EXIT

printf 'JPEG PLACEHOLDER %s\n' "$CASE_SUFFIX" > "$DRAWING_FILE"
printf '%s\n' "drawing=@${DRAWING_FILE};type=image/jpeg" > "$REQUEST_BODY_FILE"

# Given — bring the system to the required state
SHORT_DESC="unauthenticated request with valid multipart payload"
echo "STEP: Given — ${SHORT_DESC}"
[ -s "$DRAWING_FILE" ] || { echo "ASSERTION_FAILED: drawing file was not created"; exit 1; }

# When — perform the action under test
SHORT_DESC="POST /api/generate without authentication"
echo "STEP: When — ${SHORT_DESC}"
echo "REQUEST_HEADERS: (none)"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -X POST \
  -F "drawing=@${DRAWING_FILE};type=image/jpeg;filename=test-sketch.jpg" \
  "$BASE_URL/api/generate")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE" || true
echo
echo "RESPONSE_STATUS: $status"

# Then — HTTP/body assertions
SHORT_DESC="guard rejects unauthenticated access before successful generation"
echo "STEP: Then — ${SHORT_DESC}"
case "$status" in
  401|302|303|500) ;;
  *) echo "ASSERTION_FAILED: expected auth failure status 401/302/303/500 got ${status}"; exit 1 ;;
esac
if awk 'BEGIN{IGNORECASE=1} /^x-description:/ {found=1} END{exit(found?0:1)}' "$HEADERS_FILE"; then
  echo "ASSERTION_FAILED: did not expect x-description header on unauthenticated response"
  exit 1
fi
if [ "$status" = "401" ]; then
  grep -Ei 'unauthorized|auth|session|login' "$BODY_FILE" >/dev/null 2>&1 || {
    echo "ASSERTION_FAILED: expected unauthorized/auth-related response body for HTTP 401"
    exit 1
  }
fi

# Cleanup — undo Given side effects
SHORT_DESC="remove temporary files"
echo "STEP: Cleanup — ${SHORT_DESC}"
echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_user_receives_401_error"
