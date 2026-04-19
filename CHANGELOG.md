# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - 2026-04-19

### Added

- **Trae / Trae-CN 支持**:`install.sh` 现在会检测 `~/.trae/` 和 `~/.trae-cn/`(字节跳动 Trae IDE,海外版 + 国内版),分别 symlink 到各自的 `skills/wyyp`。Trae 和 Codex / Claude Code 用同样的 skills.sh 协议。
- **peer agent 抽象**:Codex / Trae / Trae-CN 的 symlink 逻辑抽成通用循环,以后加新 agent 只要加一行 `"<Label>|<skills-root>"`。
- **统一环境变量**:
  - `NO_PEERS=1` 跳过所有 peer agent 安装
  - `NO_CODEX=1` / `NO_TRAE=1` / `NO_TRAE_CN=1` 单独跳过某个
  - `uninstall.sh` 对应清理所有 peer symlink

### Migration note

升级无感。已装 v0.5.0 的用户重跑 `install.sh` 会自动补上 Trae / Trae-CN 的 symlink。

## [0.5.0] - 2026-04-19

### Added

- **Codex 支持**:`install.sh` 现在会自动检测 `~/.codex/`,并在 `~/.codex/skills/wyyp` 建一个 symlink 指向 `~/.claude/skills/wyyp`。重启 Codex 后,wyyp 会出现在"个人"skill 列表里。
  - 一份源码、两处生效,update skill 不需要手工同步
  - 跳过:`NO_CODEX=1 bash install.sh`
  - 覆盖位置:`CODEX_SKILLS_DIR=/custom/path bash install.sh`
- **`uninstall.sh` 对应清理**:Step 5 检查并删除 Codex 的 symlink(只删 symlink,不会碰用户手动放进去的真实文件)。

### Notes

- 未来计划:自动检测更多 agent(Cline / Gemini CLI 等)的 skill 目录。目前先支持 Claude Code + Codex。

## [0.4.0] - 2026-04-19

### Changed (BREAKING — 安装产物简化)

- **去掉独立的 `/wyyp` 斜杠命令文件**,skill-only 触发。
  - 之前:`install.sh` 既装 skill(`~/.claude/skills/wyyp/`)又装 slash command(`~/.claude/commands/wyyp.md`),Claude Code 菜单里出现**两个** `/wyyp`,重复。
  - 现在:只装 skill。现代 Claude Code 通过 `/<skill-name>` 直接触发 skill,不需要独立 command 文件。
- **`install.sh` Step 5 自动清理 legacy**:从 < 0.4.0 升级上来的用户,`~/.claude/commands/wyyp.md` 会被自动删除,避免菜单重复。
- **`uninstall.sh` Step 4 语义调整**:仍会删 legacy `wyyp.md`(保持升级兼容),但 0.4.0 起新装本来就不会有这个文件。
- **`build-skill.sh` / `validate-skill.py` 去掉 `commands/` 相关**。仓库不再有 `commands/` 目录。

### Migration note

从 0.3.0 或更早升上来:直接重跑 `install.sh`,会自动清理 legacy 命令文件。不需要手工 `rm ~/.claude/commands/wyyp.md`。

也可以:
```bash
# 先卸载(可选)
bash <(curl -sSL https://raw.githubusercontent.com/singchia/wyyp/main/scripts/uninstall.sh)
# 重装 0.4.0
bash <(curl -sSL https://raw.githubusercontent.com/singchia/wyyp/main/scripts/install.sh)
```

升级后,`/` 菜单只会有一个 `/wyyp` 条目。

## [0.3.0] - 2026-04-19

### Changed

- **安全维度扣分按"适用工具集"细化**(`spec/07-security.md`)。解决 v0.2.0 下纯文档 / skill 项目因 `gitleaks` 未装就被判 F 的过严问题。
  - **每个仓库形态有自己的"适用工具集"**:
    - 纯文档 / skill / 纯配置 → `[gitleaks]`
    - Go → `[gitleaks, govulncheck, gosec]`
    - Node/TS → `[gitleaks, npm audit]`(semgrep 可选)
    - Python → `[gitleaks, pip-audit, bandit]`
    - Rust → `[gitleaks, cargo-audit]`
    - Java → `[gitleaks, dependency-check]`
    - +发镜像 → `+ trivy`
  - **不适用的工具不算"未装"**(docs 项目没 trivy 不扣分)
  - **合并扣分公式**:`penalty = weight × (k/N) × (0.2 if fallback_clean else 1.0)`,k = 未装工具数,N = 适用工具数
  - 手工 fallback 通过 → 扣 20%(而不是 50%)
  - 对 gospec 这类纯文档仓库的影响:从 **50/100 (F)** 升到 **80/100 (B)**
