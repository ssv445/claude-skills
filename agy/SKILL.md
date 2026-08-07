---
name: agy
description: Use when invoking the agy CLI (Antigravity 2.0), needing Google Gemini / Claude / GPT-OSS via local CLI, or migrating from the deprecated `gemini` CLI. Also use when prompts mention agy, Antigravity, "gemini -p", or another panel/verifier slot that used to call `gemini`.
---

# agy — Antigravity 2.0 CLI

Local multi-provider CLI. Replaces the deprecated `gemini` CLI. Single binary `agy` exposes Gemini, Claude, and GPT-OSS models. Same `-p` print-mode UX as `claude -p` / `codex exec`.

## Binary

`/Users/shyam/.superconductor/bin/agy` (already on PATH)

`gemini` binary still resolves on the box but is **deprecated** — do not invoke for new work. Reroute every `gemini ...` call to `agy ...`.

## Quick reference

| Need | Command |
|---|---|
| One-shot prompt | `agy -p "what is 2+2"` |
| Pin to Gemini Pro | `agy --model "Gemini 3.1 Pro (High)" -p "..."` |
| Pin to Claude | `agy --model "Claude Sonnet 4.6 (Thinking)" -p "..."` |
| Interactive with seed | `agy -i "review this plan"` |
| Continue last session | `agy -c` |
| Auto-approve all tools | `agy --dangerously-skip-permissions -p "..."` |
| Sandboxed terminal | `agy --sandbox -p "..."` |
| Add workspace dir | `agy --add-dir /path/to/repo -p "..."` |
| List models | `agy models` |
| Update CLI | `agy update` |

`agy help` prints full flag list. `agy plugin help` for plugin subcommands.

## Arg-order trap — `-p` takes the prompt as its VALUE

`-p` / `--print` / `--prompt` is a **string** flag, not a boolean. Whatever follows `-p` becomes the prompt. Put `-p "<prompt>"` **last**, after every other flag.

```bash
# ✅ prompt is the value of -p, flags come first
agy --model "Gemini 3.1 Pro (High)" --sandbox -p "what is 2+2"

# ❌ prompt becomes the literal string "--sandbox"; the real question is dropped
agy -p --sandbox "what is 2+2"
```

Failure is **silent** — you get a confident, well-formed answer about the flag name. Verified 2026-08-07: `agy -p --json-schema s.json "What is 2+2?"` returned an essay about JSON Schema and never saw the question.

## Structured output

`--json-schema` only takes effect with `--output-format json`. The validated object lands in `.structured_output`:

```bash
agy --output-format json --json-schema schema.json -p "..." | jq .structured_output
```

Without `--output-format json` the schema is ignored and you get prose.

## Headless permissions

In print mode agy cannot prompt, so any tool needing the `command` permission is **auto-denied** and the run produces no output (stderr: `no output produced — a tool required the "command" permission`). Exit code is still 0.

Pair `--sandbox` with `--dangerously-skip-permissions` — auto-approve tools, terminal still restricted:

```bash
agy --sandbox --dangerously-skip-permissions -p "..."
```

## Available models

Run `agy models` for the live list. Current snapshot:

- Gemini 3.5 Flash (Low / Medium / High) — fast, cheap
- Gemini 3.1 Pro (Low / High) — Google's reasoning tier; default for "Google-model verifier" roles
- Claude Sonnet 4.6 (Thinking)
- Claude Opus 4.6 (Thinking)
- GPT-OSS 120B (Medium)

Model name strings are **literal** — pass them verbatim including spaces and parentheses, quoted:

```
agy --model "Gemini 3.1 Pro (High)" -p "..."
```

Unquoted parentheses → shell error.

## Migrating from `gemini`

| Old `gemini` flag | New `agy` flag |
|---|---|
| `gemini -p "..."` | `agy -p "..."` (default model) — or pin with `--model "Gemini 3.1 Pro (High)"` to preserve "Google-model verifier" intent |
| `gemini --skip-trust -p "..."` | `agy --dangerously-skip-permissions -p "..."` |
| `gemini -m "model-id"` | `agy --model "Display Name"` (display names, not IDs — see `agy models`) |
| `gemini` (interactive) | `agy` (interactive) |

**Rule of thumb:** if the old call needed Gemini specifically (independent Google-model perspective, panel diversity), keep that by pinning `--model "Gemini 3.1 Pro (High)"`. If it was just "any second-opinion model", let `agy` use its default.

## Common invocations

### Independent Google-model verifier (replaces `gemini -p`)

```bash
agy --model "Gemini 3.1 Pro (High)" --dangerously-skip-permissions -p "<prompt>"
```

Use in: panel reviewers (theteam), AI-detection scoring (write-blog), second-opinion verifiers.

### Cheap/fast bulk scoring

```bash
agy --model "Gemini 3.5 Flash (High)" -p "<prompt>"
```

Use when running many calls (per-link grading, per-paragraph linting). Flash is dramatically cheaper than Pro.

### Headless with timeout

```bash
timeout 30 agy --model "Gemini 3.1 Pro (High)" -p "<prompt>" 2>/dev/null
```

Default print timeout is 5m (`--print-timeout 5m0s`). Wrap with `timeout` for tighter caps in pipelines.

## Plugins

agy imports Claude Code and Gemini CLI plugins:

```bash
agy plugin import gemini    # one-time: pulls config from deprecated gemini CLI
agy plugin import claude    # mirrors claude plugin config
agy plugin list
```

Plugins/MCP servers configured this way appear automatically in agy sessions.

## Gotchas

- **Display names, not model IDs.** `agy --model "gemini-3.1-pro"` will fail. Use `"Gemini 3.1 Pro (High)"` exactly as shown by `agy models`.
- **Parentheses must be quoted.** `--model Gemini 3.1 Pro (High)` → shell error. Always wrap in `"..."`.
- **Default model is configurable.** Don't assume `agy -p` calls Gemini — pin `--model` when the call's semantics depend on which family answers.
- **`--dangerously-skip-permissions` is the only auto-approve flag.** No `--yes` / `--skip-trust` shortcut.
- **Browser Gemini ≠ agy.** Tasks that need image generation or chat at `gemini.google.com` still go through the browser, not agy.

## Do NOT use for

- Image generation → use Gemini browser (`gemini.google.com/app`) or a dedicated image API
- Interactive multi-turn chat within a script → use `--prompt-interactive` only when the user expects to stay in the session; otherwise pipe single prompts
- Authentication setup → run `agy install` once, then forget about it

## Related

- `theteam` skill — uses agy as one of the panel providers
- `write-blog` skill — uses agy for AI-detection scoring and link grading
- Deprecated: `gemini` CLI wrapper at `/Users/shyam/.superconductor/bin/gemini` — kept on PATH for backward compat, don't add new callers
