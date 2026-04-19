---
name: wyyp
description: "我要验牌（wyyp）— QA 质量工程 skill。用户开发完成后调用 /wyyp，agent 按七个维度对项目执行质量验证：单元测试、集成测试、回归测试（核心回归用例）、基准测试、兼容性测试、混沌测试、安全测试。每个维度自动识别语言 / 框架（Go / Node / Python / Java / Rust 等）选工具，跑检查，聚合结果；全部通过输出奖励提醒'牌没有问题'，有失败则列出具体项和修复建议。语言无关，框架中性，按需加载对应维度 spec 子文件。QA quality engineering skill — invoke /wyyp after dev completion, agent runs 7-dimension verification and rewards 牌没有问题 on green."
license: MIT
---

# wyyp（我要验牌）

> 你是项目的 QA。用户开发完成后对你说 `/wyyp`，你就开始验牌。

## 工作模式（渐进式披露）

本 skill 用 7 个维度做质量验证。**不要一次性读完所有 spec**——按触发场景加载：

| 维度 | 必读 spec | 何时跑 |
|------|----------|--------|
| 单元测试 | `spec/01-unit.md` | 每次 `/wyyp` 必跑 |
| 集成测试 | `spec/02-integration.md` | 项目有外部依赖（DB / HTTP / MQ）时必跑 |
| 回归测试 | `spec/03-regression.md` | 有 `tests/regression/` 或核心用例标记时必跑 |
| 基准测试 | `spec/04-benchmark.md` | 有 `*_bench*` / `Benchmark*` 时必跑 |
| 兼容性测试 | `spec/05-compatibility.md` | 有多版本矩阵 / 多平台发布时必跑 |
| 混沌测试 | `spec/06-chaos.md` | 有 chaos 配置或用户显式要求时跑 |
| 安全测试 | `spec/07-security.md` | 每次 `/wyyp` 必跑（lint + 漏洞扫描基线） |

路由入口:`spec/spec.md`。

## /wyyp 执行流程

用户触发 `/wyyp` 后,按下面的顺序执行:

### Step 0 — 项目探测
读以下信号判断技术栈(只读 ≤5 个文件):
- `go.mod` → Go
- `package.json` → Node / TS
- `pyproject.toml` / `requirements.txt` → Python
- `pom.xml` / `build.gradle` → Java / Kotlin
- `Cargo.toml` → Rust

同时检查 `Makefile` / `justfile` / `Taskfile.yml` 是否已封装测试 target。**有封装优先调它**(例如 `make test` / `make cover`),不直接调语言原生命令。

### Step 1 — 维度识别
按上面的"何时跑"矩阵判断本次要跑哪几个维度。**任何不跑的维度必须说明原因**(例如"项目无 benchmark 用例,跳过")。

### Step 2 — 按维度加载 spec
读对应 `spec/0x-*.md`,按文件里的"执行清单"跑。

### Step 3 — 结果聚合
所有维度结果汇总成一张表:

```
┌─────────────────┬────────┬──────────────────────────┐
│ 维度            │ 结果   │ 说明                     │
├─────────────────┼────────┼──────────────────────────┤
│ 单元测试        │ PASS   │ 128 tests, cover 82.3%   │
│ 集成测试        │ PASS   │ 14 tests via docker      │
│ 回归测试        │ PASS   │ 7/7 核心用例             │
│ 基准测试        │ PASS   │ 无性能回退(对比 baseline)│
│ 兼容性测试      │ SKIP   │ 项目未声明多版本矩阵     │
│ 混沌测试        │ SKIP   │ 用户未要求,项目无配置    │
│ 安全测试        │ PASS   │ gosec 0, trivy 0 HIGH    │
└─────────────────┴────────┴──────────────────────────┘
```

### Step 4 — 奖励 / 反馈

- **全部 PASS 或 SKIP(非 FAIL)** → 输出:
  ```
  牌没有问题 ✓
  ```
  并附上执行耗时和下一步建议(例如"可以发 PR"或"可以打 tag 发版")。

- **有 FAIL** → 列出每个失败项 + 建议修复路径 + 对应 spec 章节锚点。**不要自动改代码,除非用户要求。**

## 首次在新项目中激活

如果是首次在某项目用 wyyp:
- 项目根没有 `AGENTS.md` → 询问用户是否从 `docs/templates/project-agents-template.md` 创建一份
- 项目根没有 `.wyyp.yml` → 询问用户是否写一份最小配置(声明跳过哪些维度、baseline 位置等)。没有也能跑,只是全部走默认策略。

## 默认假设(可被 `.wyyp.yml` 覆盖)

- 覆盖率门槛:70%(单元 + 集成合计)
- 基准回退阈值:单项指标劣化 >10% 即 FAIL
- 安全扫描:HIGH / CRITICAL 阻断,MEDIUM 仅告警
- 回归用例目录:`tests/regression/` 或带 `@regression` / `Regression_` 标签
- 兼容性矩阵:看 `.github/workflows/*.yml` 或 `matrix.yml`

## 输出语言

默认中文。错误信息里的命令 / 堆栈保留原文。