- **手工 fallback 扫描流程写进 spec**:密钥 pattern / `.gitignore` 检查 / git 历史快筛 / 依赖漏洞兜底。覆盖不到完整工具但挡住最常见问题。

### Added

- **`scripts/uninstall.sh`**:对称的卸载命令。默认删 `AGENTS.md` / `.cursor/rules/wyyp.mdc` / `~/.claude/commands/wyyp.md` / 未改过的 `.wyyp.yml` 模板;加 `KEEP_SKILL=0` 一并删 `~/.claude/skills/wyyp/`。
  - 远程:`bash <(curl -sSL https://raw.githubusercontent.com/singchia/wyyp/main/scripts/uninstall.sh)`
  - 本地:`~/.claude/skills/wyyp/scripts/uninstall.sh`

### Migration note

升级到 0.3.0 后,现有项目的打分可能变化——纯文档 / skill 项目会变宽松(从 F 可能升到 B),代码项目行为不变或更精准。如果你有 `.wyyp.yml`,不需要改。

## [0.2.0] - 2026-04-19

### Added

- **三态判定(applicable / MISSING / N/A)**:agent 探测阶段给每个维度打一个状态。
  - **applicable** — 应该有 + 探测到测试 → 跑
  - **MISSING** — 应该有 + 没有 → **扣满权重**(没测试不是 SKIP,是质量缺失)
  - **N/A** — 仓库性质不适用 → 不扣分,权重归一
- **加权百分制评分 + 等级**:按维度加权算总分,映射到 A+ / A / B / C / F。
  - 各维度权重:unit 20 / integration 15 / regression 20 / benchmark 10 / compatibility 10 / chaos 5 / security 20
  - 等级终局话术:A+ "牌没有问题 ✓" / A "基本没问题" / B "先修再发" / C "先别发" / F "禁止发版"
- **仓库形态识别**:纯文档 / 单文件 CLI / 脚手架 / 纯配置 / MVP / 成熟服务,决定哪些维度默认 N/A。形态在报告里显式写明。
- **每个 spec 子文件加"三态判定"段**:01-unit.md 到 07-security.md 都列出 applicable / MISSING / N/A 的探测信号和 MISSING 报告模板。
- **"应该有"的启发式**(spec/spec.md 汇总 + 各子文件细化):
  - 单元:有生产代码 → 应该有
  - 集成:代码里 import DB / Redis / MQ / HTTP client → 应该有
  - 回归:有 CHANGELOG 或已发过 tag → 应该有
  - 基准:有 HTTP handler / pipeline / 编解码热路径 → 应该有
  - 兼容:发版产物多平台 / 多架构 → 应该有
  - 混沌:多服务 + ≥3 个外部依赖 + 已进生产 → 应该有
  - 安全:始终 applicable,无 MISSING / N/A 豁免

### Changed

- **终局输出格式**:报告头加"仓库形态",表格加"得分/权重"列,底部加总分 + 等级 + 分级话术。样例见 `spec/spec.md#最终输出格式`。
- **SKILL.md / commands/wyyp.md 工作流**:Step 1 明确为"三态判定",Step 4 明确为"按公式加权计分",Step 5 按等级给话术。
- **`.wyyp.yml` 模板**:加 `weights:` / `grade:` 段,可覆盖默认权重和等级门槛。

### Migration note

从 0.1.0 升级:已有 `.wyyp.yml` 不需要改,没写 `weights` / `grade` 会自动用默认值。如果你之前靠 `skip:` 跳过某维度,0.2.0 下 skip 的维度权重会自动归一到其他维度,总分仍为 100——行为更符合直觉。

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
