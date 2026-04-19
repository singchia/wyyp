# wyyp 验牌路由

> Agent 入口。/wyyp 触发后按此执行,**按维度按需加载子文件**。

## 维度路由表

| 维度 | spec | 应该有的信号 | 默认权重 |
|------|------|--------------|---------:|
| 单元测试 | `01-unit.md` | 有生产代码(非 README-only) | 20 |
| 集成测试 | `02-integration.md` | 代码里有 DB / Redis / MQ / HTTP client | 15 |
| 回归测试 | `03-regression.md` | 有 CHANGELOG 或已发过 tag | 20 |
| 基准测试 | `04-benchmark.md` | 有明显热路径(handler / pipeline / 编解码) | 10 |
| 兼容性测试 | `05-compatibility.md` | 声明了多版本 / 多平台 | 10 |
| 混沌测试 | `06-chaos.md` | 有 ≥2 个外部依赖 / 多服务 | 5 |
| 安全测试 | `07-security.md` | 始终 | 20 |
| **合计** | | | **100** |

---

## 三态判定(探测阶段的核心)

Agent 对每个维度先做探测,落到三个状态之一:

| 状态 | 含义 | 打分 |
|------|------|------|
| **应用(applicable)** | 应该有 + 探测到测试文件 | 跑完按结果给分 |
| **MISSING** | 应该有 + 没有 | **算 FAIL,扣满分** —— 没测试不是 SKIP,是质量缺失 |
| **N/A** | 仓库性质不适用 | 不扣分,权重归一到其他维度 |

### "应该有 + 没有" 的典型场景 → MISSING

- `go.mod` 存在,有 `.go` 文件,但 `**/*_test.go` 为 0 个 → 单元 MISSING
- 代码里 `import "database/sql"` / `go-redis` 等,但 `test/integration/` 空 → 集成 MISSING
- 已发过 tag(`git tag` 非空),但 `tests/regression/` 和 `@regression` 标记都没有 → 回归 MISSING

### "不该有" 的典型场景 → N/A

| 仓库形态 | 典型 N/A 维度 | 理由 |
|----------|---------------|------|
| 纯文档仓库(>90% `.md`) | 单元 / 集成 / 回归 / 基准 / 兼容 / 混沌 | 跑 gitleaks + markdown lint 够了 |
| 单文件 CLI 工具 | 集成 / 混沌 | 无外部依赖 |
| 脚手架 / 模板仓库 | 几乎全部除安全外 | 模板不跑业务逻辑 |
| 纯配置仓库(Helm / Terraform) | 单元 / 回归 / 基准 | 验证 yaml lint + 安全即可 |
| 早期 MVP(<500 LOC,无 CI) | 集成 / 回归 / 基准 / 兼容 / 混沌 | 先保底 |

Agent 探测结果和"应该有"的启发式不匹配时,**在报告里写明理由**——用户可通过 `.wyyp.yml` 里 `skip: { <维度>: "理由" }` 显式声明 N/A。

---

## 打分规则

### 每个维度的基础扣分公式

| 维度 | 扣分方式 |
|------|---------|
| 单元 | `failed / total × weight`;MISSING 扣满 |
| 集成 | 同上 |
| 回归(核心) | 任一失败 → 扣满(不容忍) |
| 回归(普通) | `failed / total × weight` |
| 基准 | `min(weight, (actual_regression% - threshold%) / threshold% × weight)` |
| 兼容性 | `failed_cells / total_cells × weight` |
| 混沌 | 默认告警不扣分,`default_warn_only: false` 时按场景失败数扣 |
| 安全 | 每 CRITICAL 扣 10,每 HIGH 扣 5,扣到 0 为止 |

### N/A 维度的权重归一化

```
original_weights = {unit: 20, int: 15, reg: 20, bench: 10, compat: 10, chaos: 5, sec: 20}
na = {bench, compat, chaos}                     # 探测为 N/A 的
applicable = all - na
sum_applicable = sum(original_weights[d] for d in applicable)  # 65
for d in applicable:
  scaled_weights[d] = round(original_weights[d] * 100 / sum_applicable)
```

### 等级映射

| 分数 | 等级 | 终局话术 |
|------|------|---------|
| 95-100 | A+ | 牌没有问题 ✓ |
| 85-94 | A | 牌基本没问题,有几处小瑕疵,可发但建议顺手修 |
| 70-84 | B | 牌有些问题,建议修了再发 |
| 60-69 | C | 牌问题不少,先别发 |
| < 60 | F | 牌有大问题,**禁止发版**,按报告修完再来 |

