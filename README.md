# 微信双开

![Platform: macOS](https://img.shields.io/badge/platform-macOS-black?logo=apple)
![Verified WeChat: 4.1.15](https://img.shields.io/badge/WeChat-4.1.15_verified-07C160?logo=wechat&logoColor=white)
[![Latest release](https://img.shields.io/github/v/release/yueshaosheng/wechat-dual-launch)](https://github.com/yueshaosheng/wechat-dual-launch/releases/latest)

**简体中文** | [English](README.en.md)

macOS 微信双开脚本，支持中文 / English，可创建或重建 `WeChat2.app`。

## 适用平台

- **仅适用于 macOS**，不适用于 Windows、Linux、iOS 或 Android。
- 原版微信需安装在 `/Applications/WeChat.app`，当前账户需有“应用程序”目录的写入权限。
- **已验证微信版本：Mac 微信 4.1.15（修复版 v1.0.1）**，测试环境为 macOS 26.3 / Apple Silicon。已完成脚本重建、双进程运行和独立数据目录检查；未全面验证消息收发及音视频等功能。此前 v1.0.0 在 4.1.13 上通过双开检查，但无法用于本机 4.1.15。

## 使用方法

1. 从 [Releases](https://github.com/yueshaosheng/wechat-dual-launch/releases/latest) 下载并解压安装包，双击 `WeChat-Dual-Launch.command`。
2. 选择语言：`1` 中文（默认），`2` English。
3. 输入 `y` 开始，完成后在第二个微信中登录。

无需提前删除旧副本，也无需 `sudo`。若无法双击运行，在终端输入 `zsh `，拖入脚本后按回车。

## 工作原理

脚本依次复制原版应用、修改 Bundle ID 为 `com.tencent.xinWeChat2`、重新签名并验证，最后安装副本并检查两个进程是否同时运行。新副本通过验证后，旧副本才会移到废纸篓。

针对 4.1.15，脚本将 Resources 中同版本的实际运行库复制到 Frameworks 对应位置，替换重签后无法正常工作的转发库，并单独签名验证 Resources 中的运行库。

副本使用 ad-hoc 临时签名，不保留腾讯的开发者签名、原版权限声明和 Hardened Runtime 配置。安全保护及部分功能可能受影响，独立数据目录不等于原版沙盒隔离。

## 更新与数据

- 原版升级后，重新运行脚本即可重建副本。
- 脚本不删除聊天数据；第二个微信的数据目录为 `~/Library/Containers/com.tencent.xinWeChat2`（上述版本已验证）。
- 废纸篓中的旧副本只是应用备份，不是聊天记录备份。重建前请备份重要聊天记录，确认使用正常后再清理旧副本。

## 手动更换图标

在“应用程序”中右键点击 `WeChat2.app` → **显示简介**，将 `wechat_icons` 中的图标拖到简介窗口左上角的小图标上覆盖。脚本不会自动更换图标。
