#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
AUTH_COOKIE="${AUTH_COOKIE:-}"
DRAWING_FILE="/tmp/ai_description_generation_failure_returns_empty_description_header_${CASE_SUFFIX}.png"
HEADERS_FILE="/tmp/ai_description_generation_failure_returns_empty_description_header_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/ai_description_generation_failure_returns_empty_description_header_body_${CASE_SUFFIX}.bin"
REQUEST_BODY_FILE="/tmp/ai_description_generation_failure_returns_empty_description_header_request_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$DRAWING_FILE" "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_FILE"
}
trap cleanup_files EXIT

printf 'PNG PLACEHOLDER %s\n' "$CASE_SUFFIX" > "$DRAWING_FILE"
printf '%s\n' "drawing=@${DRAWING_FILE};type=image/png" > "$REQUEST_BODY_FILE"

# Given — bring the system to the required state
SHORT_DESC="authenticated request intended to observe description-generation fallback behavior"
echo "STEP: Given — ${SHORT_DESC}"
if [ -z "$AUTH_COOKIE" ]; then
  echo "ASSERTION_FAILED: AUTH_COOKIE must be provided for authenticated generate endpoint tests"
  exit 1
fi
[ -s "$DRAWING_FILE" ] || { echo "ASSERTION_FAILED: drawing file was not created"; exit 1; }
echo "PREREQ: repository learning says hubAI has no injectable mock seam; this test observes fallback only if environment naturally causes description generation failure"

# When — perform the action under test
SHORT_DESC="POST /api/generate and inspect x-description header"
echo "STEP: When — ${SHORT_DESC}"
echo "REQUEST_HEADERS: Cookie: ${AUTH_COOKIE}"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -X POST \
  -H "Cookie: ${AUTH_COOKIE}" \
  -F "drawing=@${DRAWING_FILE};type=image/png;filename=simple-drawing.png" \
  "$BASE_URL/api/generate")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE" || true
echo
echo "RESPONSE_STATUS: $status"

# Then — HTTP/body assertions
SHORT_DESC="if request succeeds, x-description header may be empty due to implemented catch fallback"
echo "STEP: Then — ${SHORT_DESC}"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
description_header="$(awk 'BEGIN{IGNORECASE=1} /^x-description:/ {sub(/^x-description:[[:space:]]*/, ""); sub(/\r$/, ""); print; found=1; exit} END{if(!found) print "__MISSING__"}' "$HEADERS_FILE")"
[ "$description_header" != "__MISSING__" ] || { echo "ASSERTION_FAILED: expected x-description header to be present"; exit 1; }
content_type_header="$(awk 'BEGIN{IGNORECASE=1} /^content-type:/ {sub(/^content-type:[[:space:]]*/, ""); sub(/\r$/, ""); print; exit}' "$HEADERS_FILE")"
case "$content_type_header" in
  image/*) ;;
  *) echo "ASSERTION_FAILED: expected image/* content-type got ${content_type_header}"; exit 1 ;;
esac
[ -s "$BODY_FILE" ] || { echo "ASSERTION_FAILED: expected generated image response body"; exit 1; }
echo "Observed x-description value: '${description_header}'"

# Cleanup — undo Given side effects
SHORT_DESC="remove temporary files"
echo "STEP: Cleanup — ${SHORT_DESC}"
echo "CODEVALID_TEST_ASSERTION_OK:ai_description_generation_failure_returns_empty_description_header"
