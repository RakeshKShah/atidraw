#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="blob_list_error_propagation"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — target blob.list provider failure behavior"
echo "PREREQ: dependencies.json records blob storage as provisioner:none with no toxiproxy or mock seam; runtime fault injection is not available from this script"

echo "STEP: When — GET /api/drawings"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -H 'Accept: application/json' "$BASE_URL/api/drawings")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $status"

echo "STEP: Then — assert server error if environment actually produces blob provider failure"
case "$status" in
  500|502|503|504)
    ;;
  *)
    echo "ASSERTION_FAILED: expected server error from blob.list failure scenario, but no injectable blob-provider failure seam exists and service returned HTTP ${status}"
    exit 1
    ;;
esac

echo "STEP: Cleanup — no cleanup required for stateless GET"
echo "CODEVALID_TEST_ASSERTION_OK:blob_list_error_propagation"
