# wyyp — 我要验牌

> 让 AI agent 当你的 QA:`/wyyp` 一键做 7 维度质量验牌,全绿输出"牌没有问题 ✓"

中文 | [English](README.en.md)

## 它是什么

**wyyp**(我要验牌)是一个 AI agent skill,负责你项目的质量工程。开发完成后在 Claude Code 里输入 `/wyyp`,agent 会对项目执行 **7 个维度** 的质量验证,聚合结果,全部通过时给一个奖励式的"牌没有问题"。

七维度:

| 维度 | 何时跑 |
|------|--------|
| 单元测试 | 每次必跑 |
| 集成测试 | 有外部依赖(DB / Redis / MQ / HTTP)必跑 |
| 回归测试 | 有 `tests/regression/` 或 `@regression` 标记必跑 |
| 基准测试 | 有 `Benchmark*` 必跑 |
| 兼容性测试 | 有多版本 / 多平台矩阵必跑 |
| 混沌测试 | 用户显式要求或项目有 chaos 配置 |
| 安全测试 | 每次必跑 |

**语言 / 框架中性**:自动探测 Go / Node / TS / Python / Rust / Java / Kotlin / PHP 项目,优先走 `Makefile` 封装。不是 Go 专用。

## 为什么叫"我要验牌"

一次验牌(`/wyyp`)= 对整个项目各个维度的质量做一次"翻牌"。全部 PASS → **牌没有问题**。哪张牌有问题就直接指出来,不遮掩。

## 安装

### 通过 npx skills(推荐)

```bash
cd your-project
npx skills add singchia/wyyp
```

### 通过一行命令(带 `/wyyp` 命令 + AGENTS.md + .cursor/rules 自动落地)

```bash
cd your-project
bash <(curl -sSL https://raw.githubusercontent.com/singchia/wyyp/main/scripts/install.sh)
```

### 卸载

```bash
bash <(curl -sSL https://raw.githubusercontent.com/singchia/wyyp/main/scripts/uninstall.sh)

# 一并删 skill 目录
KEEP_SKILL=0 bash <(curl -sSL https://raw.githubusercontent.com/singchia/wyyp/main/scripts/uninstall.sh)
```

一条命令会:

1. 安装 skill 到 `~/.claude/skills/wyyp/`(`/wyyp` 直接触发 skill,不需要独立命令文件)
2. **检测 Codex / Trae / Trae-CN,symlink 到各自的 `skills/wyyp`**(重启对应 agent 后出现在"个人"skill 列表)
3. 在当前目录创建 `AGENTS.md`
4. 落 `.cursor/rules/wyyp.mdc`(Cursor 自动附加)
5. 落 `.wyyp.yml` 配置模板
6. 自动清理旧版(< 0.4.0)残留的 `~/.claude/commands/wyyp.md`

### 离线 / 内网

```bash
curl -L -o wyyp.skill https://github.com/singchia/wyyp/releases/latest/download/wyyp.skill
unzip wyyp.skill -d ~/.claude/skills/
```

## 使用

在 Claude Code 里:

```
/wyyp
```

Agent 会:

1. 探测技术栈(`go.mod` / `package.json` / `pyproject.toml` / ...)
2. 读 `Makefile` / `justfile` 看测试 target 封装
3. 按 7 维度矩阵判断要跑哪些
4. 逐个执行,中途失败不中断
5. 聚合结果,输出表格
6. 全部 PASS / SKIP → **`牌没有问题 ✓`**,附下一步建议
7. 有 FAIL → 列具体项 + 对应 spec 锚点 + 建议,**不自动改代码**

### 只跑指定维度

```
/wyyp unit,security
```

### 项目配置 `.wyyp.yml`

在项目根放一份 `.wyyp.yml`(`install.sh` 自带模板),可以:

- 指定跳过哪些维度(给理由)
- 调整覆盖率门槛(默认 70%)
- 调整基准回退阈值(默认 10%)
- 声明核心回归用例白名单
- 安全扫描豁免列表(必须带 reason + until)
- 声明兼容性矩阵
- 命令覆写

