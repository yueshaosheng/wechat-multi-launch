# WeChat Multi Launch

![Platform: macOS](https://img.shields.io/badge/platform-macOS-black?logo=apple)
![Verified WeChat: 4.2.0](https://img.shields.io/badge/WeChat-4.2.0_verified-07C160?logo=wechat&logoColor=white)
[![Latest release](https://img.shields.io/github/v/release/yueshaosheng/wechat-multi-launch)](https://github.com/yueshaosheng/wechat-multi-launch/releases/latest)

[简体中文](README.md) | **English**

A macOS tool to create or rebuild multiple copies from `WeChat2.app` through `WeChat9.app`, with Chinese and English prompts and an automatic alternate icon for every copy. Available as a command-line script or a native graphical app (GUI).

## Platform

- **macOS only.** Not for Windows, Linux, iOS or Android.
- Install the original app at `/Applications/WeChat.app`. Your account needs write access to Applications.
- **Verified version: WeChat for Mac 4.2.0 with v1.3.0**. Tested on macOS 26.7.3 / Apple Silicon.

## Usage

### Option 1: one command

```sh
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/yueshaosheng/wechat-multi-launch/main/WeChat-Multi-Launch.command)"
```

Paste it into Terminal and follow the on-screen prompts.

### Option 2: download the GUI

Download the DMG from [Releases](https://github.com/yueshaosheng/wechat-multi-launch/releases/latest) and install the GUI.

## Updates and data safety

- Run the script again after updating the original app to rebuild the copy.
- The script does not delete chat data. Each copy uses `~/Library/Containers/com.tencent.xinWeChatN`, where `N` is its number. Choosing a smaller total does not remove existing higher-numbered copies.
- The old copy in Trash is an application backup, not a chat backup. Back up important chats before rebuilding and check that everything works before removing the old copy.
