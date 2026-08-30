# 安装

## 1. 配置 .opencode/opencode.json

在项目根目录创建/编辑 `.opencode/opencode.json`：

```json
{
  "permission": {
    "skill": "allow"
  },
  "instructions": [
    "MEMORY.md"
  ]
}
```

## 2. 链接 Skill

```bash
mkdir -p .opencode/skills
ln -s ../skills/lesson .opencode/skills/lesson
```

## 3. 创建 MEMORY.md（如果没有）

Skill 会把经验写入项目根目录的 `MEMORY.md`：

```bash
cat > MEMORY.md << 'EOF'
# MEMORY.md — 项目铁律

---

## 开发规范

## 调试经验

## 工具配置

## 代码风格

---
EOF
```

## 使用

```
/lesson 或 记录经验
```
