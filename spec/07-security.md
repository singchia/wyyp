# 07 - 安全测试

> **适用**:/wyyp 每次必跑(**安全维度永远 applicable**,不存在 MISSING / N/A)。

## 三态判定

| 状态 | 信号 | 打分 |
|------|------|------|
| **applicable** | 始终(任何仓库都要扫) | 跑 |
| MISSING | 不适用 | — |
| N/A | 不适用(即使纯文档仓库也要跑 gitleaks) | — |

安全是**红线维度**——没有豁免。扣分更重:每 CRITICAL 扣 10,每 HIGH 扣 5,扣到 0 为止。理论上一个 CRITICAL 漏洞就能把权重 20 扣到 10,直接拉到 B 级甚至更低。

## 每个仓库的"适用工具集"

按仓库形态定义哪些安全工具对本仓库适用。**不适用的工具不算"未装"**,不扣分。

| 形态 | 适用工具(✓ 必装) |
|------|-------------------|
| 纯文档 / skill / 纯配置 | gitleaks |
| Go 项目 | gitleaks + govulncheck + gosec |
| Node / TS 项目 | gitleaks + `npm audit` (+ semgrep 可选) |
| Python 项目 | gitleaks + pip-audit + bandit |
| Rust 项目 | gitleaks + cargo-audit |
| Java (Maven) | gitleaks + dependency-check |
| Docker 镜像发布 | 上述 + trivy |

**关键原则**:docs 仓库没装 `trivy` 不是问题(trivy 对它 N/A);Go 仓库没装 `govulncheck` 是问题。

## 工具未装的扣分规则

设 N = 本仓库适用工具数量,k = 其中未装的工具数。

| 场景 | 单工具扣分 |
|------|-----------|
| 工具装了,跑通(无 HIGH/CRITICAL) | 0 |
| 工具装了,检出 HIGH/CRITICAL | 按 severity 规则扣(见下文) |
| 工具未装 + **手工 fallback 扫描通过** | `security_weight × (1/N) × 0.2` |
| 工具未装 + 无 fallback / fallback 发现问题 | `security_weight × (1/N) × 1.0` |

**合并扣分公式**(k 个工具未装时):
```
penalty = security_weight × (k/N) × (0.2 if fallback_clean else 1.0)
```

**示例**(假设 security 权重归一后为 100):
- 纯文档仓库(N=1)gitleaks 未装 + 手工通过 → 扣 `100 × 1 × 0.2 = 20` → 得 80(B)
- 纯文档仓库 gitleaks 未装 + 手工也发现问题 → 扣 `100 × 1 × 1.0 = 100` → 得 0(F)
- Go 仓库(N=3)全部未装 + 手工通过 → 扣 `100 × 1 × 0.2 = 20` → 80(B)
- Go 仓库 1/3 未装 + 手工通过 → 扣 `100 × (1/3) × 0.2 ≈ 6.7` → 93(A)
- Go 仓库全装 + 0 漏洞 → 100(A+)

## 手工 fallback 扫描

仅当"某工具未装"时 agent 做下面这套兜底,覆盖不到完整工具功能,但能挡住最常见的问题:

1. **密钥 pattern 扫描**(等效于 gitleaks 的最小子集)
   - AWS:`AKIA[0-9A-Z]{16}`
   - GitHub:`ghp_[A-Za-z0-9]{36}` / `ghs_[A-Za-z0-9]{36}`
   - OpenAI:`sk-[A-Za-z0-9]{20,}`
   - Slack:`xox[pboa]-[A-Za-z0-9-]+`
   - Private key:`-----BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY`
   - 通用:`(?i)(password|secret|token|api[_-]?key)\s*[:=]\s*['"][A-Za-z0-9+/=_-]{16,}['"]`

2. **`.gitignore` 检查**:是否忽略了 `.env`、`*.pem`、`id_rsa`、`secrets.yml` 等

3. **提交历史快筛**:`git log --all -- .env .env.* *.pem id_rsa`(有命中 → 不算 clean)

4. **依赖漏洞兜底**(仅代码项目,无 gitleaks 也不跑这个):
   - Go:`go list -m all` → 看有无明显老版本(eg. `golang.org/x/crypto` < v0.17)
   - Node:`package-lock.json` 里看有无 `"lodash": "< 4.17.21"` 等已知高危版本
   - 这步很粗,只能抓最著名的几个

**全部通过才算 `fallback_clean`**。

## 工具跑出漏洞时的扣分

和"工具未装"独立。装了工具后跑出的问题,按严重度扣:
- 每 CRITICAL 扣 10(归一前 weight 的计量单位;归一后按比例放大)
- 每 HIGH 扣 5
- MEDIUM 仅告警,不扣分(`.wyyp.yml` 可改)
- 扣到 0 为止

## 四条基线

| # | 名称 | 工具(按栈) | 阻塞条件 |
|---|------|------------|---------|
| 1 | SAST(静态代码扫描) | Go: `gosec` / Node: `eslint-plugin-security` + `semgrep` / Python: `bandit` / Java: `spotbugs-security` | HIGH/CRITICAL 阻塞 |
| 2 | 依赖漏洞 | Go: `govulncheck` / Node: `npm audit` / Python: `pip-audit` / Java: `dependency-check` | 有 fix 的 HIGH/CRITICAL 阻塞 |
| 3 | 秘密泄露 | `gitleaks`(通用) | 任何命中阻塞 |
| 4 | 容器镜像扫描 | `trivy image`(如果项目发镜像) | HIGH/CRITICAL 阻塞 |

