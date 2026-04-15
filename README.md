# 🌊 Skill Lake

![Platform](https://img.shields.io/badge/Platform-macOS-blue)
![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter)
![License](https://img.shields.io/badge/License-MIT-green)

**Skill Lake** 是一款为 AI 开发者打造的 Agent Skill 本地化管理中心。无论您使用哪个 AI 编程助手，Skill Lake 都能帮您统一发现、安装、同步和管理您的专属 AI 技能。

## ✨ 核心特性

- **一站式技能管理**：兼容并管理多个主流 AI 编程助手的 Skill 生命周期。
- **丰富的技能商店 (Skill Store)**：聚合 GitHub 优质开源技能库（如 `anthropics/skills`），探索最新、最强的 AI 技能并实现一键安装。
- **默认 Agent 与智能同步**：支持设置默认 AI Agent，并能一键将技能灵活分发与同步至其他工作流中。
- **极致的丝滑体验**：纯原生 Flutter macOS 桌面应用构建，提供优雅、现代且极其流畅的用户界面体验。

## 🤖 支持的 AI Agent

Skill Lake 会自动扫描并管理以下主流助手在本地的扩展目录：

| AI 编程助手 / Agent | 默认本地技能目录映射 |
| :--- | :--- |
| **Cursor** | `~/.cursor/skills/` |
| **Claude Code** | `~/.claude/skills/` |
| **Codex CLI** | `~/.codex/skills/` |
| **Antigravity** | `~/.gemini/antigravity/skills/` |
| **Trae** | `~/.trae/skills/` |

## 🚀 快速开始

本项目为 Flutter macOS 桌面端应用，请在开始前确保您已准备好 Flutter macOS 开发环境。

### 依赖环境

- macOS 系统
- [Flutter SDK](https://flutter.dev/docs/get-started/install/macos) >= 3.x

### 编译与运行

1. **克隆项目源码**：

   ```bash
   git clone https://github.com/your-username/skill-lake.git
   cd skill-lake
   ```

2. **启用 macOS 桌面开发支持**（如果你是首次运行 Flutter 桌面端项目）：

   ```bash
   flutter config --enable-macos-desktop
   ```

3. **获取项目依赖包**：

   ```bash
   flutter pub get
   ```

4. **编译并启动应用**：

   ```bash
   flutter run -d macos
   ```

## ❓ 常见问题 (FAQ)

### ⚠️ 运行或安装时提示「“Skill Lake”已损坏，无法打开。您应该将它移到废纸篓。」怎么办？

由于应用暂未进行 Apple 开发者证书的签名与公证，macOS 的 Gatekeeper 机制可能会拦截此应用并给出“已损坏”或“移到废纸篓”的警告提示。

**🛠️ 解决方法：**
1. 遇到提示时，请先点击弹窗上的 **「取消」**。
2. 打开 macOS 的 **「系统设置」** > **「隐私与安全性」**。
3. 向下滚动到“安全性”板块，这里会有一条拦截记录（提示“Skill Lake”已被阻止使用）。
4. 点击旁边的 **「仍然打开」**（或 **「仍然允许」**）按钮，并在弹出的安全验证中输入您的 Mac 开机密码或通过触控 ID 授权。
5. 授权完成后，再次尝试打开 **Skill Lake**，此时弹出的确认框中会出现 **「打开」** 按钮，点击后系统将记住您的选择，以后就不会再被拦截了。