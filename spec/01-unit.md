# 01 - 单元测试

> **适用**:/wyyp 几乎每次都跑(除非仓库形态判定为纯文档 / 纯配置)。验证函数 / 方法级别的正确性,所有外部依赖 mock。

## 三态判定

在跑用例前,先判定本维度状态(决定打分)。

| 状态 | 信号 | 打分影响 |
|------|------|---------|
| **applicable** | 有生产代码 + 探测到 ≥1 个测试文件 | 跑,按结果评分 |
| **MISSING** | 有生产代码 + 0 个测试文件 | **扣满 20 分**,报告里写"检测到 N 个源文件,0 个 `_test.go`" |
| **N/A** | 纯文档仓库 / 脚手架 / 纯配置 | 不扣分,权重归一 |

探测"生产代码"的启发式:
- Go:`*.go` 非 `_test.go` 且非 `vendor/` 的文件数 > 2
- Node:`src/**` 或顶层 `*.{ts,js}` 非 `*.test.*` 的文件数 > 2
- Python:非 `tests/` / `test_*.py` 的 `.py` 文件数 > 2

**MISSING 时的报告模板**:
```
[单元] MISSING — 扣 20 分
   检测到 12 个 .go 源文件,0 个 _test.go
   建议:从 biz/ 目录开始,每个 public 函数至少 1 个用例。
   参考:spec/01-unit.md#执行清单
```

## 执行清单

1. **发现测试文件**
   - Go:`*_test.go`(排除 `_integration_test.go` / build tag `integration|e2e`)
   - Node:`*.test.{ts,js}` / `*.spec.{ts,js}` / `__tests__/`
   - Python:`test_*.py` / `*_test.py`,在 `tests/unit/` 或顶层
   - Rust:`#[cfg(test)] mod tests` + `cargo test --lib`
   - Java:`src/test/java/**/*Test.java`

2. **跑命令**(优先调 Makefile target)
   ```bash
   # 首选
   make test-unit     # 或 make test / make cover

   # 兜底(按栈)
   go test -race -count=1 -coverprofile=coverage.out $(go list ./... | grep -v /test/e2e)
   npm test -- --coverage
   pytest tests/unit --cov=src --cov-report=term
   cargo test --lib
   mvn -Dtest='*Test' test
   ```

3. **判定 PASS**
   - 所有 test case 通过(不含 skip)
   - 覆盖率 ≥ `.wyyp.yml` 指定(默认 70%)
   - 跑 `-race`(Go)或等价并发检查(Java `-Dparallel=classes`),无 data race
   - 没有任何 `t.Skip()` / `it.skip()` / `@pytest.mark.skip` 未附原因

## 好测试的 10 条信号

| # | 信号 | 反例 |
|---|------|------|
| 1 | 一个 test 只测一件事 | `TestUser_AllPaths` 里塞 20 个断言 |
| 2 | 测试名描述场景 | `TestCreateOrder_EmptyName_ReturnsErrInvalidArg` > `TestCreate1` |
| 3 | 有明显的 Arrange / Act / Assert | 三段之间没有空行或注释 |
| 4 | 外部依赖全部 mock / stub | 测试里直连真 DB / 真 HTTP |
| 5 | 并发场景加 `-race` 跑过 | 没跑 race 的锁代码 |
| 6 | 表格驱动覆盖边界 | 只测 happy path |
| 7 | 错误路径有断言(不仅是 `err != nil`) | 只写 `require.Error(err)`,不查是不是预期那个错 |
| 8 | 不依赖执行顺序 | 测试 A 必须在测试 B 前跑 |
| 9 | 不泄漏 goroutine / file handle | `goleak.VerifyNone(t)` 缺失 |
| 10 | Fail 消息能定位 | `assert.True(t, ok)` 无消息 |

## 覆盖率解读

**不要只看数字。**

```bash
go tool cover -func=coverage.out | grep total:
# total: (statements) 82.3%
```

- 82% 看着很高,但如果核心业务函数(`biz/` 下)只有 50%,整体数字被 `utils/` / `pkg/` 拉高 —— 要按目录拆。
- 覆盖率高但断言弱(只断言 `err != nil`)也是假通过。

按目录看:
```bash
go tool cover -func=coverage.out | awk '
  /\/biz\// { b_total++; if ($NF+0 >= 80) b_pass++ }
  END { printf "biz/: %d/%d (%.0f%%)\n", b_pass, b_total, 100*b_pass/b_total }
'
```

## 聚合输出字段

PASS 时上报:
- `tests_total` / `tests_passed` / `tests_skipped`
- `coverage_total` / `coverage_by_dir`(如果 `.wyyp.yml` 指定了 scope)
- `race_detected`(Go 强制 false 才 PASS)
- `duration`

FAIL 时上报:
- 每个失败 case 的文件:行、用例名、期望 vs 实际
- 如果是 race:竞争地址和两条 stack
- 如果是覆盖率不足:缺多少、差哪些目录

## 反模式(发现立即报 FAIL)

- **时间依赖**:`time.Sleep(100ms)` 等待异步——用 `synctest`(Go 1.24+)或 channel 同步
- **全局状态没清**:`TestMain` 没 teardown,后续测试受影响
- **测试里 print 到 stdout**:测试框架有 `t.Log` / `t.Logf`,不要 `fmt.Println`
- **mock 过头**:连 `time.Now` 都不 mock,测试在边界日期跑挂——用时钟注入
- **跳过未修**:`t.Skip("TODO: flaky")` 超过 30 天,视为 FAIL

## 自查

- [ ] 所有被测函数至少 1 个单元测试
- [ ] 错误路径断言了具体错误类型,不只是 `err != nil`
- [ ] 表格驱动覆盖了边界(nil / 空 / 最大值 / Unicode / 负数)
- [ ] 并发代码带 `-race` 跑
- [ ] 覆盖率分目录看,核心目录达标
- [ ] 没有 unexplained skip
- [ ] 测试独立,可乱序跑
