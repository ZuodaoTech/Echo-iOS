# Echo - iOS 自我对话练习应用

<p align="center">
  <img src="https://img.shields.io/badge/平台-iOS%2015.6+-blue.svg" />
  <img src="https://img.shields.io/badge/Swift-5.0-orange.svg" />
  <img src="https://img.shields.io/badge/SwiftUI-3.0-green.svg" />
  <img src="https://img.shields.io/badge/许可证-MIT-lightgrey.svg" />
</p>

## 📱 概述

Echo 是一款强大的自我对话练习应用，旨在帮助用户通过个性化的肯定脚本和语音录音建立积极的习惯。该应用让用户能够创建、录制和播放自己的激励脚本，并支持自定义重复模式。

### ✨ 核心功能

- **📝 脚本管理**：创建和组织个性化的自我对话脚本，支持分类管理
- **🎙 语音录制**：为每个脚本录制自己的声音，实现真实的练习体验
- **🔄 智能重复**：自定义重复次数（1-10次）和间隔时间（1-3秒）
- **🎧 隐私模式**：自动播放保护 - 需要连接耳机才能播放，防止意外公开播放
- **📊 进度跟踪**：通过播放次数和时间戳监控练习进度
- **🌍 多语言转录**：支持多种语言的自动语音转文字（英语、中文、西班牙语、法语等）
- **⚡ 音频处理**：自动裁剪静音部分并优化音频质量

## 🚀 快速开始

### 环境要求

- macOS 13.0 或更高版本
- Xcode 15.0 或更高版本
- iOS 15.6+ 部署目标
- Swift 5.0

### 安装步骤

1. 克隆仓库：
```bash
git clone https://github.com/xiaolai/echo-ios.git
cd Echo-iOS
```

2. 在 Xcode 中打开项目：
```bash
open Echo.xcodeproj
```

3. 在项目设置中选择你的开发团队

4. 构建并运行（⌘R）

## 🏗 架构设计

应用采用 MVVM 架构，结合 SwiftUI 和 Core Data：

```
Echo/
├── Models/           # Core Data 数据模型（SelftalkScript、Category）
├── Views/            # SwiftUI 视图
│   ├── ScriptsListView.swift      # 脚本列表视图
│   ├── AddEditScriptView.swift     # 添加/编辑脚本视图
│   └── Components/                 # 可复用组件
├── Services/         # 音频服务层
│   ├── AudioCoordinator.swift      # 音频协调器（主控制器）
│   ├── RecordingService.swift      # 录音管理服务
│   ├── PlaybackService.swift       # 播放控制服务
│   ├── AudioProcessingService.swift # 转录和处理服务
│   └── AudioFileManager.swift      # 文件操作服务
└── Utilities/        # 工具函数和扩展
```

### 🎵 音频架构

音频系统采用协调器模式，配合专门的服务模块：

- **AudioCoordinator**：单例协调器，管理所有音频操作
- **RecordingService**：处理 AVAudioRecorder 和录音状态
- **PlaybackService**：管理 AVAudioPlayer 及重复逻辑
- **AudioProcessingService**：静音裁剪和语音转文字
- **AudioSessionManager**：音频会话配置和隐私模式检测
- **AudioFileManager**：录音文件的文件系统操作

## 🔧 核心技术

- **SwiftUI**：现代声明式 UI 框架
- **Core Data**：脚本和分类的持久化存储
- **AVFoundation**：音频录制和播放
- **Speech Framework**：设备端和云端转录
- **Combine**：响应式数据流和状态管理

## 📝 功能详解

### 隐私模式 🔒
自动检测音频输出路径，防止通过扬声器播放。用户必须连接耳机才能播放录音，保护隐私安全。

### 智能音频处理 🎛
- 自动裁剪录音开头和结尾的静音
- 双文件系统：保留原始文件用于转录，处理后的文件用于播放
- 针对语音识别兼容性的格式优化

### 多语言支持 🌐
- 支持 10+ 种语言的转录
- 特定语言的标点符号处理
- 西方语言的自动大写

## 🧪 测试

项目包含全面的测试覆盖：

```bash
# 运行所有测试
xcodebuild test -scheme "Echo" -sdk iphonesimulator

# 运行特定测试套件
xcodebuild test -scheme "Echo" -only-testing:EchoTests/AudioFileManagerTests
```

### 测试覆盖率
- **单元测试**：音频服务、Core Data 模型、业务逻辑（约 70%）
- **UI 测试**：主要用户流程、录音、播放（约 50%）
- **集成测试**：端到端场景

## 🛠 开发

### 构建项目

```bash
# Debug 构建
xcodebuild -scheme "Echo" -configuration Debug build

# Release 构建
xcodebuild -scheme "Echo" -configuration Release build
```

### 代码规范

项目使用 SwiftLint 保持代码一致性。规则定义在 `.swiftlint.yml` 文件中。

## 📚 文档

- [CLAUDE.md](CLAUDE.md) - 详细的开发指南和架构文档
- [API 文档](docs/api.md) - 服务层 API 参考（即将推出）

## 🤝 贡献指南

欢迎贡献！请随时提交 Pull Request。

1. Fork 项目
2. 创建功能分支（`git checkout -b feature/AmazingFeature`）
3. 提交更改（`git commit -m '添加某个很棒的功能'`）
4. 推送到分支（`git push origin feature/AmazingFeature`）
5. 开启 Pull Request

## 📄 许可证

本项目基于 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 👨‍💻 作者

**笑来** - [GitHub](https://github.com/xiaolai)

## 🙏 致谢

- 使用 SwiftUI 构建，致力于自我提升
- 特别感谢所有贡献者和测试者
- 基于 Apple 语音识别框架强力驱动

---

<p align="center">
用 ❤️ 为个人成长和积极的自我对话练习而制作
</p>