---

## /wyyp 执行流程(标准版)

```
Step 0: 项目探测(技术栈 / Makefile 封装 / 仓库形态)
   ↓
Step 1: 成熟度 / 适用性判定 —— 每维度落到 applicable / MISSING / N/A
   ↓
Step 2: 读 .wyyp.yml(覆盖默认权重、门槛、skip 声明)
   ↓
Step 3: 按维度执行(applicable 的跑,MISSING 和 N/A 不跑但要计分)
   ├─ 安全(最快,先跑)
   ├─ 单元
   ├─ 集成
   ├─ 回归
   ├─ 基准
   ├─ 兼容性
   └─ 混沌(破坏性,先询问)
   ↓
Step 4: 按公式加权计算总分 + 等级
   ↓
Step 5: 输出报告
   ├─ score ≥ 95        → "牌没有问题 ✓"
   ├─ 60 ≤ score < 95   → 分级话术 + 扣分明细 + 修复建议
   └─ score < 60        → "禁止发版" + 每一条 FAIL 详情
```

---

## 执行顺序(推荐)

```
安全测试(静态扫描,最快)
  ↓
单元测试(快)
  ↓
集成测试(起外部依赖)
  ↓
回归测试(核心业务用例)
  ↓
基准测试(对比 baseline)
  ↓
兼容性测试(矩阵)
  ↓
混沌测试(可选,最慢)
```

时间紧可以只跑前四个(安全 / 单元 / 集成 / 回归)——但必须在报告里明确说"后三维度因时间限制跳过",且跳过的不计分(权重归一给前四个)。

---

## 语言 / 栈识别

| 信号 | 栈 | 测试封装约定 |
|------|----|-----|
| `go.mod` | Go | `make test` / `go test ./...` |
| `package.json` 里有 `test` script | Node / TS | `npm test` / `pnpm test` |
| `pyproject.toml` / `requirements-dev.txt` | Python | `pytest` / `tox` / `nox` |
| `Cargo.toml` | Rust | `cargo test` |
| `pom.xml` / `build.gradle` | Java / Kotlin | `mvn test` / `gradle test` |

**红线**:如果项目有 `Makefile`(或 `justfile` / `Taskfile.yml`),必须先看里面的 test target,**优先调封装 target**,不要绕过去直接调语言命令。

---

## 仓库形态快速识别

Agent 在 Step 0 用以下信号给仓库分类,决定后续哪些维度一律标 N/A:

| 形态 | 识别信号 |
|------|---------|
| 纯文档 | `.md` 文件占 >90%,无 `go.mod` / `package.json` / 其他语言工程文件 |
| 单文件 CLI | 只有 `main.go` / 一个入口文件 + < 500 LOC,无 `internal/` / 无外部 DB 调用 |
| 脚手架 / 模板 | README 包含"template" / "scaffold",或有 `.gomplate.yaml` / `template.yaml` |
| 纯配置仓库 | 主要是 `.yaml` / `.tf` / `.hcl`,无业务代码 |
| MVP | 有代码但 `git tag` 为空 + 无 CI 配置 + LOC < 2000 |
| 成熟服务 | 有 CI + 已发 tag + 有 `internal/` 分层 + LOC > 2000 |

**形态一旦判定,在报告里显式写明**,让用户知道 agent 是按"MVP"还是"成熟服务"标准评的。

---

## 项目配置文件 `.wyyp.yml`(可选)

```yaml
version: 1

# 权重覆盖(不写走默认)
weights:
  unit: 20
  integration: 15
  regression: 20
  benchmark: 10
  compatibility: 10
  chaos: 5
  security: 20

# 显式声明 N/A 的维度(不计权重)—— 比 agent 自动判定更权威
skip:
  chaos: "MVP 阶段无演练环境"
  compatibility: "单平台 linux/amd64"

# 等级门槛(不写走默认)
grade:
  A_plus: 95
  A:      85
  B:      70
  C:      60

# 覆盖率门槛
coverage:
  min: 70
  scope: [biz, data]

# 基准
benchmark:
  baseline: .wyyp/bench-baseline.txt
  regression_threshold: 0.10
  count: 5

# 回归
regression:
  critical:
    - path: tests/regression/checkout_test.go
      reason: "支付主流程"
  standard_tag: "@regression"
  standard_dir: tests/regression/

# 安全
security:
  severity_block: [HIGH, CRITICAL]
  severity_warn:  [MEDIUM]
  allowlist:
    - id: CVE-2024-99999
      reason: "未调用到受影响函数"
      until: 2026-06-01

# 兼容性矩阵
compatibility:
  go: ["1.22", "1.24"]
  os: [linux, darwin]

# 混沌
chaos:
  default_warn_only: true
```

