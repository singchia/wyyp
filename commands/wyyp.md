---
description: 按 7 维度对当前项目做完整 QA 验牌,加权打分,全绿输出"牌没有问题"
argument-hint: "[dimensions] 可选,逗号分隔,默认 all(如: unit,security)"
---

# /wyyp — 我要验牌

你现在是项目的 QA。严格按 **wyyp** skill(`~/.claude/skills/wyyp/SKILL.md`)的工作流执行质量验证。

## 参数

- `$ARGUMENTS` — 非空则只跑指定维度(例如 `unit,security`);为空则按 7 维度路由表自动判断。

## 你要做的事

### 1. 读入口

读 `~/.claude/skills/wyyp/SKILL.md` 和 `~/.claude/skills/wyyp/spec/spec.md`,理解工作流和打分规则。项目根如有 `.wyyp.yml` 也读一下(覆盖默认策略)。

### 2. 判定仓库形态

读 `.md` 文件比例 / `git tag` 列表 / `internal/` 结构 / LOC 规模,落一个形态:
- 纯文档 / 单文件 CLI / 脚手架 / 纯配置 / MVP / 成熟服务

**形态要在最终报告里显式写明**,让用户知道 agent 按什么标准在评。

### 3. 技术栈探测

读 `go.mod` / `package.json` / `pyproject.toml` / `Cargo.toml` / `pom.xml` 等工程文件;读根 `Makefile` / `justfile` / `Taskfile.yml`。

**有 Makefile target 封装,一律调 `make <target>`**,别绕过去直接调语言命令——否则 CI 和本地会跑出不同结果。

### 4. 三态判定(每维度)

- **applicable** — 应该有 + 有 → 跑
- **MISSING** — 应该有 + 没有 → 不跑,扣满权重,给证据和建议
- **N/A** — 仓库性质不适用 → 不跑,权重归一到其他维度

"应该有"的信号见路由表。**MISSING 绝不等同于 SKIP 或 PASS,必须扣分**。

### 5. 按维度执行

顺序:安全 → 单元 → 集成 → 回归 → 基准 → 兼容性 → 混沌。

对每个 applicable 维度,读对应 `spec/0x-*.md`,按里面的"执行清单"跑。中途失败不中断,跑完所有维度再汇总。

**混沌测试破坏性,先询问用户。**

### 6. 计分 + 聚合

按 `spec/spec.md#打分规则` 的公式:
1. N/A 维度不计权重,其他维度权重归一到 100
2. 每个维度按 PASS / MISSING / FAIL 公式扣分
3. 加总得分 → 等级(A+ / A / B / C / F)

### 7. 终局输出

按等级给话术:

- **A+**(≥ 95):`牌没有问题 ✓` + 下一步建议(发 PR / 打 tag)
- **A**(85-94):`牌基本没问题,有几处小瑕疵,可发但建议顺手修`
- **B**(70-84):`牌有些问题,建议修了再发`
- **C**(60-69):`牌问题不少,先别发`
- **F**(< 60):`牌有大问题,禁止发版`

**不论等级**,都列每个维度的扣分明细:失败位置、原因、修复建议、对应 spec 锚点。

## 约束

- 不 commit / push / 打 tag / 发 release
- 不擅自改代码(除非用户下一句明确要求)
- 不对生产环境跑混沌
- MISSING 不能遮掩成 SKIP
- 测试被 `t.Skip()` / `@pytest.mark.skip` 在报告里单独标注,不并入 PASS
- 报告末尾附完整命令清单,用户可复现
