# 微信多开

![Platform: macOS](https://img.shields.io/badge/platform-macOS-black?logo=apple)
![Verified WeChat: 4.2.0](https://img.shields.io/badge/WeChat-4.2.0_verified-07C160?logo=wechat&logoColor=white)
[![Latest release](https://img.shields.io/github/v/release/yueshaosheng/wechat-multi-launch)](https://github.com/yueshaosheng/wechat-multi-launch/releases/latest)

**简体中文** | [English](README.en.md)

macOS 微信多开工具，支持中文 / English，可按总开数创建或重建 `WeChat2.app` 至 `WeChat9.app`，并自动为每个副本换上不同颜色的图标。提供命令行与原生图形界面（GUI）两种用法。

## 适用平台

- **仅适用于 macOS**，不适用于 Windows、Linux、iOS 或 Android。
- 原版微信需安装在 `/Applications/WeChat.app`，当前账户需有“应用程序”目录的写入权限。
- **已验证微信版本：Mac 微信 4.2.0（v1.3.0）**。测试环境为 macOS 26.7.3 / Apple Silicon。

## 使用方法

### 方法一：一行命令

```sh
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/yueshaosheng/wechat-multi-launch/main/WeChat-Multi-Launch.command)"
```

粘贴到“终端”里按回车，按命令行提示操作即可。

### 方法二：下载图形界面（GUI）

从 [Releases](https://github.com/yueshaosheng/wechat-multi-launch/releases/latest) 下载 DMG 并安装 GUI 即可。

## 更新与数据安全说明

- 原版升级后，重新运行脚本即可重建副本。
- 脚本不删除聊天数据；每个副本使用 `~/Library/Containers/com.tencent.xinWeChatN` 数据目录（`N` 为副本编号）。输入较小总开数不会删除编号更高的已有副本。
- 废纸篓中的旧副本只是应用备份，不是聊天记录备份。重建前请备份重要聊天记录，确认使用正常后再清理旧副本。