模板见 `docs/templates/wyyp-config-template.yml`。

## 三态 + 打分

每个维度探测后落一个状态:

| 状态 | 含义 | 打分 |
|------|------|------|
| **applicable** | 应该有 + 探测到测试 | 跑,按结果评分 |
| **MISSING** | 应该有 + 没有 | **扣满权重**(没测试不是 SKIP,是质量缺失) |
| **N/A** | 仓库性质不适用 | 不扣分,权重归一 |

加权总分映射到等级:

| 分数 | 等级 | 话术 |
|------|------|------|
| 95-100 | A+ | 牌没有问题 ✓ |
| 85-94  | A  | 牌基本没问题,有几处小瑕疵 |
| 70-84  | B  | 牌有些问题,建议修了再发 |
| 60-69  | C  | 牌问题不少,先别发 |
| < 60   | F  | **禁止发版** |

## 输出样例

### 全绿

```
╭─ wyyp 验牌结果 ────────────────────────────────────────╮
│  仓库形态:成熟服务(Go / 已发 tag / 有 CI)            │
│                                                        │
│  维度     │ 状态 │ 得分/权重 │ 说明                    │
│  安全     │ PASS │  20 / 20  │ gosec 0, trivy 0        │
│  单元     │ PASS │  20 / 20  │ 128 tests, cov 82%      │
│  集成     │ PASS │  15 / 15  │ 14 tests / docker       │
│  回归     │ PASS │  20 / 20  │ 7/7 核心                │
│  基准     │ PASS │  10 / 10  │ 无回退                  │
│  兼容性   │ PASS │  10 / 10  │ go1.22 / 1.24 ok        │
│  混沌     │ N/A  │    —      │ 单依赖服务              │
│                                                        │
│  总分: 100 / 100 (A+)    总耗时: 4m27s                 │
│                                                        │
│  牌没有问题 ✓                                          │
╰────────────────────────────────────────────────────────╯
```

### 有问题

```
╭─ wyyp 验牌结果 ────────────────────────────────────────╮
│  仓库形态:成熟服务                                     │
│                                                        │
│  维度     │ 状态    │ 得分/权重 │ 说明                 │
│  安全     │ PASS    │  20 / 20  │                      │
│  单元     │ PASS    │  20 / 20  │                      │
│  集成     │ MISSING │   0 / 15  │ 有 DB 调用无集成测试 │
│  回归     │ FAIL    │   0 / 20  │ 核心用例失败         │
│  基准     │ PASS    │  10 / 10  │                      │
│  兼容性   │ N/A     │    —      │                      │
│  混沌     │ N/A     │    —      │                      │
│                                                        │
│  总分: 65 / 100 (C)                                    │
│                                                        │
│  牌问题不少,先别发:                                   │
│  - [集成] MISSING — 检测到 internal/data/order_repo.go │
│    用了 database/sql,但 test/integration/ 为空        │
│    建议:testcontainers 起 mysql + 补 3 个用例         │
│  - [回归] tests/regression/checkout_test.go:45 FAIL    │
│    TestCheckoutRetry 期望 ErrDup,实际 nil              │
╰────────────────────────────────────────────────────────╯
```

## 设计原则

- **渐进式披露**:7 维度各一个 spec 子文件,agent 按触发场景加载,不一次读完。
- **优先封装 target**:有 `Makefile` / `justfile` 就用,不绕过去直接调语言命令(避免本地和 CI 跑出不同结果)。
- **不自动改代码**:wyyp 只验证,改代码交给用户或下一条指令。
- **不破坏环境**:混沌测试默认告警不阻塞,生产环境绝不跑。
- **失败不遮掩**:测试被 skip / 超时 / flaky 都不算 PASS,报告如实。

## 相关 skill

- [gospec](https://github.com/singchia/gospec) — Go 后端 SDLC 全流程规范(同作者)

## License

MIT © singchia
