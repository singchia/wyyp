# 02 - 集成测试

> **适用**:项目有外部依赖(DB / Redis / MQ / 第三方 HTTP)时必跑。验证组件之间的交互,用真实(或容器化的)依赖。

## 与单元测试的分界

| 维度 | 单元 | 集成 |
|------|------|------|
| 依赖 | 全部 mock | 真实(容器化) |
| 数据库 | 不碰 | testcontainers / docker-compose |
| 外部 HTTP | httptest / nock / responses | 真调用或 wiremock / prism |
| 速度 | < 1s per case | 5s~60s per case |
| 在 CI | 每次都跑 | 每次都跑(用 services 容器) |

## 执行清单

1. **探测集成测试的位置**
   - Go:带 build tag `integration` / `e2e`,或目录 `test/integration/`
   - Node:`*.integration.test.{ts,js}` 或 `test/integration/`
   - Python:`tests/integration/`
   - 通用:`docker-compose.test.yml` / `Testcontainersfile`

2. **起依赖**(按探测结果)
   ```bash
   # 首选
   make test-integration     # Makefile 应该封装容器启停

   # 兜底
   docker compose -f docker-compose.test.yml up -d --wait
   go test -tags=integration -count=1 ./test/integration/...
   docker compose -f docker-compose.test.yml down -v
   ```

3. **判定 PASS**
   - 所有集成用例通过
   - 没有用例因依赖启动失败被跳过(skip 计入 FAIL)
   - 测试结束后容器清理干净(再跑一次能用)
   - 无数据残留影响下次跑(每个 case 用独立 schema / namespace / key prefix)

## testcontainers 优先

推荐 `testcontainers-go` / `testcontainers-node` / `testcontainers-python` 在测试代码里起容器,而不是依赖外部 `docker-compose up`。好处:

- 本地 / CI 行为一致
- 不需要外部 orchestration
- 并行跑时端口不冲突
- 测试结束容器自动清理

```go
// Go 示例
ctx := context.Background()
mysqlC, err := mysql.Run(ctx,
    "mysql:8.0",
    mysql.WithDatabase("test"),
    mysql.WithUsername("root"),
    mysql.WithPassword("root"),
)
t.Cleanup(func() { _ = mysqlC.Terminate(ctx) })
```

## 数据隔离策略

选一套,别混:

| 策略 | 适用 | 代价 |
|------|------|------|
| 每个 case 起新容器 | 慢但最稳 | 100 个 case × 5s = 8 分钟 |
| 每个 case 独立 schema / DB | 快 | 要管理 schema 生命周期 |
| 每个 case 独立 key 前缀 | 适合 Redis / Kafka topic | 清理不彻底会污染 |
| 每个 case 独立事务 + rollback | 只适合事务型 DB | 不能测 commit 后的行为 |

**红线**:不允许跨 case 共享可变状态。

## 判定外部依赖"起来了"

不要用 `sleep 10`。用健康检查:

- MySQL / Postgres:`mysqladmin ping` / `pg_isready`
- Redis:`redis-cli ping`
- Kafka:`kafka-topics.sh --list`
- HTTP service:`curl -f http://host/healthz`(要求被测服务必须暴露 `/healthz`)
- testcontainers 自带 wait strategies:用 `wait.ForLog` / `wait.ForHTTP`

容器起超 60s 没 ready → FAIL + 把容器日志摘到报告里。

## 和 E2E 的区别

- **集成**:测一个服务内,跨层(service ↔ biz ↔ data ↔ DB)。范围一个进程。
- **E2E**:测多个服务(API gateway → service A → service B → DB)。范围跨进程 / 跨网络。

E2E 在基础 QA 里不强求(慢、不稳)。如果项目有 `test/e2e/`,在集成测试通过后可选跑。本 spec 不覆盖完整 E2E,详细做法项目自己定。

## 反模式(发现立即报 FAIL)

- **用生产库做集成测试**:连接串里出现 `prod` / 真实域名
- **硬编码端口**:`localhost:3306` —— 用 testcontainers 动态端口
- **测试后不清理容器**:下次跑时 `Error starting userland proxy: listen tcp 0.0.0.0:3306: bind: address already in use`
- **依赖互联网**:集成测试调 `api.example.com`(第三方 API)——mock 掉或用 VCR
- **CI 里 skip 掉集成测试**:因为慢就跳过,等于没跑

## 聚合输出字段

PASS 时:
- `tests_total` / `tests_passed`
- 起了哪些依赖容器(镜像 + 版本)
- `duration`

FAIL 时:
- 哪个 case fail,错误消息
- 如果是容器启动失败:贴最后 50 行容器日志
- 如果是超时:超时前的 last log

## 自查

- [ ] 使用 testcontainers 或 docker-compose,不连生产
- [ ] 每 case 数据独立(schema / db / prefix / tx)
- [ ] 用健康检查等待依赖 ready,不 sleep
- [ ] 结束后容器清理
- [ ] 没有 hardcoded 端口
- [ ] 第三方 API 被 mock / VCR / stub
- [ ] CI 跑的和本地跑的是同一套(不在 CI 里 skip)
