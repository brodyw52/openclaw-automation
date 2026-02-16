---
name: signal-scanner
description: Scan A-tier leads for buying signals using Perplexity deep research. Checks for funding, hiring, press, and growth indicators to prioritize the hottest prospects.
---

# Signal Scanner

Deep research on A-tier leads to find buying signals before outreach.

## What It Does

For each A-tier lead, queries Perplexity to check:
1. **Funding** — Recent raises, investor announcements
2. **Hiring** — Job postings for marketing/growth/sales roles
3. **Press** — Product launches, partnerships, news mentions
4. **Growth** — Revenue milestones, expansion, new markets

Leads with signals get flagged as "Priority 1" — reach out first.

## Why This Matters

An A-tier lead with recent funding is 10x more likely to buy than one without. They have budget, they're growing, and they're actively investing.

This step separates "good fit" from "good fit with money."

## Invocation

```bash
# Scan A-tier leads from scored output
./scripts/scan.sh scored.json > signaled.json

# Scan specific leads
echo '{"leads": [...]}' | ./scripts/scan.sh > signaled.json
```

## Setup

### Environment Variables
```bash
export PERPLEXITY_API_KEY="pplx-..."
```

Get your key at: https://perplexity.ai → Settings → API

## Signal Scoring

| Signals Found | Priority | Action |
|---------------|----------|--------|
| 3-4 signals | **Priority 1** | Reach out immediately, heavy personalization |
| 2 signals | **Priority 2** | High priority sequence |
| 1 signal | **Priority 3** | Standard A-tier sequence |
| 0 signals | A-tier | Still good, no urgency boost |

## Cost

- ~$0.05-0.10 per lead (Perplexity API)
- Only runs on A-tier leads (typically 10-15% of pipeline)
- 50 leads mined → ~5-8 A-tier → ~$0.50 total

## Usage in Pipeline

```bash
# Full pipeline with signal scanning
./linkedin-miner/scripts/mine.sh "DTC ad costs" 20 > raw.json
./lead-enricher/scripts/enrich.sh raw.json > enriched.json
./icp-scorer/scripts/score.sh enriched.json > scored.json

# Extract A-tier and scan for signals
cat scored.json | jq '{leads: [.leads[] | select(.tier == "A")]}' | \
  ./signal-scanner/scripts/scan.sh > priority.json

# Priority 1 leads get immediate outreach
cat priority.json | jq '.leads | map(select(.priority == 1))'
```
