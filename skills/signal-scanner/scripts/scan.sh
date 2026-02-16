#!/bin/bash
# signal-scanner/scripts/scan.sh
# Scan A-tier leads for buying signals using Perplexity

set -e

PERPLEXITY_API_KEY="${PERPLEXITY_API_KEY:-}"

if [[ -z "$PERPLEXITY_API_KEY" ]]; then
  echo "Error: PERPLEXITY_API_KEY not set" >&2
  exit 1
fi

INPUT="${1:-/dev/stdin}"
LEADS=$(cat "$INPUT")

log() { echo "[$(date '+%H:%M:%S')] $1" >&2; }

A_TIER=$(echo "$LEADS" | jq '[.leads[] | select(.tier == "A")]')
TOTAL=$(echo "$A_TIER" | jq 'length')

log "Scanning $TOTAL A-tier leads for signals..."

RESULTS="[]"
WITH_SIGNALS=0
PRIORITY_1=0

for i in $(seq 0 $((TOTAL - 1))); do
  LEAD=$(echo "$A_TIER" | jq ".[$i]")
  NAME=$(echo "$LEAD" | jq -r '.name')
  COMPANY=$(echo "$LEAD" | jq -r '.company // "Unknown"')
  
  log "Scanning: $NAME @ $COMPANY"
  
  QUERY="Research $COMPANY: 1) Any funding in last 12 months? 2) Hiring marketing/growth roles? 3) Recent press or launches? 4) Growth indicators? Be specific with dates."

  RESPONSE=$(curl -s "https://api.perplexity.ai/chat/completions" \
    -H "Authorization: Bearer $PERPLEXITY_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"llama-3.1-sonar-small-128k-online\", \"messages\": [{\"role\": \"user\", \"content\": $(echo "$QUERY" | jq -Rs .)}]}" 2>/dev/null || echo '{}')
  
  CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // "No response"')
  
  # Detect signals
  SIGNAL_COUNT=0
  echo "$CONTENT" | grep -qi "series\|raised\|funding\|million" && SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
  echo "$CONTENT" | grep -qi "hiring\|job.*open\|recruiting" && SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
  echo "$CONTENT" | grep -qi "announced\|launch\|partnership" && SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
  echo "$CONTENT" | grep -qi "growth\|expand\|revenue\|doubled" && SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
  
  [[ $SIGNAL_COUNT -ge 3 ]] && PRIORITY=1 && PRIORITY_1=$((PRIORITY_1 + 1))
  [[ $SIGNAL_COUNT -eq 2 ]] && PRIORITY=2
  [[ $SIGNAL_COUNT -eq 1 ]] && PRIORITY=3
  [[ $SIGNAL_COUNT -eq 0 ]] && PRIORITY=0
  [[ $SIGNAL_COUNT -gt 0 ]] && WITH_SIGNALS=$((WITH_SIGNALS + 1))
  
  RESULT=$(echo "$LEAD" | jq --argjson sc "$SIGNAL_COUNT" --argjson p "$PRIORITY" '. + {signal_score: $sc, priority: $p}')
  RESULTS=$(echo "$RESULTS" | jq --argjson lead "$RESULT" '. + [$lead]')
  
  sleep 1
done

jq -n --argjson total "$TOTAL" --argjson ws "$WITH_SIGNALS" --argjson p1 "$PRIORITY_1" --argjson leads "$RESULTS" \
  '{meta: {total_scanned: $total, with_signals: $ws, priority_1: $p1}, leads: $leads}'

log "Done. $WITH_SIGNALS leads with signals, $PRIORITY_1 Priority 1."
