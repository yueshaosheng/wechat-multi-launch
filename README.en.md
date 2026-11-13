# WeChat Multi Launch

![Platform: macOS](https://img.shields.io/badge/platform-macOS-black?logo=apple)
![Verified WeChat: 4.2.0](https://img.shields.io/badge/WeChat-4.2.0_verified-07C160?logo=wechat&logoColor=white)
[![Latest release](https://img.shields.io/github/v/release/yueshaosheng/wechat-multi-launch)](https://github.com/yueshaosheng/wechat-multi-launch/releases/latest)

[简体中文](README.md) | **English**

A macOS tool to create or rebuild multiple copies from `WeChat2.app` through `WeChat9.app`, with Chinese and English prompts and an automatic alternate icon for every copy. Available as a command-line script or a native graphical app (GUI).

## Platform

- **macOS only.** Not for Windows, Linux, iOS or Android.
- Install the original app at `/Applications/WeChat.app`. Your account needs write access to Applications.
- **Verified version: WeChat for Mac 4.2.0 with v1.3.0**. Tested on macOS 26.3 / Apple Silicon. Messaging, calls and other features have not been fully tested.

## Usage

### Option 1: one command

```sh
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/yueshaosheng/wechat-multi-launch/main/WeChat-Multi-Launch.command)"
```

Paste it into Terminal and press Return — no download needed. Keep the `zsh -c "$(curl …)"` form: `curl … | zsh` makes the script's prompts read from the script text instead of your keyboard. The first run fetches the icon files into `~/.cache/wechat-multi-launch` and reuses them afterwards; if they cannot be fetched, copies keep the original WeChat icon and multi-launch still works.

### Option 2: download the GUI

1. Download `WeChat-Multi-Launch-GUI-*.dmg` from [Releases](https://github.com/yueshaosheng/wechat-multi-launch/releases/latest), open it, and drag `WeChat Multi Launch.app` onto the `Applications` folder beside it to install.
2. If Gatekeeper blocks the first launch, right-click the app → **Open** → **Open** again (ad-hoc signed, not notarized).
3. Pick the language, total instance count (2–9) and icon option (rotate with drag-to-reorder, one colour, or original) in the window, then click **Create / Rebuild Copies**. Progress and the log update live.

The GUI embeds the same script and icons and runs **offline**; its behaviour is identical to the command line. You can also build it from source: with Xcode installed, run `zsh gui/build-app.sh`; the result is `gui/build/WeChat Multi Launch.app`.

Neither method requires deleting existing copies first or using `sudo`. Option 1 needs access to `raw.githubusercontent.com`; option 2 needs access to Releases.

## How it works

For every requested copy, the script copies the original app, assigns a `com.tencent.xinWeChatN` Bundle ID, writes the chosen icon from `wechat_icons`, re-signs and verifies it, installs it, and checks all requested processes. Each previous copy moves to Trash only after its replacement passes verification.

Icons are written before signing, so the ad-hoc signature covers them. Each copy sets `CFBundleIconFile = WeChatNIcon` and drops `CFBundleIconName`, which would otherwise keep pointing at the original icon inside `Assets.car`.

The script copies matching runtime libraries from Resources into Frameworks, replacing forwarding stubs that fail after re-signing, and explicitly signs and verifies runtime libraries in Resources (verified on 4.2.0).

The copy uses ad-hoc signing and does not preserve Tencent's developer identity, original entitlements or Hardened Runtime configuration. Security protections and some features may be affected; a separate data directory does not imply the original sandbox isolation.

## Updates and data

- Run the script again after updating the original app to rebuild the copy.
- The script does not delete chat data. Each copy uses `~/Library/Containers/com.tencent.xinWeChatN`, where `N` is its number. Choosing a smaller total does not remove existing higher-numbered copies.
- The old copy in Trash is an application backup, not a chat backup. Back up important chats before rebuilding and check that everything works before removing the old copy.

## Icons

`wechat_icons` contains seven colour variants. One-command runs download them to `~/.cache/wechat-multi-launch/wechat_icons`; delete that folder to fetch them again. In rotate mode they are assigned by copy number: `WeChat2.app` gets `flat`, `WeChat3.app` gets `classic`, `WeChat4.app` gets `minimal`, `WeChat5.app` gets `blue`, `WeChat6.app` gets `purple`, `WeChat7.app` gets `dark`, and `WeChat8.app` gets `gradient`. With more than seven copies the list starts over, so `WeChat9.app` matches `WeChat2.app`.

To change one copy later, right-click `WeChatN.app` in Applications → **Get Info**, then drag any icon from `wechat_icons` onto the small icon at the top left. Re-running the script rebuilds icons according to the chosen option.

If Finder or the Dock keeps showing an old icon, run `killall Dock` to refresh the cache.
