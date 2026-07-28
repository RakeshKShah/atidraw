#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/github_auth_redirect_to_draw_cookie_${CASE_SUFFIX}.txt"
GIVEN_HEADERS="/tmp/github_auth_redirect_to_draw_given_headers_${CASE_SUFFIX}.txt"
GIVEN_BODY="/tmp/github_auth_redirect_to_draw_given_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/github_auth_redirect_to_draw_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/github_auth_redirect_to_draw_when_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$GIVEN_HEADERS" "$GIVEN_BODY" "$WHEN_HEADERS" "$WHEN_BODY"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — capture known successful local redirect behavior via anonymous auth"
echo "PREREQ: use anonymous auth because social OAuth completion is intentionally not provisioned in this test stack"
echo 'REQUEST_HEADERS: Accept: */*'
echo 'REQUEST_BODY: '
given_status="$(curl -sS -D "$GIVEN_HEADERS" -o "$GIVEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" "$BASE_URL/auth/anonymous")"
echo 'RESPONSE_HEADERS:'
cat "$GIVEN_HEADERS"
echo 'RESPONSE_BODY:'
cat "$GIVEN_BODY"
echo "RESPONSE_STATUS: $given_status"

# When
echo "STEP: When — request GitHub auth entry point"
echo 'REQUEST_HEADERS: Accept: */*'
echo 'REQUEST_BODY: '
when_status="$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' -c "$COOKIE_JAR" "$BASE_URL/auth/github")"
echo 'RESPONSE_HEADERS:'
cat "$WHEN_HEADERS"
echo 'RESPONSE_BODY:'
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $when_status"

# Then
echo "STEP: Then — assert /draw redirect is available for anonymous success and GitHub starts external OAuth"
given_location="$(grep -i '^location:' "$GIVEN_HEADERS" | tail -n 1 | tr -d '\r' || true)"
when_location="$(grep -i '^location:' "$WHEN_HEADERS" | tail -n 1 | tr -d '\r' || true)"
[ "$given_status" = "302" ] || [ "$given_status" = "303" ] || { echo "ASSERTION_FAILED: expected anonymous auth HTTP 302 or 303 got ${given_status}"; exit 1; }
printf '%s' "$given_location" | grep -Eq '/draw$' || { echo "ASSERTION_FAILED: expected anonymous auth Location to end with /draw, got: ${given_location}"; exit 1; }
[ "$when_status" = "302" ] || [ "$when_status" = "303" ] || { echo "ASSERTION_FAILED: expected GitHub auth HTTP 302 or 303 got ${when_status}"; exit 1; }
[ -n "$when_location" ] || { echo "ASSERTION_FAILED: expected GitHub auth Location header"; exit 1; }
printf '%s' "$when_location" | grep -Eqi 'github|oauth|authorize|login' || { echo "ASSERTION_FAILED: expected GitHub auth redirect to external OAuth flow, got: ${when_location}"; exit 1; }
printf '%s' "$when_location" | grep -Eq '/draw$' && { echo "ASSERTION_FAILED: expected initial GitHub auth entrypoint not to redirect directly to /draw without provider success, got: ${when_location}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary artifacts"
rm -f "$COOKIE_JAR" "$GIVEN_HEADERS" "$GIVEN_BODY" "$WHEN_HEADERS" "$WHEN_BODY"

echo "CODEVALID_TEST_ASSERTION_OK:github_auth_redirect_to_draw"
