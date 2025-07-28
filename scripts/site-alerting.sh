#!/bin/bash

# Check arguments
if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <BOT_TOKEN> <CHAT_ID> <YAML_FILE>"
  exit 1
fi

BOT_TOKEN="$1"
CHAT_ID="$2"
YAML_FILE="$3"
INTERVAL=5 # Check interval in seconds

# Check for yq (YAML utility)
if ! command -v yq &> /dev/null; then
  echo "Error: 'yq' utility is not installed. Install it: https://github.com/mikefarah/yq/"
  exit 1
fi

# Get list of sites from YAML file
# Use cat and yq to read the file, then readarray to populate the array
if ! SITES_YAML_CONTENT=$(yq '.sites[]' "$YAML_FILE" 2>&1); then
  echo "Error reading YAML file or invalid format: $YAML_FILE"
  echo "yq message: $SITES_YAML_CONTENT"
  exit 1
fi
readarray -t SITES <<< "$SITES_YAML_CONTENT"

declare -A SITE_STATUS # Associative array to store site status (OK/FAIL)
declare -A FAIL_COUNT  # Associative array to count consecutive failures

echo "Starting website monitoring. Press Ctrl+C to stop."
echo "Monitoring the following sites:"
for SITE in "${SITES[@]}"; do
  echo "- $SITE"
done
echo "-----------------------------"

while true; do
  echo "==== $(date '+%Y-%m-%d %H:%M:%S') ===="

  for SITE in "${SITES[@]}"; do
    # Use curl to check site availability
    # -s: Silent mode
    # -L: Follow redirects
    # --connect-timeout 5: Connection timeout
    # --max-time 15: Total operation timeout
    # -w "%{http_code} %{errormsg}": Output HTTP code and error message
    # -o /dev/null: Discard response body output
    RESPONSE=$(curl -s -L --connect-timeout 5 --max-time 15 -w "%{http_code} %{errormsg}" -o /dev/null "$SITE")
    HTTP_CODE=$(echo "$RESPONSE" | cut -d' ' -f1)
    ERROR_MSG=$(echo "$RESPONSE" | cut -d' ' -f2-)

    # Determine status based on HTTP code and error messages
    # -z "$HTTP_CODE": If HTTP_CODE is empty (connection error before getting a code)
    # "$HTTP_CODE" == "000": Curl returns 000 for some errors
    # "$HTTP_CODE" -ge 400: Client or server error codes (4xx, 5xx)
    if [[ -z "$HTTP_CODE" || "$HTTP_CODE" == "000" || "$HTTP_CODE" -ge 400 ]]; then
      STATUS="FAIL"
    else
      STATUS="OK"
    fi

    PREV_STATUS=${SITE_STATUS["$SITE"]} # Get previous site status

    if [[ "$STATUS" == "FAIL" ]]; then
      ((FAIL_COUNT["$SITE"]++)) # Increment failure counter

      # If the site has been down 2 or more times in a row and the previous status was not "FAIL"
      # (i.e., this is a new downtime or it's continuing), send a notification.
      # The condition ${FAIL_COUNT["$SITE"]} -ge 2 prevents spamming on the first failure,
      # which might be temporary.
      if [[ ${FAIL_COUNT["$SITE"]} -ge 2 && "$PREV_STATUS" != "FAIL" ]]; then
        SITE_STATUS["$SITE"]="FAIL" # Set site status to "FAIL"
        MSG="❌ $SITE unavailable (HTTP ${HTTP_CODE:-000}) ${ERROR_MSG}"
        echo "$MSG"
        # Send notification to Telegram
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
          -d chat_id="$CHAT_ID" \
          -d text="$MSG" \
          -d disable_web_page_preview=true
      elif [[ ${FAIL_COUNT["$SITE"]} -eq 1 ]]; then
        # First detected failure, don't send notification, just log.
        echo "$SITE: 1st error (possibly temporary), HTTP $HTTP_CODE ${ERROR_MSG}"
      else
        # Subsequent failures after the first notification, don't resend, just log.
        echo "$SITE: Continuing failure (HTTP $HTTP_CODE ${ERROR_MSG})"
      fi
    else # Site is available (STATUS == "OK")
      if [[ "$PREV_STATUS" == "FAIL" ]]; then
        SITE_STATUS["$SITE"]="OK" # Set site status to "OK"
        FAIL_COUNT["$SITE"]=0      # Reset failure counter
        MSG="✅ $SITE restored (HTTP $HTTP_CODE)"
        echo "$MSG"
        # Send restoration notification to Telegram
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
          -d chat_id="$CHAT_ID" \
          -d text="$MSG" \
          -d disable_web_page_preview=true
      else
        echo "$SITE: OK (HTTP $HTTP_CODE)"
        FAIL_COUNT["$SITE"]=0 # Reset failure counter if it was non-zero
      fi
    fi
  done

  echo ""
  sleep "$INTERVAL" # Wait before next check
done
