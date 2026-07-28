#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/various_image_formats_supported_cookie_${CASE_SUFFIX}.txt"
AUTH_HEADERS="/tmp/various_image_formats_supported_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY="/tmp/various_image_formats_supported_auth_body_${CASE_SUFFIX}.txt"
PNG_FILE="/tmp/various_image_formats_supported_${CASE_SUFFIX}.png"
JPG_FILE="/tmp/various_image_formats_supported_${CASE_SUFFIX}.jpg"
JPEG_FILE="/tmp/various_image_formats_supported_${CASE_SUFFIX}.jpeg"
HEADERS_FILE="/tmp/various_image_formats_supported_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/various_image_formats_supported_body_${CASE_SUFFIX}.bin"
REQUEST_BODY_FILE="/tmp/various_image_formats_supported_request_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$COOKIE_JAR" "$AUTH_HEADERS" "$AUTH_BODY" "$PNG_FILE" "$JPG_FILE" "$JPEG_FILE" "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_FILE"
}
trap cleanup_files EXIT

printf 'PNG PLACEHOLDER %s\n' "$CASE_SUFFIX" > "$PNG_FILE"
printf 'JPG PLACEHOLDER %s\n' "$CASE_SUFFIX" > "$JPG_FILE"
printf 'JPEG PLACEHOLDER %s\n' "$CASE_SUFFIX" > "$JPEG_FILE"

run_case() {
  file_path="$1"
  file_type="$2"
  file_name="$3"
  printf '%s\n' "drawing=@${file_path};type=${file_type}" > "$REQUEST_BODY_FILE"
  echo "PREREQ: preparing format case ${file_name}"
  echo "REQUEST_HEADERS: Cookie: (from cookie jar)"
  echo "REQUEST_BODY:"
  cat "$REQUEST_BODY_FILE"
  status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -X POST \
    -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
    -F "drawing=@${file_path};type=${file_type};filename=${file_name}" \
    "$BASE_URL/api/generate")"
  echo "RESPONSE_HEADERS:"
  cat "$HEADERS_FILE"
  echo "RESPONSE_BODY:"
  cat "$BODY_FILE" || true
  echo
  echo "RESPONSE_STATUS: $status"
  [ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 for ${file_name} got ${status}"; exit 1; }
  description_header="$(awk 'BEGIN{IGNORECASE=1} /^x-description:/ {sub(/^x-description:[[:space:]]*/, ""); sub(/\r$/, ""); print; exit}' "$HEADERS_FILE")"
  [ -n "$description_header" ] || { echo "ASSERTION_FAILED: expected non-empty x-description header for ${file_name}"; exit 1; }
  content_type_header="$(awk 'BEGIN{IGNORECASE=1} /^content-type:/ {sub(/^content-type:[[:space:]]*/, ""); sub(/\r$/, ""); print; exit}' "$HEADERS_FILE")"
  case "$content_type_header" in
    image/*) ;;
    *) echo "ASSERTION_FAILED: expected image/* content-type for ${file_name} got ${content_type_header}"; exit 1 ;;
  esac
  [ -s "$BODY_FILE" ] || { echo "ASSERTION_FAILED: expected non-empty generated image body for ${file_name}"; exit 1; }
}

# Given — bootstrap an authenticated session via /auth/anonymous
SHORT_DESC="authenticated user with multiple image formats"
echo "STEP: Given — ${SHORT_DESC}"
echo "PREREQ: bootstrapping anonymous session via /auth/anonymous"
AUTH_STATUS=$(curl -sS -L -D "$AUTH_HEADERS" -o "$AUTH_BODY" -w '%{http_code}' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  "$BASE_URL/auth/anonymous")
echo "RESPONSE_STATUS: $AUTH_STATUS"
[ -s "$COOKIE_JAR" ] || { echo "ASSERTION_FAILED: expected session cookie to be set after /auth/anonymous"; exit 1; }
[ -s "$PNG_FILE" ] || { echo "ASSERTION_FAILED: PNG test file missing"; exit 1; }
[ -s "$JPG_FILE" ] || { echo "ASSERTION_FAILED: JPG test file missing"; exit 1; }
[ -s "$JPEG_FILE" ] || { echo "ASSERTION_FAILED: JPEG test file missing"; exit 1; }

# When — perform the action under test
SHORT_DESC="POST /api/generate for png, jpg, and jpeg uploads"
echo "STEP: When — ${SHORT_DESC}"
run_case "$PNG_FILE" "image/png" "drawing.png"
run_case "$JPG_FILE" "image/jpeg" "sketch.jpg"
run_case "$JPEG_FILE" "image/jpeg" "artwork.jpeg"

# Then — HTTP/body assertions
SHORT_DESC="all formats were accepted and returned alt text plus image data"
echo "STEP: Then — ${SHORT_DESC}"
echo "ASSERTION_OK: PNG, JPG, and JPEG requests all returned HTTP 200 with x-description and image responses"

# Cleanup — undo Given side effects
SHORT_DESC="remove temporary files"
echo "STEP: Cleanup — ${SHORT_DESC}"
echo "CODEVALID_TEST_ASSERTION_OK:various_image_formats_supported"
