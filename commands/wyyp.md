---
description: 按 7 个维度对当前项目做完整 QA 验牌,全部通过时输出"牌没有问题"
argument-hint: "[dimensions] 可选,逗号分隔,默认 all(如: unit,security)"
---

# /wyyp — 我要验牌

你现在是项目的 QA。严格按照 **wyyp** skill(`~/.claude/skills/wyyp/SKILL.md`)的工作流执行质量验证。

## 参数

- `$ARGUMENTS` — 如果非空,只跑指定维度(例如 `unit,security` 只跑单元测试和安全测试);为空则走"何时跑"矩阵自动判断。

## 你要做的事

1. **读 skill 入口**:先读 `~/.claude/skills/wyyp/SKILL.md` 和 `~/.claude/skills/wyyp/spec/spec.md`,理解 7 个维度的路由和工作流。如果项目根有 `.wyyp.yml`,也读一下(会覆盖默认策略)。

2. **探测项目技术栈**:读 `go.mod` / `package.json` / `pyproject.toml` / `Cargo.toml` / `pom.xml` 其中存在的;读根 `Makefile` / `justfile` / `Taskfile.yml`(如果有)——**有就优先调封装好的 target**,别绕过去直接调语言原生命令。

3. **按维度执行**:对每个要跑的维度,读对应 `spec/0x-*.md`,按文件里的"执行清单"跑。中途有失败不要立刻停,跑完所有维度再汇总。

4. **聚合结果**:输出一张表,列每个维度的 PASS/FAIL/SKIP 和一行说明。

5. **终局**:
   - 全部 PASS 或 SKIP(无 FAIL) → 输出奖励:
     ```
     牌没有问题 ✓
     ```
     并提示下一步(发 PR / 打 tag / 合并)。
   - 有 FAIL → 每项列出:失败位置、原因、修复建议、对应 spec 锚点。**不要擅自改代码**——除非用户下一句让你改。

## 约束

- 不主动 commit、push、打 tag。
- 不自动删生成物(coverage report / 临时文件可以留着,由用户清)。
- 遇到破坏性操作(migrate / chaos inject 真实破坏)必须先询问。
- 维度之间独立执行,不因前置失败就跳后面。
