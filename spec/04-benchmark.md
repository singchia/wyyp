# 04 - 基准测试

> **适用**:项目有 `Benchmark*` / `*.bench.*` / `criterion` 等基准测试时必跑。对比 baseline,发现性能回退。

## 目标

基准测试不是"跑得快"——是"这次改动没让关键路径变慢"。所以重点不是绝对值,是**和 baseline 的差值**。

## 执行清单

1. **探测基准用例**
   - Go:`func Benchmark*(b *testing.B)`
   - Node:`benchmark` / `vitest bench` / `tinybench`
   - Python:`pytest-benchmark` / `asv`
   - Rust:`criterion` / `#[bench]`
   - Java:JMH(`@Benchmark`)

2. **读 baseline**
   - `.wyyp.yml` 的 `benchmark.baseline` 指定路径(默认 `.wyyp/bench-baseline.json`)
   - baseline 不存在 → 首次运行,**建议用户跑一次后把结果保存为 baseline**,本次标 SKIP + 提示
   - baseline 存在 → 跑 benchmark 后对比

3. **跑命令**
   ```bash
   # 首选
   make bench

   # 兜底
   go test -bench=. -benchmem -run=^$ -count=5 -benchtime=1s ./... | tee .wyyp/bench-current.txt
   cargo bench
   pytest --benchmark-only --benchmark-json=.wyyp/bench-current.json
   ```

   **-count=5** 降低随机噪音。**-run=^$** 跳过普通测试。

4. **对比 baseline**
   - Go:用 `benchstat old.txt new.txt`(`golang.org/x/perf/cmd/benchstat`)
   - Rust criterion:`cargo bench --baseline <name>` 自动对比
   - pytest-benchmark:`--benchmark-compare`

5. **判定 PASS**
   - 每个指标回退 ≤ 阈值(默认 10%,`.wyyp.yml` 可覆盖)
   - ns/op / MB/s / allocs/op 都要看,不只看 ns
   - 方差太大(benchstat 报 `p > 0.05`)算作不显著,不阻塞,但在报告里提示"结果不可信,建议增大 -count 重跑"

## 噪音控制(跑基准测试前必做)

- **关掉 CPU 动态频率**(本地):`sudo cpupower frequency-set -g performance`
- **固定核心**:`taskset -c 0,1 go test -bench=.`(避免跨核调度)
- **CI 跑基准**:用专用 runner(不跟其他 job 竞争 CPU)——否则数据不可信
- **至少 -count=5**,最好 -count=10
- **预热**:Go 的 `b.N` 自适应已经预热,其他栈要手动跑 1-2 次弃掉首次

## baseline 管理

baseline 来自**稳定的主分支 HEAD**,不是当前分支。更新策略:

```bash
# 在 main 分支跑,保存为 baseline
make bench > .wyyp/bench-baseline.txt
git add .wyyp/bench-baseline.txt
git commit -m "chore(bench): update baseline after v1.2.0"
```

建议每次发版后更新 baseline,否则长期积累的小回退会被漏掉。

## 报告格式

```
基准测试: PASS
  对比 baseline (.wyyp/bench-baseline.txt):
    BenchmarkParseJSON-8        改善 +4.2%   (450ns → 431ns)
    BenchmarkEncodeProto-8      持平    ±0%
    BenchmarkDBInsert-8         回退 -3.1%   (12.3µs → 12.7µs)  ← 未触阈值
  阈值: 10%
  耗时: 2m3s
```

FAIL:
```
基准测试: FAIL
  BenchmarkHotPath-8  回退 -18.4%  (120ns → 142ns)  ← 超阈值
  建议:检查最近 commit 里涉及这条路径的改动(bisect)
```

## 反模式

- **只跑一次就对比**:随机噪音可能看着像回退
- **没有 baseline 也不告警**:/wyyp 应该提示用户保存 baseline
- **改基准用例后直接更新 baseline**:等于放弃监控——baseline 应该和用例版本对应
- **在开发机跑 benchmark 阻塞合并**:本地数据不稳,阻塞用 CI 的专用 runner

## 聚合输出字段

- 每个 bench 指标:baseline / current / delta%
- 是否所有都在阈值内
- 如果 baseline 缺失:提示路径
- CI runner 信息(如果可拿到):CPU / 核心数

## 自查

- [ ] 有 baseline,/wyyp 能对比
- [ ] benchmark 至少跑 5 次(-count=5)
- [ ] ns/op 和 allocs/op 都看
- [ ] 超阈值阻塞,未超阈值显示为绿
- [ ] 方差过大给警告(p > 0.05)
- [ ] 报告里列每个指标的 delta,不只给总体结论
