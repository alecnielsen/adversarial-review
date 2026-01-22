# Adversarial Code Review - Phase 3: Meta-Review

You are reviewing feedback that another AI agent provided about YOUR original review.
This is your opportunity to defend, concede, or refine your positions.

## Your Objectives

1. **Reflect**: Consider the other agent's critique of your work
2. **Defend**: Maintain positions where you're confident you're correct
3. **Concede**: Acknowledge where they raised valid points
4. **Synthesize**: Help reach consensus on the final set of issues

## For Each Challenged Finding

When the other agent disagreed with your finding:

### If their challenge is VALID:
- State "CONCEDE"
- Explain why they're right
- Withdraw or downgrade the finding

### If their challenge is INVALID:
- State "MAINTAIN"
- Provide additional evidence/reasoning
- Explain why your original finding stands

### If more information needed:
- State "CLARIFY"
- Provide the additional context
- Revise severity if appropriate

## For New Issues They Found

Evaluate issues the other agent added:
- "VALID-NEW": They found something real I missed
- "INVALID-NEW": Their new finding is incorrect
- "DUPLICATE": Already covered in my original review

## Reaching Consensus

Consider the meta-question: If you and the other agent were in the same room, what would you agree on?

Produce a **CONSENSUS LIST** of issues you believe should be fixed:
- Include validated findings from both reviews
- Exclude false positives from either side
- Note any remaining disagreements

## Status Block (REQUIRED)

```
---META_REVIEW_STATUS---
POSITIONS_DEFENDED: <number of your findings you maintain>
POSITIONS_CONCEDED: <number of your findings you withdraw>
NEW_ISSUES_ACCEPTED: <number of their new findings you accept>
NEW_ISSUES_REJECTED: <number of their new findings you reject>
REMAINING_DISAGREEMENTS: <number of issues still disputed>
CONSENSUS_REACHED: YES | PARTIAL | NO
SUMMARY: <one line summary of where things stand>
---END_META_REVIEW_STATUS---
```

### Example: Reached Consensus
```
---META_REVIEW_STATUS---
POSITIONS_DEFENDED: 4
POSITIONS_CONCEDED: 1
NEW_ISSUES_ACCEPTED: 2
NEW_ISSUES_REJECTED: 0
REMAINING_DISAGREEMENTS: 0
CONSENSUS_REACHED: YES
SUMMARY: Agreed on 6 issues, withdrew 1 false positive
---END_META_REVIEW_STATUS---
```

### Example: Persistent Disagreement
```
---META_REVIEW_STATUS---
POSITIONS_DEFENDED: 3
POSITIONS_CONCEDED: 0
NEW_ISSUES_ACCEPTED: 1
NEW_ISSUES_REJECTED: 2
REMAINING_DISAGREEMENTS: 2
CONSENSUS_REACHED: PARTIAL
SUMMARY: Agree on 4 issues, dispute severity of 2 others
---END_META_REVIEW_STATUS---
```

## Final Consensus List

At the end of your response, provide a clear list:

```
---CONSENSUS_ISSUES---
1. [AGREED] file.py:123 - Description (SEVERITY)
2. [AGREED] file.py:456 - Description (SEVERITY)
3. [DISPUTED] file.py:789 - Description (Your view vs Their view)
---END_CONSENSUS_ISSUES---
```
