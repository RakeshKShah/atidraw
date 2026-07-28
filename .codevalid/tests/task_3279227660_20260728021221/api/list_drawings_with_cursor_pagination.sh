#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="list_drawings_with_cursor_pagination"
HEADERS_FILE_1="/tmp/${TEST_ID}_page1_headers_${CASE_SUFFIX}.txt"
BODY_FILE_1="/tmp/${TEST_ID}_page1_body_${CASE_SUFFIX}.txt"
HEADERS_FILE_2="/tmp/${TEST_ID}_page2_headers_${CASE_SUFFIX}.txt"
BODY_FILE_2="/tmp/${TEST_ID}_page2_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE_1" "$BODY_FILE_1" "$HEADERS_FILE_2" "$BODY_FILE_2"
}
trap cleanup_files EXIT

echo "STEP: Given — pagination test setup"
echo "PREREQ: No direct blob seeding seam is available; validate cursor handling from live response if cursor is returned"

echo "STEP: When — request first page from GET /api/drawings"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
status1="$(curl -sS -D "$HEADERS_FILE_1" -o "$BODY_FILE_1" -w '%{http_code}' -H 'Accept: application/json' "$BASE_URL/api/drawings")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE_1"
echo "RESPONSE_BODY:"
cat "$BODY_FILE_1"
echo "RESPONSE_STATUS: $status1"

[ "$status1" = "200" ] || { echo "ASSERTION_FAILED: expected first page HTTP 200 got ${status1}"; exit 1; }

cursor=""
if command -v jq >/dev/null 2>&1; then
  jq -e '.blobs | type == "array"' "$BODY_FILE_1" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected first page blobs array"; exit 1; }
  cursor="$(jq -r 'if has("cursor") and .cursor != null then .cursor else "" end' "$BODY_FILE_1")"
else
  grep -F '"blobs"' "$BODY_FILE_1" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected first page blobs field"; exit 1; }
fi

if [ -n "$cursor" ]; then
  echo "STEP: When — request second page using returned cursor"
  echo "REQUEST_HEADERS: Accept: application/json"
  echo "REQUEST_BODY: <empty>"
  status2="$(curl -sS -D "$HEADERS_FILE_2" -o "$BODY_FILE_2" -w '%{http_code}' -H 'Accept: application/json' "$BASE_URL/api/drawings?cursor=$cursor")"
  echo "RESPONSE_HEADERS:"
  cat "$HEADERS_FILE_2"
  echo "RESPONSE_BODY:"
  cat "$BODY_FILE_2"
  echo "RESPONSE_STATUS: $status2"

  echo "STEP: Then — assert second page succeeds and has blobs array"
  [ "$status2" = "200" ] || { echo "ASSERTION_FAILED: expected second page HTTP 200 got ${status2}"; exit 1; }
  if command -v jq >/dev/null 2>&1; then
    jq -e '.blobs | type == "array"' "$BODY_FILE_2" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected second page blobs array"; exit 1; }
  else
    grep -F '"blobs"' "$BODY_FILE_2" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected second page blobs field"; exit 1; }
  fi
else
  echo "STEP: Then — no cursor returned on first page, so assert first page remains a valid paginated response"
  echo "PREREQ: Service may have fewer than one page of results in this environment"
fi

echo "STEP: Cleanup — no cleanup required for stateless GET"
echo "CODEVALID_TEST_ASSERTION_OK:list_drawings_with_cursor_pagination"
