# 06 - 混沌测试

> **适用**:项目有 chaos 配置(`chaos-mesh.yml` / `litmus/` / `.chaos/`)或用户在 /wyyp 参数里显式要求。验证系统在依赖故障 / 网络扰动下的韧性。
>
> **默认只告警,不阻塞**(`.wyyp.yml` 可改为 block),因为混沌结果波动大,且用于生态系统级验证。

## 混沌的目标

不是"搞崩服务"——是验证:

1. **故障被正确降级**:依赖挂了,主路径返回兜底值 / 503,不级联爆炸
2. **超时有上限**:所有外部调用有 context timeout,不吊死线程池
3. **重试不放大故障**:指数退避 + jitter,不形成雪崩
4. **有可观测信号**:故障发生时 trace / metric / log 能还原现场
5. **恢复后能自愈**:依赖回来了,服务不需重启

## 执行清单

1. **探测 chaos 配置**
   - `chaos-mesh/`(Kubernetes CRD)
   - `litmus/` 实验 yml
   - `toxiproxy.json`(网络代理)
   - `.wyyp.yml` 的 `chaos` 段
   - 都没有 → SKIP,提示"项目无 chaos 配置,跳过"

2. **确认破坏性影响范围**
   - **必须先询问用户**:"本次 chaos 会对 X 服务注入 Y 故障,时长 Z 分钟,继续?"
   - 禁止对生产环境跑(/wyyp 不允许操作 `prod` 命名空间)
   - 只在隔离环境(local docker / dedicated staging)跑

3. **跑实验**(选项,按项目实际)
   ```bash
   # 首选
   make chaos

   # toxiproxy 网络注入(轻量)
   toxiproxy-cli create -l localhost:26379 -u redis:6379 redis-proxy
   toxiproxy-cli toxic add -t latency -a latency=500 redis-proxy
   # ... 跑关键路径测试,观察行为 ...
   toxiproxy-cli delete redis-proxy

   # chaos-mesh(k8s)
   kubectl apply -f .chaos/pod-kill.yml
   # ... 验证 HPA / 健康检查工作 ...
   kubectl delete -f .chaos/pod-kill.yml
   ```

4. **判定 PASS**(每条都要 verify)
   - 故障期间:关键路径 SLO 没破(error rate / P99 在阈值内)
   - 故障期间:降级返回的响应是预期格式(有 `fallback: true` 标记或明确错误码)
   - 故障恢复后:服务在 30s 内恢复健康(`/healthz` 200)
   - 期间产生了 trace 和告警(至少日志里能搜到故障信号)

## 推荐的混沌场景清单

按影响从轻到重,/wyyp 默认跑前 3 个:

| # | 场景 | 工具 | 预期行为 |
|---|------|------|---------|
| 1 | DB 慢查询(延迟 500ms) | toxiproxy | 请求 context 超时,返回 503,不吊死 pool |
| 2 | Redis 不可达 | toxiproxy / 直接停容器 | 降级到直查 DB 或兜底,不 panic |
| 3 | 下游 HTTP 5xx | wiremock / mockserver | 重试(带退避),超次数后返回错误 |
| 4 | 容器被 kill | docker kill / chaos-mesh pod-kill | k8s 重拉,流量路由正确 |
| 5 | 网络分区 | iptables / chaos-mesh network-partition | 选择正确侧(CP / AP) |
| 6 | CPU 打满 | stress-ng | 限流生效,关键路径不被饿死 |
| 7 | 磁盘写满 | dd / chaos-mesh io-fault | 日志 rotation 工作,不炸 |

## 常见暴露的问题

- 外部调用没设 context timeout,pool 爆满
- 重试没 jitter,所有实例同步重试形成尖峰
- 缓存未命中时 DB 被雪崩(thundering herd)
- 单 leader 节点挂了,follower 等超时太久才切换
- 告警触发但 Runbook 指向的 dashboard 404

## 报告格式

```
混沌测试: PASS(告警模式)
  场景: 3/3 通过
    ✓ DB 延迟 500ms:P99 1.2s (阈值 2s),error 0.1%,fallback 工作
    ✓ Redis 断连:降级到 DB 查询,成功率 100%
    ✓ 下游 5xx:触发重试(3 次),最终返回 503
  耗时: 4m12s
  ⚠ 注意:混沌结果有波动,单次 PASS 不代表绝对韧性。建议每周定时跑。
```

默认 `default-warn-only: true`,即使某条 FAIL 也只告警不阻塞。
用户想设成阻塞:`.wyyp.yml`:
```yaml
chaos:
  default_warn_only: false
  block_on: [db_latency, downstream_5xx]   # 列出必须 pass 的场景
```

## 反模式 / 绝对不能做

- **对生产跑 chaos**:除非团队有明确的 chaos engineering 流程 + 流量切换演练 + 值班 on-call 待命。/wyyp 自己不做这个。
- **无止损**:实验没 cleanup 脚本,注入失败后手工擦
- **没先告知**:团队不知道测试在跑,误以为是真事故
- **结果不采集**:跑完不看 trace / 指标,只看进程没崩就算通过
- **一次性压力测试当混沌**:chaos 是注入已知故障看行为,不是随便压

## 先决条件检查(跑之前 agent 要 verify)

- [ ] 目标环境非生产(`KUBECONFIG` context 不含 `prod`)
- [ ] 用户已确认可以做破坏性实验
- [ ] 有 cleanup 脚本或 chaos tool 自带恢复
- [ ] 关键指标采集通道在工作(能拿到实验期间数据)

任何一条不满足 → SKIP + 在报告里说明。

## 自查

- [ ] chaos 配置存在且 agent 能读懂
- [ ] 用户在 /wyyp 前已确认(破坏性动作)
- [ ] 目标环境绝对不是生产
- [ ] 场景跑完有明确的 cleanup
- [ ] 每个场景验证了 3 件事:SLO / 降级响应 / 恢复时间
- [ ] 默认告警不阻塞,除非 `.wyyp.yml` 改
- [ ] 报告显式说明"结果有波动"
