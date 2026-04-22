# 🌊 Skill Lake

简体中文 | [English](./README.md)

![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows-blue)
![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter)
![License](https://img.shields.io/badge/License-MIT-green)

**Skill Lake** 是一款跨平台（macOS / Windows）的 AI Agent Skill 管理工具。支持搜索、安装、删除、同步 Skill。

![Skill Lake 搜索](images/store_search.png)

## 核心特性

- **语义搜索**：基于 skillsmp API 提供强大的 AI 语义搜索功能，助您高效发现并安装最新 AI 技能。
- **一站式技能管理**：兼容并管理多个主流 AI 编程助手的 Skill 生命周期。
- **丰富的技能商店**：聚合 GitHub 优质开源技能库（如 `anthropics/skills`），探索最新、最强的 AI 技能并实现一键安装。
- **SKill 同步**：支持设置默认 AI Agent，并能一键将技能灵活分发与同步至其他Agent。

## 支持的 AI Agent

| AI 工具 | 个人级 Skills 路径 | 官方网站 |
| :--- | :--- | :--- |
| **Cursor** | `~/.cursor/skills/` (Windows: `%USERPROFILE%\\.cursor\\skills` or `%APPDATA%\\Cursor\\skills`) | <https://cursor.com/> |
| **Claude Code** | `~/.claude/skills/` (Windows: `%USERPROFILE%\\.claude\\skills` or `%APPDATA%\\Claude\\skills`) | <https://claude.com/product/claude-code> |
| **Codex** | `~/.codex/skills/` (Windows: `%USERPROFILE%\\.codex\\skills` or `%APPDATA%\\Codex\\skills`) | <https://openai.com/codex> |
| **Trae** | `~/.trae/skills/` (Windows: `%USERPROFILE%\\.trae\\skills` or `%APPDATA%\\Trae\\skills`) | <https://www.trae.ai/> |
| **Gemini CLI** | `~/.gemini/skills/` (Windows: `%USERPROFILE%\\.gemini\\skills`) | <https://geminicli.com/> |
| **Antigravity** | `~/.gemini/antigravity/skills/` (Windows: `%USERPROFILE%\\.gemini\\antigravity\\skills` or `%APPDATA%\\Antigravity\\skills`) | <https://antigravity.google/> |
| **GitHub Copilot** | `~/.copilot/skills/` (Windows: `%USERPROFILE%\\.copilot\\skills` or `%APPDATA%\\Copilot\\skills`) | <https://github.com/features/copilot> |

## 安装

### macOS (推荐)

通过 Homebrew 安装：

```bash
brew tap emlog/skill-lake
brew install --cask skill-lake
```

### Windows

请从 [Releases](https://github.com/emlog/skill-lake/releases) 页面下载最新的 `.exe` 安装包进行安装。

## 更新

```bash
brew update
brew upgrade --cask skill-lake
```

## 源码编译运行

### **1.克隆项目源码**：

```bash
git clone https://github.com/emlog/skill-lake.git
cd skill-lake
```

### **2.启用桌面开发支持**（如果你是首次运行 Flutter 桌面端项目）：

- macOS:

```bash
flutter config --enable-macos-desktop
```

- Windows:

```bash
flutter config --enable-windows-desktop
```

### **3.获取项目依赖包**：

```bash
flutter pub get
```

### **4.编译并启动应用**：

- macOS:

```bash
flutter run -d macos
```

- Windows:

```bash
flutter run -d windows
```


## ❓ 常见问题 (FAQ)

### ⚠️ 运行或安装时提示「“Skill Lake”已损坏，无法打开。您应该将它移到废纸篓。」怎么办？

由于应用暂未进行 Apple 开发者证书的签名与公证，macOS 的 Gatekeeper 机制可能会拦截此应用并给出“已损坏”或“移到废纸篓”的警告提示。

**解决方法：**
1. 遇到提示时，请先点击弹窗上的 **「取消」**。
2. 打开 macOS 的 **「系统设置」** > **「隐私与安全性」**。
3. 向下滚动到“安全性”板块，这里会有一条拦截记录（提示“Skill Lake”已被阻止使用）。
4. 点击旁边的 **「仍然打开」**（或 **「仍然允许」**）按钮，并在弹出的安全验证中输入您的 Mac 开机密码或通过触控 ID 授权。
5. 授权完成后，再次尝试打开 **Skill Lake**，此时弹出的确认框中会出现 **「打开」** 按钮，点击后系统将记住您的选择，以后就不会再被拦截了。