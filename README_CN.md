# Echo - 你的私人自我对话伙伴

<p align="center">
  <img src="icon.png" width="120" height="120" alt="Echo 应用图标">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/平台-iOS%2015.6+-blue.svg" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange.svg" />
  <img src="https://img.shields.io/badge/SwiftUI-5.0-green.svg" />
  <img src="https://img.shields.io/badge/许可证-MIT-lightgrey.svg" />
</p>

<p align="center">
  <b>用个性化的自我肯定改变你的内在对话</b>
</p>

## 🌟 Echo 是什么？

Echo 是一款精心设计的 iOS 应用，通过个性化的自我对话脚本帮助你建立积极的习惯。用自己的声音录制肯定语、励志演讲或日常提醒，然后通过可自定义的重复模式播放，强化积极思维。

## ✨ 核心功能

### 📝 **智能脚本管理**
- 创建无限量的个性化自我对话脚本
- 使用彩色标签轻松分类整理
- 美观的卡片界面，颜色随机变化
- 快速搜索和筛选功能

### 🎙️ **专业录音**
- 高质量音频录制（44.1kHz，AAC 格式）
- 自动静音裁剪，录音更清晰
- 60 秒录音限制，让信息更聚焦
- 高级降噪技术，音质清澈透明

### 🔄 **智能播放**
- 可自定义重复次数（每个脚本 1-10 次）
- 可调节重复间隔（0-10 秒）
- 播放不同卡片时自动停止
- 支持后台播放

### 🔒 **隐私优先**
- **隐私模式**：自动扬声器保护 - 需要连接耳机才能播放
- 本地存储 - 你的录音永远不会离开设备
- 可选 iCloud 同步，在你的设备间备份

### 🌍 **多语言支持**
- 界面支持 15+ 种语言
- 多语言语音转文字
- 智能语言检测转录

### 📊 **进度跟踪**
- 跟踪每个脚本的播放次数
- 最后播放时间戳
- 播放时的可视化进度指示器

## 📱 开始使用

### 用户指南

1. **从 App Store 下载**（即将推出）
2. 启动 Echo，点击"+"按钮创建你的第一个脚本
3. 写下你的肯定语或励志信息
4. 点击麦克风用自己的声音录制
5. 使用你喜欢的重复设置播放

### 开发者指南

#### 环境要求
- macOS 13.0+
- Xcode 15.0+
- iOS 设备或模拟器（iOS 15.6+）

#### 安装步骤

```bash
# 克隆仓库
git clone https://github.com/ZuodaoTech/Echo-iOS.git
cd Echo-iOS

# 在 Xcode 中打开
open Echo.xcodeproj

# 选择你的团队并运行
```

## 🎯 使用场景

- **早晨肯定语**：用积极的自我对话开始新的一天
- **建立自信**：在重要事件前强化赋能信念
- **习惯养成**：为正在培养的新习惯创建提醒
- **冥想与正念**：录制冥想用的平静咒语
- **语言学习**：通过重复练习发音
- **目标可视化**：每天口述并强化你的目标

## 🏗️ 技术架构

### 核心技术
- **SwiftUI 5.0**：现代声明式 UI，流畅动画
- **Core Data + CloudKit**：持久化存储，可选 iCloud 同步
- **AVFoundation**：专业音频录制和播放
- **Speech Framework**：设备端转录，保护隐私
- **Combine**：响应式状态管理

### 服务架构
```
AudioCoordinator（外观模式）
├── RecordingService     - 音频采集和编码
├── PlaybackService      - 带重复的播放
├── AudioSessionManager  - 隐私模式和路由
├── AudioFileManager     - 文件操作
└── AudioProcessingService - 静音裁剪和转录
```

## 🔐 隐私与安全

- **无分析**：零跟踪或分析
- **本地优先**：所有数据存储在设备本地
- **隐私模式**：自动扬声器保护
- **iCloud 加密**：可选同步使用 Apple 的加密 CloudKit
- **无第三方服务**：仅使用纯 Apple 框架

## 🎨 最近更新

### 版本 0.3.0（最新）
- ✅ 每次启动应用时刷新的动态卡片颜色
- ✅ 修复 CloudKit 同步，改进 iCloud 数据管理
- ✅ 改进音频播放稳定性
- ✅ 添加重复间隔设置
- ✅ 增强标签管理系统
- ✅ 应用启动性能优化

### 版本 0.2.0
- ✅ 完整的标签系统实现
- ✅ 隐私模式（原隐私模式）
- ✅ 60 秒录音限制，带可视化反馈
- ✅ 高级降噪
- ✅ 自动静音裁剪

## 🛠️ 开发功能

### 隐藏开发者菜单
在"我"标签页向下-向下-向上滑动以访问：
- 性能指标
- CloudKit 同步状态
- 调试选项
- 数据管理工具

## 🤝 贡献

我们欢迎贡献！详情请查看我们的[贡献指南](CONTRIBUTING.md)。

### 如何贡献
1. Fork 仓库
2. 创建你的功能分支（`git checkout -b feature/AmazingFeature`）
3. 提交你的更改（`git commit -m '添加 AmazingFeature'`）
4. 推送到分支（`git push origin feature/AmazingFeature`）
5. 开启 Pull Request

## 📄 许可证

本项目基于 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 👥 团队

- **创建者**：[笑来](https://github.com/xiaolai)
- **贡献者**：[查看所有贡献者](https://github.com/ZuodaoTech/Echo-iOS/graphs/contributors)

## 🙏 致谢

- 使用 SwiftUI 构建，致力于心理健康
- 受积极自我对话力量的启发
- 感谢所有 beta 测试者和贡献者

## 📞 支持

- **问题**：[GitHub Issues](https://github.com/ZuodaoTech/Echo-iOS/issues)
- **讨论**：[GitHub Discussions](https://github.com/ZuodaoTech/Echo-iOS/discussions)
- **邮箱**：support@zuodao.tech

---

<p align="center">
  <b>Echo</b> - 放大你的内心声音<br>
  用 ❤️ 为个人成长而制作
</p>