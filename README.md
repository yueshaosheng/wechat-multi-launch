# 微信多开

![Platform: macOS](https://img.shields.io/badge/platform-macOS-black?logo=apple)
![Verified WeChat: 4.1.15](https://img.shields.io/badge/WeChat-4.1.15_verified-07C160?logo=wechat&logoColor=white)
[![Latest release](https://img.shields.io/github/v/release/yueshaosheng/wechat-dual-launch)](https://github.com/yueshaosheng/wechat-dual-launch/releases/latest)

**简体中文** | [English](README.en.md)

macOS 微信多开脚本，支持中文 / English，可按总开数创建或重建 `WeChat2.app` 至 `WeChat9.app`。

## 适用平台

- **仅适用于 macOS**，不适用于 Windows、Linux、iOS 或 Android。
- 原版微信需安装在 `/Applications/WeChat.app`，当前账户需有“应用程序”目录的写入权限。
- **已验证微信版本：Mac 微信 4.1.15（v1.1.0）**，测试环境为 macOS 26.3 / Apple Silicon。已实际创建并同时运行原版、`WeChat2.app` 和 `WeChat3.app`，两个副本使用独立 Bundle ID 和数据目录；未全面验证消息收发及音视频等功能。

## 使用方法

1. 从 [Releases](https://github.com/yueshaosheng/wechat-dual-launch/releases/latest) 下载并解压安装包，双击 `WeChat-Multi-Launch.command`。
2. 选择语言：`1` 中文（默认），`2` English。
3. 输入总开数 `2`～`9`（包含原版），再输入 `y` 开始。例如输入 `4` 会创建或重建 `WeChat2.app`、`WeChat3.app` 和 `WeChat4.app`。

无需提前删除旧副本，也无需 `sudo`。若无法双击运行，在终端输入 `zsh `，拖入脚本后按回车。

## 工作原理

脚本为每个副本依次复制原版应用，使用 `com.tencent.xinWeChatN` Bundle ID，重新签名并验证，最后安装并检查所有请求的进程。每个新副本通过验证后，对应旧副本才会移到废纸篓。

针对 4.1.15，脚本将 Resources 中同版本的实际运行库复制到 Frameworks 对应位置，替换重签后无法正常工作的转发库，并单独签名验证 Resources 中的运行库。

副本使用 ad-hoc 临时签名，不保留腾讯的开发者签名、原版权限声明和 Hardened Runtime 配置。安全保护及部分功能可能受影响，独立数据目录不等于原版沙盒隔离。

## 更新与数据

- 原版升级后，重新运行脚本即可重建副本。
- 脚本不删除聊天数据；每个副本使用 `~/Library/Containers/com.tencent.xinWeChatN` 数据目录（`N` 为副本编号）。输入较小总开数不会删除编号更高的已有副本。
- 废纸篓中的旧副本只是应用备份，不是聊天记录备份。重建前请备份重要聊天记录，确认使用正常后再清理旧副本。

## 手动更换图标

在“应用程序”中右键点击 `WeChatN.app` → **显示简介**，将 `wechat_icons` 中的图标拖到简介窗口左上角的小图标上覆盖。脚本不会自动更换图标。
