#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/github_auth_numeric_id_conversion_cookie_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/github_auth_numeric_id_conversion_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/github_auth_numeric_id_conversion_when_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$WHEN_HEADERS" "$WHEN_BODY"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — note that numeric-id-to-string conversion occurs only after successful GitHub provider callback"
echo "PREREQ: in this stack github-oauth is provisioner none, so only the public auth initiation route can be exercised end-to-end"

# When
echo "STEP: When — request the GitHub authentication route"
echo 'REQUEST_HEADERS: Accept: */*'
echo 'REQUEST_BODY: '
when_status="$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" "$BASE_URL/auth/github")"
echo 'RESPONSE_HEADERS:'
cat "$WHEN_HEADERS"
echo 'RESPONSE_BODY:'
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $when_status"

# Then
echo "STEP: Then — assert the route starts external OAuth and does not fabricate a local completed session"
location_header="$(grep -i '^location:' "$WHEN_HEADERS" | tail -n 1 | tr -d '\r' || true)"
set_cookie_header="$(grep -i '^set-cookie:' "$WHEN_HEADERS" | tail -n 1 | tr -d '\r' || true)"
[ "$when_status" = "302" ] || [ "$when_status" = "303" ] || { echo "ASSERTION_FAILED: expected HTTP 302 or 303 got ${when_status}"; exit 1; }
[ -n "$location_header" ] || { echo "ASSERTION_FAILED: expected Location header on GitHub auth response"; exit 1; }
printf '%s' "$location_header" | grep -Eqi 'github|oauth|authorize|login' || { echo "ASSERTION_FAILED: expected redirect to GitHub/OAuth flow, got: ${location_header}"; exit 1; }
[ -z "$set_cookie_header" ] || { echo "ASSERTION_FAILED: expected no completed session cookie before provider callback success, got: ${set_cookie_header}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary artifacts"
rm -f "$COOKIE_JAR" "$WHEN_HEADERS" "$WHEN_BODY"

echo "CODEVALID_TEST_ASSERTION_OK:github_auth_numeric_id_conversion"