---

## 核心约束

1. **真实 > 好看**:测试通过 ≠ 覆盖到位,覆盖率虚高要看用例是否真断言
2. **跑不动不等于通过**:测试被 skip / `t.Skip()` / `@pytest.mark.skip` 必须在报告里单独列,不能并入 PASS
3. **别改生产代码**:/wyyp 只验证,不修代码(除非用户下一句明确要求)
4. **别造数据库 / chaos 破坏**:会做 destructive 动作的先问用户
5. **别覆盖用户环境变量**:测试需要的 env(DB connection / secret),提示用户设,不偷读 `.env.production`
6. **MISSING 不等于 SKIP**:应该有的维度没有时必须扣分,不允许遮掩

---

## 最终输出格式

### 全绿(score ≥ 95)

```
╭─ wyyp 验牌结果 ────────────────────────────────────────╮
│  仓库形态:成熟服务(Go / 已发 tag / 有 CI)           │
│                                                        │
│  维度          │ 状态 │ 得分/权重 │ 说明               │
│  安全          │ PASS │  20 / 20  │ gosec 0, trivy 0   │
│  单元          │ PASS │  20 / 20  │ 128 tests, cov 82% │
│  集成          │ PASS │  15 / 15  │ 14 tests / docker  │
│  回归          │ PASS │  20 / 20  │ 7/7 核心          │
│  基准          │ PASS │  10 / 10  │ 无回退            │
│  兼容性        │ PASS │  10 / 10  │ go1.22 / 1.24 ok  │
│  混沌          │ N/A  │  —        │ MVP 无配置        │
│                                                        │
│  总分: 100 / 100 (A+)   总耗时: 4m27s                  │
│                                                        │
│  牌没有问题 ✓                                          │
│                                                        │
│  下一步建议:可以发 PR / 打 tag 发版                   │
╰────────────────────────────────────────────────────────╯
```

### 有问题(score < 95)

```
╭─ wyyp 验牌结果 ────────────────────────────────────────╮
│  仓库形态:成熟服务                                     │
│                                                        │
│  维度          │ 状态    │ 得分/权重 │ 说明            │
│  安全          │ PASS    │ 20 / 20   │                 │
│  单元          │ PASS    │ 20 / 20   │                 │
│  集成          │ MISSING │  0 / 15   │ 有 DB 调用无集成测试 │
│  回归          │ FAIL    │  0 / 20   │ 核心用例失败    │
│  基准          │ PASS    │ 10 / 10   │                 │
│  兼容性        │ N/A     │  —        │ 已 skip         │
│  混沌          │ N/A     │  —        │                 │
│                                                        │
│  总分: 65 / 100 (C)                                    │
│                                                        │
│  牌问题不少,先别发:                                   │
│  - [集成] MISSING — 检测到 internal/data/order_repo.go │
│    用了 database/sql,但 test/integration/ 为空。       │
│    建议:用 testcontainers 起 mysql,给 order_repo 加 │
│    3 个集成用例(见 spec/02-integration.md#执行清单)│
│  - [回归] tests/regression/checkout_test.go:45         │
│    TestCheckoutRetry 期望 ErrDup,实际 nil              │
│    建议:检查 biz/checkout.go:78 的幂等逻辑             │
╰────────────────────────────────────────────────────────╯
```

---

## 自查

- [ ] 每次 /wyyp 读了本文件和至少一个维度子文件
- [ ] 仓库形态在报告里显式写明
- [ ] 每个维度的状态(applicable / MISSING / N/A)有明确依据
- [ ] N/A 的权重正确归一化到其他维度,合计仍为 100
- [ ] MISSING 不算 PASS / SKIP,扣满权重
- [ ] 总分 + 等级在报告里
- [ ] FAIL 有对应 spec 子文件的锚点
- [ ] 不自动改代码
- [ ] 奖励话术按等级给("牌没有问题" / "基本没问题" / "有些问题" / "禁止发版")