不覆盖的(需要专项,不在 /wyyp 标准流程):
- 动态扫描(DAST):要跑起服务,用 OWASP ZAP / Burp
- 渗透测试:人工
- 合规扫描(PCI / SOC2):另有工具链

## 执行清单

1. **探测工具可用**
   ```bash
   command -v gosec govulncheck gitleaks trivy semgrep bandit
   ```
   缺的工具 → 先让用户装(或 `make tools`),不要静默跳过。

2. **跑**(优先 Makefile)
   ```bash
   # 首选
   make lint vuln secscan

   # 兜底(按栈)
   gosec -severity=medium -confidence=medium ./...
   govulncheck ./...
   gitleaks detect --no-banner --redact -v
   trivy image your-image:tag --severity HIGH,CRITICAL --exit-code 1
   ```

3. **解析输出**
   - 把每个工具的 JSON / SARIF 抽到统一结构:`{severity, rule, location, message, fix?}`
   - 比对 `.wyyp.yml` 的 `security.allowlist`(CVE 豁免清单,必须有 reason 注释)
   - 非 allowlist 的 HIGH / CRITICAL → FAIL

4. **判定 PASS**
   - 四条基线全部通过
   - allowlist 里的豁免有注释(否则视为未豁免)
   - 没有新增秘密泄露

## 秘密检测细节

gitleaks 扫 git 历史 + 工作区。阻塞条件:

- 工作区任何命中 → 立即 FAIL(删掉 + 轮换密钥)
- 历史命中但已 rotate → allowlist 放行(`.gitleaks.toml` 的 `[allowlist]`)

**不要做**:
- 把密钥写进测试文件当 fixture
- 把密钥注释掉当"示例"
- 用 base64 / 简单编码"隐藏"密钥

**要做**:
- 用 env var + `.env.example`(例子文件只写占位)
- 测试用假值(`test-token-xxx`),和真 token 格式区分(前缀 `test-`)

## SAST 常见真阳性

Go `gosec`:
- G104 错误被忽略 → `_ = fn()` 要有注释说明
- G204 子进程参数来自变量 → 确认是否真的需要动态参数,或用 allowlist
- G402 TLS 配置 InsecureSkipVerify → 生产代码 0 容忍

Node:
- `eval` / `new Function` / `setTimeout(string)` → 不用就行
- 原型污染:`lodash.merge` 旧版本,换新版本或 `lodash-es`
- XSS:直接塞 `dangerouslySetInnerHTML` / `innerHTML`

Python:
- `yaml.load` 不带 SafeLoader
- `pickle.loads` 处理不可信数据
- `subprocess` 带 `shell=True`

## 依赖漏洞处理

`govulncheck`(Go)只报**被实际调用的**漏洞,比 `trivy fs` 精确。优先信它。

- 有 fix:升级版本,重跑
- 无 fix(upstream 还没修):
  - 如果代码未调用到漏洞函数,可写 allowlist + 监控 upstream
  - 如果调用到,找 workaround(比如用不同 API)或暂时降级功能

**禁止**:无脑 allowlist 所有漏洞"让 CI 先绿"。

## 容器镜像扫描

如果项目发 Docker 镜像:
```bash
trivy image --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  your-image:tag
```

- `--ignore-unfixed`:不阻塞 upstream 没修的漏洞(避免你搞不定)
- 基础镜像选 `gcr.io/distroless/*` 或 `alpine:latest` + 最小依赖,减小攻击面

## 报告格式

```
安全测试: PASS
  [1] SAST        gosec          0 HIGH, 2 MEDIUM(未阻塞)
  [2] 依赖漏洞    govulncheck    0
  [3] 秘密泄露    gitleaks       0
  [4] 容器扫描    trivy          0 HIGH, 0 CRITICAL(--ignore-unfixed)
  耗时: 18.2s
```

FAIL:
```
安全测试: FAIL
  [2] 依赖漏洞: GO-2024-3210 HIGH
      包:   golang.org/x/net@v0.20.0
      影响: 被 internal/http/client.go:45 调用
      fix:  升级到 v0.23.0+
  [3] 秘密泄露: 工作区命中
      文件: internal/cfg/default.go:12
      规则: AWS Access Key
      处理: 删除 + rotate key + 加入 allowlist(注明原因)
```

## `.wyyp.yml` 安全配置

```yaml
security:
  severity_block: [HIGH, CRITICAL]
  severity_warn: [MEDIUM]
  allowlist:
    - id: CVE-2024-99999
      reason: "upstream 未修,不影响本项目(未调用到受影响函数)"
      until: 2026-06-01      # 到期必须复查
    - id: gosec:G204
      path: internal/cmd/run.go
      reason: "参数来自可信配置,非用户输入"
```

## 反模式

- **CI 上 `|| true` 绕过扫描**:等于没扫
- **allowlist 无 reason 无 until**:漏洞一旦被豁免就永远豁免,失控
- **只跑 SAST 不跑依赖**:80% 的漏洞来自依赖
- **秘密扫描只扫 HEAD**:历史 commit 里的密钥已经泄露,即使删了工作区也要 rotate
- **镜像扫描扫 latest 标签**:应该扫构建出的具体 tag

## 自查

- [ ] 四条基线全跑(SAST / 依赖 / 秘密 / 容器)
- [ ] 工具都装好,没静默跳过
- [ ] HIGH/CRITICAL 无例外阻塞(allowlist 必须有 reason + until)
- [ ] 秘密扫描扫工作区 + git 历史
- [ ] 容器扫描用 `--ignore-unfixed` 避免假阻塞
- [ ] 报告里每个 FAIL 给出修复路径
- [ ] 无法修的漏洞有 workaround 记录
