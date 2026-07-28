#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/github_auth_oauth_error_cookie_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/github_auth_oauth_error_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/github_auth_oauth_error_when_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$WHEN_HEADERS" "$WHEN_BODY"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare an OAuth error callback request"
echo "PREREQ: GitHub OAuth is not mocked in this stack, but the public callback route can still be exercised with an error query parameter"

# When
echo "STEP: When — send GitHub callback request carrying an OAuth error"
echo 'REQUEST_HEADERS: Accept: */*'
echo 'REQUEST_BODY: '
when_status="$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" "$BASE_URL/auth/github?error=access_denied&error_description=simulated-${CASE_SUFFIX}")"
echo 'RESPONSE_HEADERS:'
cat "$WHEN_HEADERS"
echo 'RESPONSE_BODY:'
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $when_status"

# Then
echo "STEP: Then — assert no successful authenticated redirect to draw occurs"
location_header="$(grep -i '^location:' "$WHEN_HEADERS" | tail -n 1 | tr -d '\r' || true)"
set_cookie_header="$(grep -i '^set-cookie:' "$WHEN_HEADERS" | tail -n 1 | tr -d '\r' || true)"
[ "$when_status" != "500" ] || { echo "ASSERTION_FAILED: unexpected HTTP 500 for OAuth error callback"; exit 1; }
if [ -n "$location_header" ]; then
  printf '%s' "$location_header" | grep -Eq '/draw$' && { echo "ASSERTION_FAILED: expected OAuth error flow to avoid redirecting to /draw, got: ${location_header}"; exit 1; }
fi
[ -z "$set_cookie_header" ] || { echo "ASSERTION_FAILED: expected no authenticated session cookie on OAuth error, got: ${set_cookie_header}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary artifacts"
rm -f "$COOKIE_JAR" "$WHEN_HEADERS" "$WHEN_BODY"

echo "CODEVALID_TEST_ASSERTION_OK:github_auth_oauth_error"
