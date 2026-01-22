# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Repository Overview

Adversarial Review is a multi-agent code review tool that uses Claude and GPT Codex in an adversarial debate loop. Two AI agents independently review code, critique each other's findings, and reach consensus through structured debate.

Based on patterns from [asimov-ralph](https://github.com/frankbria/ralph-claude-code).

## Architecture

### Main Script: `adversarial_review.sh`

The main entry point (~820 lines). Orchestrates the 4-phase review loop:

1. **Phase 1: Independent Reviews** - Claude and Codex review code in parallel
2. **Phase 2: Cross-Review** - Each reviews the other's findings
3. **Phase 3: Meta-Review** - Each responds to feedback on their review
4. **Phase 4: Synthesis** - Claude synthesizes findings and implements fixes

### Library Components (`lib/`)

- **circuit_breaker.sh** - Prevents runaway loops by detecting:
  - No progress after N iterations (default: 3)
  - Persistent disagreement (default: 5 iterations)
  - Same issues found repeatedly (default: 3 times)

- **response_analyzer.sh** - Parses agent outputs:
  - Detects NO_ISSUES responses
  - Extracts structured status blocks
  - Compares agent agreement levels

- **date_utils.sh** - Cross-platform date utilities:
  - ISO timestamp generation
  - Epoch time calculations

### Prompt Templates (`prompts/`)

Each phase has a dedicated prompt template:
- `initial_review.md` - Code review criteria and output format
- `cross_review.md` - How to analyze another agent's findings
- `meta_review.md` - How to respond to feedback
- `synthesis.md` - How to synthesize and implement fixes

All prompts include structured status blocks that get parsed:
```
---REVIEW_STATUS---
ISSUES_FOUND: 3
EXIT_SIGNAL: false
SUMMARY: Found critical issues
---END_REVIEW_STATUS---
```

## Key Commands

```bash
# Run review on a project
./adversarial_review.sh ../my-project

# With options
./adversarial_review.sh -m 5 -v -t 15 ../my-project  # 5 iters, verbose, 15m timeout

# Dry run (no API calls)
./adversarial_review.sh --dry-run ../my-project

# Status and management
./adversarial_review.sh --status
./adversarial_review.sh --reset
./adversarial_review.sh --circuit-status
./adversarial_review.sh --reset-circuit
```

## State Files

- `tracking.json` - Main state tracking (iteration, status, history)
- `.circuit_breaker.json` - Circuit breaker state
- `.circuit_breaker_history.json` - State transition history
- `artifacts/` - All agent outputs per iteration

## Artifacts Naming Convention

```
iter{N}_{phase}_{agent}_{type}.md

Examples:
- iter1_1_claude_review.md      # Phase 1, Claude's initial review
- iter1_1_codex_review.md       # Phase 1, Codex's initial review
- iter1_2_claude_on_codex.md    # Phase 2, Claude reviewing Codex
- iter1_2_codex_on_claude.md    # Phase 2, Codex reviewing Claude
- iter1_3_claude_meta.md        # Phase 3, Claude's meta-review
- iter1_3_codex_meta.md         # Phase 3, Codex's meta-review
- iter1_4_synthesis.md          # Phase 4, Claude's synthesis
```

## Dependencies

- **claude CLI**: `npm install -g @anthropic-ai/claude-code`
- **codex CLI**: `npm install -g @openai/codex`
- **jq**: JSON processing (`brew install jq`)
- **coreutils** (macOS): For timeout command (`brew install coreutils`)

## Known Issues / TODOs

1. **macOS compatibility**: Uses `gtimeout` from coreutils instead of `timeout`
2. **No tests yet**: Should add bats tests following ralph's pattern
3. **Codex CLI flags**: May need adjustment based on actual codex CLI behavior
4. **Cost tracking**: Not implemented - each iteration is ~6 API calls

## Development Notes

### Bash Gotchas Fixed

1. **Arithmetic increment with set -e**: `((iteration++))` returns 1 when incrementing from 0, which triggers `set -e`. Fixed with `((iteration++)) || true`.

2. **macOS head -z**: GNU `head -z` for null-delimited input doesn't exist on macOS. Replaced with line-based reading with counters.

3. **Background job stdin**: When running agents in parallel with `&`, ensure stdin handling doesn't block.

### Adding New Agents

To add a third agent (e.g., Gemini):
1. Add `run_gemini()` function following `run_claude()`/`run_codex()` pattern
2. Update phases to run third agent in parallel
3. Update cross-review to have 3-way comparisons
4. Update synthesis to consider all three perspectives

### Customizing Review Criteria

Edit `prompts/initial_review.md` to change what gets reviewed:
- Add domain-specific checks
- Adjust severity classifications
- Modify output format

## Related Projects

- [asimov-ralph](https://github.com/frankbria/ralph-claude-code) - The autonomous dev loop this is based on
- [D3 Framework](https://arxiv.org/abs/2410.04663) - Academic research on adversarial AI debate
- [ChatEval](https://github.com/thunlp/ChatEval) - Multi-agent debate for evaluation
