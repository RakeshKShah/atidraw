#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
AUTH_COOKIE="${AUTH_COOKIE:-}"
DRAWING_FILE="/tmp/valid_drawing_receives_descriptive_single_sentence_alt_text_${CASE_SUFFIX}.png"
HEADERS_FILE="/tmp/valid_drawing_receives_descriptive_single_sentence_alt_text_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/valid_drawing_receives_descriptive_single_sentence_alt_text_body_${CASE_SUFFIX}.bin"
REQUEST_BODY_FILE="/tmp/valid_drawing_receives_descriptive_single_sentence_alt_text_request_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$DRAWING_FILE" "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_FILE"
}
trap cleanup_files EXIT

printf 'PNG PLACEHOLDER %s landscape scene\n' "$CASE_SUFFIX" > "$DRAWING_FILE"
printf '%s\n' "drawing=@${DRAWING_FILE};type=image/png" > "$REQUEST_BODY_FILE"

# Given — bring the system to the required state
SHORT_DESC="authenticated user with recognizable drawing"
echo "STEP: Given — ${SHORT_DESC}"
if [ -z "$AUTH_COOKIE" ]; then
  echo "ASSERTION_FAILED: AUTH_COOKIE must be provided for authenticated generate endpoint tests"
  exit 1
fi
[ -s "$DRAWING_FILE" ] || { echo "ASSERTION_FAILED: drawing file was not created"; exit 1; }

# When — perform the action under test
SHORT_DESC="POST /api/generate and capture x-description alt text"
echo "STEP: When — ${SHORT_DESC}"
echo "REQUEST_HEADERS: Cookie: ${AUTH_COOKIE}"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -X POST \
  -H "Cookie: ${AUTH_COOKIE}" \
  -F "drawing=@${DRAWING_FILE};type=image/png;filename=landscape-scene.png" \
  "$BASE_URL/api/generate")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE" || true
echo
echo "RESPONSE_STATUS: $status"

# Then — HTTP/body assertions
SHORT_DESC="x-description is non-empty and sentence-like"
echo "STEP: Then — ${SHORT_DESC}"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
description_header="$(awk 'BEGIN{IGNORECASE=1} /^x-description:/ {sub(/^x-description:[[:space:]]*/, ""); sub(/\r$/, ""); print; exit}' "$HEADERS_FILE")"
[ -n "$description_header" ] || { echo "ASSERTION_FAILED: expected non-empty x-description header"; exit 1; }
printf '%s' "$description_header" | grep -E '[.!?]$' >/dev/null 2>&1 || {
  echo "ASSERTION_FAILED: expected x-description to look like a complete sentence ending with punctuation"
  exit 1
}
word_count="$(printf '%s\n' "$description_header" | awk '{print NF}')"
[ "$word_count" -ge 3 ] || { echo "ASSERTION_FAILED: expected descriptive alt text with at least 3 words"; exit 1; }
[ -s "$BODY_FILE" ] || { echo "ASSERTION_FAILED: expected non-empty generated image body"; exit 1; }

# Cleanup — undo Given side effects
SHORT_DESC="remove temporary files"
echo "STEP: Cleanup — ${SHORT_DESC}"
echo "CODEVALID_TEST_ASSERTION_OK:valid_drawing_receives_descriptive_single_sentence_alt_text"
