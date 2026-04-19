# 03 - 回归测试

> **适用**:项目进入维护期(有 CHANGELOG / 已发过 tag)时必跑。验证历史 bug 不复现、核心业务流不断裂。

## 三态判定

| 状态 | 信号 | 打分 |
|------|------|------|
| **applicable** | 有 `tests/regression/` 目录 或 `@regression` 标记 或 `.wyyp.yml` 的 `regression.critical` 非空 | 跑 |
| **MISSING** | 已发过 ≥1 个 tag(`git tag` 非空)或 有 CHANGELOG,但上述信号全无 | **扣满 20 分** |
| **N/A** | MVP 初期(0 tag + 无 CHANGELOG) / 纯文档 / 脚手架 | 不扣分 |

判定逻辑:
```
has_tag    = git tag | head -1 非空
has_change = CHANGELOG.md 或 CHANGES.md 存在
has_regr   = tests/regression/ 或 grep "@regression" 或 .wyyp.yml has critical
```

- `(has_tag or has_change) and not has_regr` → MISSING
- `not has_tag and not has_change` → N/A(项目还没到维护期)
- `has_regr` → applicable

**MISSING 报告模板**:
```
[回归] MISSING — 扣 20 分
   项目已发过 3 个 tag(最新 v1.2.0),但无 tests/regression/ 目录也无 @regression 标记。
   每次 bug 修复应补一个回归用例,注释里写事故 ID / 原因。
   建议:创建 tests/regression/,从最近一次 hotfix 开始补。
   参考:spec/03-regression.md#回归用例维护守则
```

## 什么是"核心回归用例"

和普通单元 / 集成测试的区别:

- **普通测试**:覆盖实现分支,新增功能时一起写
- **回归测试**:**过去出过的 bug** 或 **核心业务流** 的冻结快照。每个用例都对应一个具体故障 / 一个关键场景——**删除一个就有风险**

典型来源:
| 来源 | 标记方式 |
|------|---------|
| 线上事故复盘 | 用例注释:`// Regression for INC-2024-0042` |
| 核心付费流程 | `// @regression checkout` |
| 登录 / 鉴权主路径 | `// @regression auth` |
| 数据完整性保证 | `// @regression data-integrity` |

## 执行清单

1. **识别回归用例集**
   - 优先:`.wyyp.yml` 的 `regression.critical` 白名单
   - 次选:目录 `tests/regression/`
   - 最后:用例名 / 注释带 `@regression` 或 `Regression_` 前缀

   如果三者都没有,**跳过本维度并在报告里标注 SKIP - 项目未定义回归用例集**。这是合理状态,但建议用户补一份白名单。

2. **独立跑**(和普通单元测试分开)
   ```bash
   # 首选
   make test-regression

   # 兜底
   go test -run 'Regression_|TestRegression' -count=1 ./...
   pytest -m regression
   npm test -- --testPathPattern=regression
   ```

3. **判定 PASS**
   - `.wyyp.yml` 里列的 "核心" 用例 100% 通过(任一失败 → FAIL + 阻塞)
   - 非核心的回归用例失败 → MEDIUM 级告警,不阻塞
   - 单个回归用例超时 → 视为 FAIL(回归用例不应该慢到超时)

## 白名单推荐结构

```yaml
# .wyyp.yml
regression:
  # 核心,任一失败就 FAIL 阻塞
  critical:
    - path: tests/regression/checkout_flow_test.go
      reason: "支付主流程,2023 年影响营收"
    - path: tests/regression/auth_test.go
      reason: "登录核心路径"

  # 普通,失败算 MEDIUM 告警,不阻塞
  standard_tag: "@regression"
  standard_dir: tests/regression/
```

## 回归用例维护守则

在 wyyp 输出报告的"建议"里提醒用户:

1. **每个用例注释里写事故 ID / 日期 / 根因一句话**
   ```go
   // Regression for INC-2024-0042 (2024-03-12): nil ptr on empty user.Profile.Avatar
   func TestCreateUser_EmptyAvatar_NoPanic(t *testing.T) { ... }
   ```

2. **不允许重命名 / 删除**核心回归用例,除非对应的"事故原因已在架构层规避"并且 PR 里有 reviewer 显式 approve
3. **不允许 skip**(跳过的回归用例 = 没有)。如果用例真过时,删除 + 在 CHANGELOG 记录,而不是 skip

## 与单元 / 集成测试的重叠

一个 case 可能同时是单元测试 + 回归测试。这没问题——用 tag / 目录组织,同一份代码不重复写。关键是 /wyyp 能按"回归集"独立统计通过率。

## 反模式

- **把回归用例塞进普通测试**:跑普通 `go test` 过了,回归未跑,出事故
- **标记为 flaky**:回归用例 flaky = 回归失效,必须修,不是打标签隐藏
- **只测 happy path**:回归应当精准覆盖历史 bug 场景,比 happy path 更细
- **只在发版时跑**:太晚,应每次 /wyyp 都跑

## 聚合输出

```
回归测试: PASS
  核心: 7/7 全部通过
    ✓ checkout_flow_test.go (支付主流程)
    ✓ auth_test.go (登录核心)
    ✓ ...
  普通: 42/44 通过(2 MEDIUM 告警,非阻塞)
    ⚠ idempotency_test.go:TestRetryDup
    ⚠ cache_test.go:TestTTLEdge
  耗时: 8.7s
```

## 自查

- [ ] 核心回归用例白名单存在(`.wyyp.yml` 或 `tests/regression/.critical.yml`)
- [ ] 每个核心用例注释里有事故 ID / 原因
- [ ] 核心用例 100% PASS,否则不放过
- [ ] 没有 unexplained skip
- [ ] 回归用例和普通测试能独立跑(有 tag / 目录)
- [ ] 报告里单独列回归结果,不并入"单元测试"
