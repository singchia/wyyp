# wyyp 验牌路由

> Agent 入口。/wyyp 触发后按此执行,**按维度按需加载子文件**。

## 维度路由表

| 维度 | spec | 何时跑 | 默认阻塞级别 |
|------|------|--------|-------------|
| 单元测试 | `01-unit.md` | 每次必跑 | FAIL → 阻塞 |
| 集成测试 | `02-integration.md` | 有外部依赖(DB / Redis / MQ / HTTP 客户端)必跑 | FAIL → 阻塞 |
| 回归测试 | `03-regression.md` | 有 `tests/regression/` 或 `@regression` 标记必跑 | FAIL → 阻塞 |
| 基准测试 | `04-benchmark.md` | 有 `Benchmark*` / `*.bench.*` 必跑 | 回退 > 阈值 → 阻塞 |
| 兼容性测试 | `05-compatibility.md` | 声明多版本 / 多平台矩阵时必跑 | FAIL → 阻塞 |
| 混沌测试 | `06-chaos.md` | 项目有 chaos 配置或用户显式要求 | 告警不阻塞(默认) |
| 安全测试 | `07-security.md` | 每次必跑 | HIGH/CRITICAL → 阻塞 |

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

**策略**:前四个是"快速失败"组,一般 5 分钟内结束;后三个是"深度验证"组。如果时间紧,可以只跑前四个,但必须在最终输出里明确说明跳过原因。

## 语言 / 栈识别

| 信号 | 栈 | 测试封装约定 |
|------|----|-----|
| `go.mod` | Go | `make test` / `go test ./...` |
| `package.json` 里有 `test` script | Node / TS | `npm test` / `pnpm test` |
| `pyproject.toml` / `requirements-dev.txt` | Python | `pytest` / `tox` / `nox` |
| `Cargo.toml` | Rust | `cargo test` |
| `pom.xml` / `build.gradle` | Java / Kotlin | `mvn test` / `gradle test` |

**红线**:如果项目有 `Makefile`(或 `justfile` / `Taskfile.yml`),必须先看里面的 test target,**优先调封装 target**,不要绕过去直接调语言命令——否则 CI 和本地会跑出不同结果。

## 项目配置文件 `.wyyp.yml`(可选)

```yaml
# .wyyp.yml — 放在项目根
version: 1

# 跳过哪些维度(默认全部自动判断)
skip:
  - chaos

# 覆盖率门槛(默认 70%)
coverage:
  min: 80
  scope: biz,data       # 只统计这些目录

# 基准回退阈值(默认 10%)
benchmark:
  baseline: .wyyp/baseline.json
  regression_threshold: 0.15   # 15%

# 回归用例
regression:
  tag: "@regression"
  dir: tests/regression/

# 安全
security:
  severity_block: HIGH,CRITICAL
  allowlist:
    - CVE-2024-99999   # 有豁免理由的漏洞,附注释

# 兼容性矩阵
compatibility:
  go: ["1.22", "1.24"]
  os: [linux, darwin]
  arch: [amd64, arm64]
```

## 核心约束(任何维度都要遵守)

1. **真实 > 好看**:测试通过 ≠ 覆盖到位,覆盖率虚高要看用例是否真断言。
2. **跑不动不等于通过**:测试被跳过 / 标记 `t.Skip()` / `@pytest.mark.skip` 必须在聚合报告里单独列出,不能算 PASS。
3. **别改生产代码**:/wyyp 只验证,不修代码(除非用户下一句明确要求)。
4. **别造数据库 / chaos 破坏**:会做 destructive 动作的步骤先问用户。
5. **别覆盖用户环境变量**:如果测试需要 env(DB connection / secret),提示用户设,不要从代码里偷读 `.env.production`。

## 最终输出格式

```
╭─ wyyp 验牌结果 ─────────────────────────────────────╮
│                                                        │
│  维度          │ 结果 │ 耗时   │ 说明                  │
│  单元          │ PASS │  12.3s │ 128 tests, cover 82%  │
│  集成          │ PASS │  45.1s │ 14 tests via docker   │
│  回归          │ PASS │   8.7s │ 7/7 核心用例          │
│  基准          │ PASS │   2m3s │ 无性能回退            │
│  兼容性        │ SKIP │    —   │ 项目未声明矩阵        │
│  混沌          │ SKIP │    —   │ 未要求                │
│  安全          │ PASS │  18.2s │ gosec 0, trivy 0 HIGH │
│                                                        │
│  总耗时: 4m27s                                         │
│                                                        │
│  牌没有问题 ✓                                          │
│                                                        │
│  下一步建议:可以发 PR / 打 tag 发版                   │
╰────────────────────────────────────────────────────────╯
```

有 FAIL 时,去掉"牌没有问题",替换为:

```
  牌有问题,请先修:
  - [单元] internal/order/biz/order_test.go:42 → TestCreateOrder_EmptyName 期望 errs.ErrInvalidArg,实际 nil
    建议:检查 biz/order.go:15 的参数校验是否被 middleware 吞了(见 spec/01-unit.md#断言)
  - [安全] govulncheck 报告 GO-2024-xxxx,影响 net/http
    建议:升级到 go 1.24.2+(见 spec/07-security.md#vuln)
```

## 自查

- [ ] 每次 /wyyp 都读了本文件和至少一个维度子文件
- [ ] 前四维度(安全 / 单元 / 集成 / 回归)全跑了,没跑的必须有原因
- [ ] 聚合表格里 SKIP 都有说明
- [ ] 有 FAIL 时不自动改代码,只给建议
- [ ] 全部 PASS 才输出"牌没有问题"
