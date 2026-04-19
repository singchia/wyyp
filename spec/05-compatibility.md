# 05 - 兼容性测试

> **适用**:项目声明了多版本 / 多平台 / 多后端矩阵时必跑。验证在每个支持的环境下都能跑、结果一致。

## 常见兼容性维度

| 维度 | 例子 | 触发信号 |
|------|------|---------|
| 语言版本 | Go 1.22 / 1.23 / 1.24 | `go.mod` 里 `go 1.xx`,`.github/workflows/*.yml` 的 matrix |
| OS | linux / darwin / windows | 发版产物多平台,或 CI matrix 有 `runs-on` 多值 |
| CPU 架构 | amd64 / arm64 | Docker manifest,或 `GOARCH` 多值 |
| 数据库版本 | MySQL 5.7 / 8.0 / 8.4 | `docker-compose.yml` 里多个 DB 镜像 |
| 客户端 SDK 版本 | Node 18 / 20 / 22,Python 3.10 / 3.11 / 3.12 | `.nvmrc` 范围、`python_requires` 范围 |
| 协议版本 | API v1 / v2 并存 | 多 proto package |
| 浏览器 | Chrome / Firefox / Safari | `playwright.config.*` 的 projects |

## 执行清单

1. **探测矩阵**
   - 优先:`.wyyp.yml` 的 `compatibility` 段
   - 次选:`.github/workflows/*.yml` 中的 `strategy.matrix`
   - 再次:`Dockerfile` / `docker-compose.yml` 多版本服务
   - 都没有 → **SKIP 本维度**,在报告里说明"项目未声明兼容性矩阵"

2. **生成用例集合**:矩阵各轴的笛卡尔积(+ 手工 `exclude` 列表)

3. **跑每个组合**
   ```bash
   # 典型 CI 做法:每个 matrix cell 一个 job
   # 本地 /wyyp 不用跑完所有组合,选代表:
   #   - 最低支持版本 × 1
   #   - 最高支持版本 × 1
   #   - 其他各版本 × 1(按需)

   make test-compat MATRIX='go-1.22,go-1.24'
   ```

4. **判定 PASS**
   - 矩阵中每个 cell:单元 + 集成测试都通过
   - 没有"只在某个版本通过"的用例(这是兼容性 bug 的明显信号)
   - 产物(二进制 / 镜像)在目标平台能启动(至少 `--version` 跑起来)

## 常见兼容性陷阱

### Go
- `sync/atomic` 在 32-bit arm 上对 int64 的对齐要求
- `filepath.Separator` / 路径大小写(macOS 默认不敏感,Linux 敏感)
- `syscall` 包跨平台差异
- CGo 依赖系统库,arm64 / amd64 镜像差异

### Node
- 原生模块(`better-sqlite3` / `sharp`)对 Node 大版本敏感
- `fetch` 在 Node 18 是 experimental,20 才稳定
- ESM / CJS 互操作在不同 Node 版本行为不同

### Python
- `typing` 在 3.10 加了 `|`,低版本要 `from __future__`
- 异步上下文 `asyncio.run` 行为在 3.11 改过
- wheel 在不同 musllinux / manylinux 标签下可用性

### 数据库
- MySQL 5.7 → 8.0:utf8mb4 默认、`SELECT` 不用 GROUP BY 时的严格模式
- Postgres 各版本对 JSON / JSONB 的语法支持
- Redis 6 / 7:RESP3 / 客户端库兼容

### API 协议
- Proto `reserved` 字段:删除字段后没占位,老客户端解析错位
- HTTP 响应 code 变更:`200 {"code": 0, "error": "..."}` → `400` 的破坏

## 报告格式

```
兼容性测试: PASS
  矩阵: go ∈ {1.22, 1.24} × os ∈ {linux, darwin} = 4 组合
    ✓ go1.22 / linux   单元 PASS, 集成 PASS
    ✓ go1.22 / darwin  单元 PASS, 集成 PASS
    ✓ go1.24 / linux   单元 PASS, 集成 PASS
    ✓ go1.24 / darwin  单元 PASS, 集成 PASS
  耗时: 3m40s
```

FAIL:
```
兼容性测试: FAIL
  go1.22 / linux  单元 FAIL:TestFileLock 在 go1.22 panic (use of unknown syscall)
  建议:查 go1.23 引入的 syscall,或补兼容分支(//go:build go1.23)
```

## 多平台二进制冒烟测试

如果是发版前 /wyyp,建议对每个平台产物跑 `--version` / `--help` 冒烟:

```bash
for plat in linux-amd64 linux-arm64 darwin-amd64 darwin-arm64; do
  qemu-binfmt $plat dist/myapp-$plat --version || echo "FAIL: $plat"
done
```

(本地不一定装了 qemu,如果没有就标注"本地跳过,CI 已覆盖"。)

## 反模式

- **只在 CI 的"latest" 版本跑**:最低支持版本没人测,出 bug
- **矩阵组合太多,CI 跑半小时**:用 `exclude` 裁剪,保代表性就行
- **某版本 FAIL 就放宽支持声明**:应该修代码或显式删除该版本支持(CHANGELOG + 给用户迁移期),不是默默删 matrix
- **产物只打一个架构**:ARM Mac 用户就炸

## 自查

- [ ] `.wyyp.yml` 或 CI matrix 声明了支持范围
- [ ] 矩阵每个 cell 单元 + 集成都跑
- [ ] 最低 / 最高版本都覆盖
- [ ] 多平台产物有冒烟 `--version`
- [ ] FAIL 有明确定位(哪个 cell)
- [ ] 不为 FAIL 偷偷删 matrix,而是修代码或显式降版本支持
