---
name: karpathy-guidelines
description: Behavioral guidelines to reduce common LLM coding mistakes. Use when writing, reviewing, or refactoring code to avoid overcomplication, make surgical changes, surface assumptions, and define verifiable success criteria.
license: MIT
---

# Karpathy Guidelines

Reduce common LLM coding mistakes. From [Karpathy's observations](https://x.com/karpathy/status/2015883857489522876).

**Tradeoff:** Biases toward caution over speed. Use judgment on trivial tasks.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

- State assumptions explicitly. Uncertain → ask.
- Multiple interpretations → present them, don't pick silently.
- Simpler approach exists → say so. Push back when warranted.
- Something unclear → stop, name what's confusing, ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" not requested.
- No error handling for impossible scenarios.
- 200 lines that could be 50 → rewrite.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

- Don't "improve" adjacent code, comments, formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd differ.
- Unrelated dead code → mention, don't delete.
- YOUR changes made something unused → remove it.
- Every changed line should trace to user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, make them pass"
- "Fix the bug" → "Write reproducing test, make it pass"
- "Refactor X" → "Ensure tests pass before and after"

Multi-step tasks — state plan with checks:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria → loop independently. Weak criteria ("make it work") → constant clarification.
