# Adversarial Review

Multi-agent code review with Claude and GPT Codex in an adversarial debate loop.

Based on patterns from [asimov-ralph](https://github.com/frankbria/ralph-claude-code) and research on [AI Debate](https://arxiv.org/abs/2410.04663).

## Concept

Two AI agents (Claude and GPT Codex) independently review code, then critique each other's findings through multiple rounds of debate. This adversarial process helps:

- **Find more issues**: Different models catch different problems
- **Eliminate false positives**: Cross-validation filters out incorrect findings
- **Build consensus**: Disagreements are resolved through structured debate
- **Improve confidence**: Issues both agents agree on are high-confidence fixes

## The 4-Phase Loop

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: Independent Reviews                               │
│    Claude reviews code → claude_review.md                   │
│    Codex reviews code  → codex_review.md                    │
│    (runs in parallel)                                       │
├─────────────────────────────────────────────────────────────┤
│  Phase 2: Cross-Review                                      │
│    Claude reviews Codex's findings → claude_on_codex.md     │
│    Codex reviews Claude's findings → codex_on_claude.md     │
│    (runs in parallel)                                       │
├─────────────────────────────────────────────────────────────┤
│  Phase 3: Meta-Review                                       │
│    Claude responds to Codex's critique → claude_meta.md     │
│    Codex responds to Claude's critique → codex_meta.md      │
│    (runs in parallel)                                       │
├─────────────────────────────────────────────────────────────┤
│  Phase 4: Synthesis                                         │
│    Claude reviews all debate artifacts                      │
│    Decides which issues are valid                           │
│    Implements fixes with high/medium confidence             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
              Loop back to Phase 1 to verify fixes
              until both agents report NO_ISSUES
```

## Quick Start

```bash
# Clone or copy to your workspace
cd adversarial-review

# Run on a target project
./adversarial_review.sh ../my-project

# With options
./adversarial_review.sh -m 5 -v ../my-project  # 5 iterations, verbose

# Dry run (see what would happen)
./adversarial_review.sh --dry-run ../my-project
```

## Requirements

- **claude CLI**: `npm install -g @anthropic-ai/claude-code`
- **codex CLI**: `npm install -g @openai/codex`
- **jq**: `brew install jq` (macOS) or `apt install jq` (Linux)
- **coreutils** (macOS only, for timeout): `brew install coreutils`

## Usage

```bash
./adversarial_review.sh [OPTIONS] <target_directory>

OPTIONS:
    -h, --help              Show help
    -m, --max-iters N       Max iterations (default: 3)
    -p, --prompt FILE       Custom initial review prompt
    -v, --verbose           Verbose output
    -t, --timeout MIN       Timeout per agent in minutes (default: 10)
    --status                Show current status
    --reset                 Reset all state
    --reset-circuit         Reset circuit breaker only
    --circuit-status        Show circuit breaker status
    --dry-run               Show what would happen without executing
```

## Project Structure

```
adversarial-review/
├── adversarial_review.sh    # Main script
├── lib/
│   ├── date_utils.sh        # Cross-platform date utilities
│   ├── circuit_breaker.sh   # Prevents runaway loops
│   └── response_analyzer.sh # Parses agent outputs
├── prompts/
│   ├── initial_review.md    # Phase 1: Independent review prompt
│   ├── cross_review.md      # Phase 2: Cross-review prompt
│   ├── meta_review.md       # Phase 3: Meta-review prompt
│   └── synthesis.md         # Phase 4: Synthesis prompt
├── artifacts/               # Agent outputs per iteration
├── logs/                    # Execution logs
└── tracking.json            # State tracking
```

## Circuit Breaker

Prevents runaway loops by detecting:

- **No progress**: 3 iterations with no fixes made
- **Persistent disagreement**: 5+ iterations where agents can't agree
- **Same issues**: 3+ iterations finding the same unfixable issues

```bash
# Check circuit breaker status
./adversarial_review.sh --circuit-status

# Reset if stuck
./adversarial_review.sh --reset-circuit
```

## Customization

### Custom Review Prompts

```bash
# Use your own review criteria
./adversarial_review.sh -p my_review_prompt.md ../project
```

### Environment Variables

```bash
MAX_ITERATIONS=5      # Override max iterations
TIMEOUT_MINUTES=15    # Timeout per agent call
VERBOSE=1             # Enable verbose output
DRY_RUN=1            # Show what would happen
```

## How It Works

### Agent Status Blocks

Each agent outputs a structured status block that gets parsed:

```
---REVIEW_STATUS---
ISSUES_FOUND: 3
CRITICAL_COUNT: 1
HIGH_COUNT: 1
MEDIUM_COUNT: 1
LOW_COUNT: 0
CONFIDENCE: HIGH
EXIT_SIGNAL: false
SUMMARY: Found critical type mixing bug
---END_REVIEW_STATUS---
```

### Exit Conditions

The loop exits when:
1. **Both agents report NO_ISSUES** in Phase 1
2. **Synthesis completes** with EXIT_SIGNAL: true
3. **Max iterations reached**
4. **Circuit breaker opens** (stagnation detected)

### Artifacts

Each iteration produces:
- `iter{N}_1_claude_review.md` - Claude's initial review
- `iter{N}_1_codex_review.md` - Codex's initial review
- `iter{N}_2_claude_on_codex.md` - Claude's cross-review
- `iter{N}_2_codex_on_claude.md` - Codex's cross-review
- `iter{N}_3_claude_meta.md` - Claude's meta-review
- `iter{N}_3_codex_meta.md` - Codex's meta-review
- `iter{N}_4_synthesis.md` - Final synthesis and fixes

## Research Background

This approach is based on:

- [D3: Debate, Deliberate, Decide](https://arxiv.org/abs/2410.04663) - Adversarial multi-agent evaluation framework
- [ChatEval](https://github.com/thunlp/ChatEval) - Multi-agent debate for LLM evaluation
- [AI Debate Research](https://arxiv.org/html/2410.04663v1) - Shows debating LLMs produce more accurate results

Key findings from research:
- Multi-agent debate reduces hallucinations and false positives
- 3-7 agents offer the best accuracy-to-cost ratio
- Adversarial validation improves consensus quality

## Cost Considerations

Each iteration makes 6 API calls (3 parallel pairs):
- Phase 1: 2 calls (Claude + Codex)
- Phase 2: 2 calls (Claude + Codex)
- Phase 3: 2 calls (Claude + Codex)
- Phase 4: 1 call (Claude only)

With 3 iterations max, worst case is ~21 API calls per review.

## Contributing

This is an experimental prototype. Ideas for improvement:
- Add support for other models (Gemini, local LLMs)
- Implement weighted voting based on historical accuracy
- Add cost tracking and budgets
- Build a web UI for reviewing artifacts

## License

MIT
