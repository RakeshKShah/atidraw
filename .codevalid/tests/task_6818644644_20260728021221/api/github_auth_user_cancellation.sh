#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/github_auth_user_cancellation_cookie_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/github_auth_user_cancellation_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/github_auth_user_cancellation_when_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$WHEN_HEADERS" "$WHEN_BODY"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare a cancelled GitHub authorization callback"
echo "PREREQ: simulate provider cancellation by sending error=access_denied to the public callback route"

# When
echo "STEP: When — call GitHub auth callback with user cancellation parameters"
echo 'REQUEST_HEADERS: Accept: */*'
echo 'REQUEST_BODY: '
when_status="$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" "$BASE_URL/auth/github?error=access_denied&error_description=user-cancelled-${CASE_SUFFIX}")"
echo 'RESPONSE_HEADERS:'
cat "$WHEN_HEADERS"
echo 'RESPONSE_BODY:'
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $when_status"

# Then
echo "STEP: Then — assert cancellation does not establish a successful draw session"
location_header="$(grep -i '^location:' "$WHEN_HEADERS" | tail -n 1 | tr -d '\r' || true)"
set_cookie_header="$(grep -i '^set-cookie:' "$WHEN_HEADERS" | tail -n 1 | tr -d '\r' || true)"
[ "$when_status" != "500" ] || { echo "ASSERTION_FAILED: unexpected HTTP 500 for cancelled OAuth callback"; exit 1; }
if [ -n "$location_header" ]; then
  printf '%s' "$location_header" | grep -Eq '/draw$' && { echo "ASSERTION_FAILED: expected cancelled auth not to redirect to /draw, got: ${location_header}"; exit 1; }
fi
[ -z "$set_cookie_header" ] || { echo "ASSERTION_FAILED: expected no authenticated session cookie on cancellation, got: ${set_cookie_header}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary artifacts"
rm -f "$COOKIE_JAR" "$WHEN_HEADERS" "$WHEN_BODY"

echo "CODEVALID_TEST_ASSERTION_OK:github_auth_user_cancellation"
