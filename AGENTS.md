# wyyp — QA 质量工程 skill

本项目仓库同时也是 **wyyp** skill 的源码。AI agent 打开本仓库时:

- 主入口:`SKILL.md`
- 路由表 + /wyyp 工作流:`spec/spec.md`
- 7 维度 spec:`spec/01-unit.md` ... `spec/07-security.md`

## 核心约束(改本 skill 源码时遵守)

- SKILL.md frontmatter 只能用 `name` / `description` / `license` / `allowed-tools` / `metadata` / `compatibility`
- `description` 不能超 1024 字符
- 所有 `spec/0x-*.md` 必须有 `## 自查` 小节(CI 会校验)
- 路由表(spec/spec.md)引用的每个文件必须真实存在
- 新增维度必须同时改 SKILL.md + spec.md + 对应子文件,一处也不能漏

## 发版

打 tag `vX.Y.Z` 触发 `.github/workflows/release.yml`,自动构建 `wyyp.skill` 并发 Release。
