# AGENTS.md — 本项目使用 wyyp 做 QA 验牌

> 本文件是给 AI agent(Claude Code / Cursor / Cline / Codex / Gemini CLI / Copilot)看的入口。Agent 打开本项目时应读到这里并了解项目的质量验证约定。

## wyyp 已启用

本项目使用 **wyyp**(我要验牌)skill 做质量验证。用户开发完成后会调用 `/wyyp` 触发 7 个维度的验证:

| 维度 | 何时跑 |
|------|--------|
| 单元测试 | 每次必跑 |
| 集成测试 | 有外部依赖必跑 |
| 回归测试 | 有 `tests/regression/` 或 `@regression` 标记必跑 |
| 基准测试 | 有 `Benchmark*` 必跑 |
| 兼容性测试 | 有多版本 / 多平台矩阵必跑 |
| 混沌测试 | 用户显式要求或有 chaos 配置 |
| 安全测试 | 每次必跑 |

详见 `~/.claude/skills/wyyp/SKILL.md`。

## 当 agent 接到 /wyyp

- 严格按 `~/.claude/skills/wyyp/spec/spec.md` 的执行流程跑
- 不自动改代码、不 commit、不 push
- 前 4 维度(安全 / 单元 / 集成 / 回归)属于"快速失败"组
- 全部 PASS → 输出"牌没有问题"
- 有 FAIL → 列具体项 + 建议,等用户指示再改

## `.wyyp.yml`(项目配置)

如果项目根有 `.wyyp.yml`,按它覆盖默认策略(跳过维度、覆盖率门槛、baseline 路径等)。没有就全部走默认。

## 写新测试时的约定(本项目特化)

<!-- 项目自己填,以下是通用提示 -->

- 新功能必须有单元测试
- 修 bug 必须有回归测试(注释写事故 ID)
- 涉及外部依赖的功能必须有集成测试(用 testcontainers,不连生产)
- 有性能要求的路径补 benchmark,发版前更新 baseline
- 任何涉及密钥 / 用户输入的代码都要过 SAST 和秘密扫描
