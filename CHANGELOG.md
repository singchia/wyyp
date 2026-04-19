# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-19

### Added

- **首次发布**:我要验牌(wyyp)QA 质量工程 skill,符合 [skills.sh](https://skills.sh) Open Agent Skills 协议。
- **`/wyyp` 斜杠命令**:Claude Code 下直接输入 `/wyyp` 触发 7 维度验牌。命令文件 `commands/wyyp.md`,由 `install.sh` 落到 `~/.claude/commands/wyyp.md`。
- **7 个测试维度 spec**:
  - `spec/01-unit.md` — 单元测试(表格驱动、mock、race、覆盖率)
  - `spec/02-integration.md` — 集成测试(testcontainers、数据隔离、健康检查)
  - `spec/03-regression.md` — 回归测试(核心白名单、事故 ID 追溯)
  - `spec/04-benchmark.md` — 基准测试(baseline 对比、噪音控制、benchstat)
  - `spec/05-compatibility.md` — 兼容性测试(多版本 / 多平台矩阵)
  - `spec/06-chaos.md` — 混沌测试(toxiproxy / chaos-mesh,默认告警不阻塞)
  - `spec/07-security.md` — 安全测试(SAST / 依赖漏洞 / 秘密 / 容器四基线)
- **路由入口** `spec/spec.md`:维度矩阵、执行顺序、`.wyyp.yml` 配置样例、聚合报告格式、核心约束。
- **语言 / 框架中性**:自动探测 Go / Node / TS / Python / Rust / Java / Kotlin / PHP 项目,优先走 `Makefile` / `justfile` / `Taskfile.yml` 封装。
- **奖励机制**:全部维度 PASS/SKIP 时输出"牌没有问题 ✓",有 FAIL 时列具体项 + 修复建议,**不自动改代码**。
- **安装机制**:
  - `SKILL.md` 含 frontmatter `name` + `description` + `license`,符合 skills.sh 协议
  - 支持 `npx skills add singchia/wyyp`
  - `scripts/install.sh` 一行命令安装 + 落 `AGENTS.md` + `.cursor/rules/wyyp.mdc` + `~/.claude/commands/wyyp.md` + `.wyyp.yml` 模板
  - `scripts/build-skill.sh` 自包含构建脚本,产出 `dist/wyyp.skill`
  - `scripts/validate-skill.py` 自包含校验器
- **文档模板**:
  - `docs/templates/project-agents-template.md` — 项目根 AGENTS.md 模板
  - `docs/templates/cursor-rule-template.mdc` — Cursor 单文件规则模板(带 globs 自动附加)
  - `docs/templates/wyyp-config-template.yml` — `.wyyp.yml` 最小配置样例
- **CI/CD**:
  - `.github/workflows/validate.yml` 每次 push/PR 校验 frontmatter + 路由表完整性 + 自查清单 + smoke test
  - `.github/workflows/release.yml` tag push 自动构建 `wyyp.skill` 并发 GitHub Release
