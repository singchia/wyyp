#!/usr/bin/env python3
"""
validate-skill.py — 校验 wyyp skill 的结构和 SKILL.md frontmatter。

只需要 python3 + pyyaml。

用法:
    python3 scripts/validate-skill.py              # 校验当前目录
    python3 scripts/validate-skill.py /path/to/dir # 校验指定目录
    python3 scripts/validate-skill.py --strict .   # 自查清单缺失视为失败

退出码:0 = 通过,1 = 失败。
"""

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("❌ 需要 pyyaml。安装:pip install pyyaml")
    sys.exit(2)


ALLOWED_FRONTMATTER = {
    "name",
    "description",
    "license",
    "allowed-tools",
    "metadata",
    "compatibility",
}
REQUIRED_FRONTMATTER = {"name", "description"}

WYYP_REQUIRED_FILES = [
    "SKILL.md",
    "AGENTS.md",
    "spec/spec.md",
    "spec/01-unit.md",
    "spec/02-integration.md",
    "spec/03-regression.md",
    "spec/04-benchmark.md",
    "spec/05-compatibility.md",
    "spec/06-chaos.md",
    "spec/07-security.md",
    "docs/templates/project-agents-template.md",
    "docs/templates/cursor-rule-template.mdc",
    "docs/templates/wyyp-config-template.yml",
    "scripts/install.sh",
]

# 路由表里的 spec 子文件必须真实存在
ROUTING_LINK_RE = re.compile(r"`(\d{2}-[\w-]+\.md|spec\.md)`")

# 每个 spec 子文件应有"自查"小节
SELF_CHECK_PATTERN = re.compile(r"^##\s+(自查清单|自查|Checklist|checklist|Self-check)\b", re.MULTILINE)
SELF_CHECK_EXEMPT = {
    "spec/spec.md",   # 入口路由文件本身也应有 ## 自查,但放开也可
}


def validate_frontmatter(skill_md: Path):
    content = skill_md.read_text()
    if not content.startswith("---"):
        return False, "SKILL.md 缺少 YAML frontmatter"

    m = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not m:
        return False, "SKILL.md frontmatter 格式不合法"

    try:
        fm = yaml.safe_load(m.group(1))
    except yaml.YAMLError as e:
        return False, f"frontmatter YAML 解析失败: {e}"

    if not isinstance(fm, dict):
        return False, "frontmatter 必须是 YAML 字典"

    missing = REQUIRED_FRONTMATTER - fm.keys()
    if missing:
        return False, f"缺少必填字段: {', '.join(sorted(missing))}"

    extra = set(fm.keys()) - ALLOWED_FRONTMATTER
    if extra:
        return False, (
            f"frontmatter 含不允许字段: {', '.join(sorted(extra))}\n"
            f"   允许的字段: {', '.join(sorted(ALLOWED_FRONTMATTER))}"
        )

    name = fm["name"]
    if not isinstance(name, str):
        return False, "name 必须是字符串"
    if not re.match(r"^[a-z0-9-]+$", name):
        return False, f"name '{name}' 必须是 kebab-case"
    if len(name) > 64:
        return False, f"name 太长 ({len(name)} > 64)"
    if name.startswith("-") or name.endswith("-") or "--" in name:
        return False, f"name '{name}' 连字符位置不合法"

    desc = fm["description"]
    if not isinstance(desc, str):
        return False, "description 必须是字符串"
    if len(desc) > 1024:
        return False, f"description 太长 ({len(desc)} > 1024)"
    if "<" in desc or ">" in desc:
        return False, "description 不能包含尖括号"

    return True, name


def validate_files(skill_dir: Path):
    missing = [rel for rel in WYYP_REQUIRED_FILES if not (skill_dir / rel).exists()]
    if missing:
        return False, "缺少必备文件:\n   " + "\n   ".join(missing)
    return True, ""


def validate_routing_links(skill_dir: Path):
    spec_md = skill_dir / "spec" / "spec.md"
    text = spec_md.read_text()
    spec_root = skill_dir / "spec"
    broken = []
    for match in ROUTING_LINK_RE.findall(text):
        if match == "spec.md":
            continue
        target = spec_root / match
        if not target.exists():
            broken.append(match)
    if broken:
        return False, "spec/spec.md 路由表引用了不存在的文件:\n   " + "\n   ".join(sorted(set(broken)))
    return True, ""


def validate_self_check(skill_dir: Path):
    spec_root = skill_dir / "spec"
    missing = []
    for md in spec_root.rglob("*.md"):
        rel = md.relative_to(skill_dir).as_posix()
        if rel in SELF_CHECK_EXEMPT:
            continue
        body = md.read_text()
        if not SELF_CHECK_PATTERN.search(body):
            missing.append(rel)
    if missing:
        return False, "以下 spec 子文件缺少 `## 自查` 小节:\n   " + "\n   ".join(sorted(missing))
    return True, ""


def validate(skill_dir: str, strict: bool = False):
    skill_dir = Path(skill_dir).resolve()
    warnings = []

    if not skill_dir.is_dir():
        return False, f"目录不存在: {skill_dir}", warnings

    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        return False, f"SKILL.md 不存在: {skill_md}", warnings

    ok, msg = validate_frontmatter(skill_md)
    if not ok:
        return False, msg, warnings
    name = msg

    ok, msg = validate_files(skill_dir)
    if not ok:
        return False, msg, warnings

    ok, msg = validate_routing_links(skill_dir)
    if not ok:
        return False, msg, warnings

    ok, msg = validate_self_check(skill_dir)
    if not ok:
        if strict:
            return False, msg, warnings
        warnings.append(msg)

    return True, (
        f"skill '{name}' 通过校验"
        f"(frontmatter + {len(WYYP_REQUIRED_FILES)} 必备文件 + 路由完整性"
        f"{' + 自查清单' if not warnings else ''})"
    ), warnings


if __name__ == "__main__":
    args = sys.argv[1:]
    strict = "--strict" in args
    args = [a for a in args if a != "--strict"]
    target = args[0] if args else "."
    ok, msg, warnings = validate(target, strict=strict)
    for w in warnings:
        print("⚠️  " + w)
    print(("✅ " if ok else "❌ ") + msg)
    sys.exit(0 if ok else 1)
