# Skill Lake

本地 AI Agent Skill 管理应用，支持统一管理 Cursor、Claude Code、Codex cli、Antigravity、Trae 的 Skill 生命周期。

## 运行方式（macOS）

1. 安装 Flutter SDK，并确保已启用 macOS 桌面支持：

```bash
flutter config --enable-macos-desktop
flutter doctor
```

2. 安装依赖并运行：

```bash
flutter pub get
flutter run -d macos
```
## Agent Skills 目录列表

应用会自动扫描以下目录发现已安装的 Skills：

- Cursor	~/.cursor/skills/
- Claude Code	~/.claude/skills/
- Codex cli	~/.codex/skills/
- Antigravity	~/.gemini/antigravity/skills/
- Trae	~/.trae/skills/-