# wyyp — "I want to verify the cards"

> An AI agent QA skill: run `/wyyp` for 7-dimension quality verification, get **牌没有问题 ✓** ("all cards clean") when everything passes.

[中文](README.md) | English

## What it is

**wyyp** (我要验牌, "I want to verify the cards") is an AI agent skill that acts as your project's QA. After finishing development, type `/wyyp` in Claude Code — the agent runs **7 dimensions** of quality verification, aggregates results, and on green prints a reward line: **牌没有问题** ("the cards are fine").

Seven dimensions:

| Dimension | When to run |
|-----------|-------------|
| Unit tests | Every run |
| Integration tests | When external deps exist (DB / Redis / MQ / HTTP) |
| Regression tests | When `tests/regression/` or `@regression` markers exist |
| Benchmarks | When `Benchmark*` or similar exist |
| Compatibility | When multi-version / multi-platform matrix declared |
| Chaos | When explicitly requested or project has chaos config |
| Security | Every run |

**Language / framework agnostic.** Auto-detects Go / Node / TS / Python / Rust / Java / Kotlin / PHP projects. Prefers `Makefile` / `justfile` / `Taskfile.yml` wrappers if present.

## Why "verify the cards"

One `/wyyp` = flipping over each quality card across dimensions. All PASS → **牌没有问题**. Any card that's broken gets named out loud, no cover-ups.

## Install

### Via npx skills (recommended)

```bash
cd your-project
npx skills add singchia/wyyp
```

### One-liner (installs `/wyyp` command + AGENTS.md + Cursor rule + config template)

```bash
cd your-project
bash <(curl -sSL https://raw.githubusercontent.com/singchia/wyyp/main/scripts/install.sh)
```

Installs skill to `~/.claude/skills/wyyp/`, drops `AGENTS.md` and `.cursor/rules/wyyp.mdc`, installs `/wyyp` slash command to `~/.claude/commands/wyyp.md`, places `.wyyp.yml` template.

### Offline

```bash
curl -L -o wyyp.skill https://github.com/singchia/wyyp/releases/latest/download/wyyp.skill
unzip wyyp.skill -d ~/.claude/skills/
```

## Usage

In Claude Code:

```
/wyyp
```

Optionally restrict dimensions:

```
/wyyp unit,security
```

The agent auto-detects your stack, prefers Makefile targets, runs each dimension, aggregates, and prints a result table. On all-green it adds **`牌没有问题 ✓`** plus a next-step hint. On failure it lists specifics + remediation pointers and **does not auto-modify code**.

## Project config `.wyyp.yml`

Drop in project root to override defaults:

- Skip dimensions (with reason)
- Adjust coverage threshold (default 70%)
- Adjust benchmark regression threshold (default 10%)
- Declare critical regression allowlist
- Security CVE allowlist (with reason + expiry)
- Compatibility matrix
- Command overrides

Template at `docs/templates/wyyp-config-template.yml`.

## Design principles

- **Progressive disclosure** — load only the relevant dimension spec per run.
- **Wrapper-first** — if `Makefile` exists, use it, don't bypass.
- **No auto-fix** — only verify; code changes need explicit user instruction.
- **Safe by default** — chaos warns but doesn't block; never runs against prod.
- **No masking** — skipped / timed-out / flaky tests don't count as PASS.

## Related

- [gospec](https://github.com/singchia/gospec) — Go backend SDLC spec (same author)

## License

MIT © singchia
