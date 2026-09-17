#!/bin/zsh

set -euo pipefail

# Select once per run; all operations below share the same implementation.
printf '%s\n' '微信多开 / WeChat Multi Launch' '1. 中文（默认）' '2. English'
printf '%s' '选择语言 / Choose language [1/2]: '
read -r UI_LANGUAGE
[[ "$UI_LANGUAGE" == "2" ]] || UI_LANGUAGE="1"

localize() {
  if [[ "$UI_LANGUAGE" == "2" ]]; then
    builtin printf '%s' "$1"
  else
    builtin printf '%s' "$2"
  fi
}

SOURCE_APP="/Applications/WeChat.app"
SCRIPT_DIR="${0:A:h}"
CUSTOM_ICON_DIR="$SCRIPT_DIR/wechat_icons"
BUILD_DIR=""
BUILD_APP=""
BACKUP_APP=""
BACKUP_APPS=()
BUILT_CLONES=()
SOURCE_PROCESS_PATTERN='^/Applications/WeChat\.app/Contents/MacOS/WeChat( |$)'

blue() {
  printf '\033[1;34m%s\033[0m\n' "$1"
}

green() {
  printf '\033[1;32m%s\033[0m\n' "$1"
}

yellow() {
  printf '\033[1;33m%s\033[0m\n' "$1"
}

red() {
  printf '\033[1;31m%s\033[0m\n' "$1" >&2
}

pause_before_close() {
  printf "$(localize '\nPress Return to close...' '\n按回车键关闭窗口…')"
  read -r _unused
}

cleanup() {
  if [[ -n "${BUILD_DIR:-}" && "$BUILD_DIR" == /Applications/.wechat-multi-build.* && -d "$BUILD_DIR" ]]; then
    rm -rf -- "$BUILD_DIR"
  fi
}

fail() {
  red "$(localize "Failed: $1" "失败：$1")"
  if [[ -n "${BACKUP_APP:-}" ]]; then
    yellow "$(localize "The previous copy remains at: $BACKUP_APP" "旧版副本仍保存在：$BACKUP_APP")"
  fi
  pause_before_close
  exit 1
}

trap cleanup EXIT INT TERM

printf '\033c'
blue "$(localize "WeChat Multi Launch" "微信多开 / WeChat Multi Launch")"
printf '%s\n' "----------------------------------------"
printf '%s\n' "$(localize "Create WeChat2.app, WeChat3.app and more from the installed WeChat.app." "从最新版 WeChat.app 创建 WeChat2.app、WeChat3.app 等多个副本。")"
printf '%s\n' "$(localize "Each copy uses its own Bundle ID and data directory." "每个副本使用独立的 Bundle ID 和数据目录。")"
printf '%s\n\n' "$(localize "Existing app copies move to Trash only after replacements pass verification." "新副本通过验证后，已有应用副本才会移到废纸篓。")"

if (( EUID == 0 )); then
  fail "$(localize "Double-click this script; do not run it with sudo." "请直接双击运行，不要通过 sudo 启动此脚本。")"
fi

if [[ ! -d "$SOURCE_APP" ]]; then
  fail "$(localize "Cannot find $SOURCE_APP. Install the original WeChat app first." "没有找到 $SOURCE_APP，请先安装原版微信。")"
fi

if [[ ! -w /Applications ]]; then
  fail "$(localize "Your account cannot write to /Applications. Check its permissions in Finder." "当前账户不能写入 /Applications。请在 Finder 中确认你有应用程序目录的管理权限。")"
fi

if ! codesign --verify --deep --strict "$SOURCE_APP" >/dev/null 2>&1; then
  fail "$(localize "The original app failed signature verification. Reinstall or update it first." "原版微信的代码签名校验失败，请先重新安装或更新原版微信。")"
fi

SOURCE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_APP/Contents/Info.plist" 2>/dev/null || printf "$(localize 'unknown' '未知')")
printf "$(localize 'Installed WeChat version: %s\n' '检测到原版微信版本：%s\n')" "$SOURCE_VERSION"
printf "$(localize 'Total instances, including the original [2-9]: ' '请输入总开数，包含原版微信 [2-9]：')"
read -r TOTAL_INSTANCES

if [[ ! "$TOTAL_INSTANCES" =~ '^[2-9]$' ]]; then
  fail "$(localize "Enter one number from 2 through 9." "请输入 2 到 9 之间的一个数字。")"
fi

printf "$(localize '\nThe following copies will be created or rebuilt:\n' '\n将创建或重建以下副本：\n')"
for (( CLONE_INDEX = 2; CLONE_INDEX <= TOTAL_INSTANCES; CLONE_INDEX++ )); do
  printf '  /Applications/WeChat%s.app\n' "$CLONE_INDEX"
  printf '  %s/Library/Containers/com.tencent.xinWeChat%s\n' "$HOME" "$CLONE_INDEX"
done
printf "$(localize '\nType y and press Return to start; anything else cancels: ' '\n输入 y 并按回车开始，输入其他内容取消：')"
read -r CONFIRMATION

if [[ "$CONFIRMATION" != "y" && "$CONFIRMATION" != "Y" ]]; then
  yellow "$(localize "Cancelled. Nothing was changed." "已取消，没有修改任何内容。")"
  pause_before_close
  exit 0
fi

for (( CLONE_INDEX = 2; CLONE_INDEX <= TOTAL_INSTANCES; CLONE_INDEX++ )); do
CLONE_APP="/Applications/WeChat${CLONE_INDEX}.app"
CLONE_BUNDLE_ID="com.tencent.xinWeChat${CLONE_INDEX}"
CLONE_DATA_DIR="$HOME/Library/Containers/com.tencent.xinWeChat${CLONE_INDEX}"
CLONE_PROCESS_PATTERN="^/Applications/WeChat${CLONE_INDEX}\\.app/Contents/MacOS/WeChat( |$)"
BACKUP_APP=""

printf '\n'
blue "$(localize "Building WeChat${CLONE_INDEX}.app" "正在构建 WeChat${CLONE_INDEX}.app")"
blue "$(localize "[1/6] Creating a temporary build directory..." "[1/6] 创建临时构建目录…")"
BUILD_DIR=$(mktemp -d /Applications/.wechat-multi-build.XXXXXX)
BUILD_APP="$BUILD_DIR/WeChat${CLONE_INDEX}.app"

blue "$(localize "[2/6] Copying the installed WeChat app (may take a few minutes)..." "[2/6] 复制最新版微信（约需数秒至数分钟）…")"
ditto "$SOURCE_APP" "$BUILD_APP" || fail "$(localize "Could not copy WeChat." "复制微信失败。")"

blue "$(localize "[3/6] Changing the copy's Bundle ID..." "[3/6] 修改副本 Bundle ID…")"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $CLONE_BUNDLE_ID" "$BUILD_APP/Contents/Info.plist" || fail "$(localize "Could not change the Bundle ID." "修改 Bundle ID 失败。")"

ACTUAL_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUILD_APP/Contents/Info.plist")
if [[ "$ACTUAL_BUNDLE_ID" != "$CLONE_BUNDLE_ID" ]]; then
  fail "$(localize "Bundle ID verification failed." "Bundle ID 校验失败。")"
fi

blue "$(localize "[4/6] Re-signing the copy and its nested components..." "[4/6] 重新签署副本及其内部组件…")"
# Newer builds put real libraries in Resources and forwarding stubs in
# Frameworks. Re-signing the stubs alone leaves unresolved runtime targets.
# Copy only matching payloads supplied by this same app version.
RESOURCE_CODE=("$BUILD_APP"/Contents/Resources/*.framework(N) "$BUILD_APP"/Contents/Resources/*.dylib(N))
for RESOURCE_ITEM in "${RESOURCE_CODE[@]}"; do
  FRAMEWORK_TARGET="$BUILD_APP/Contents/Frameworks/${RESOURCE_ITEM:t}"
  if [[ -e "$FRAMEWORK_TARGET" ]]; then
    ditto "$RESOURCE_ITEM" "$FRAMEWORK_TARGET" || fail "$(localize "Could not install the bundled runtime library." "无法复制应用自带的运行库。")"
  fi
  # Resources is not a standard nested-code location for codesign --deep.
  if ! codesign --force --deep --sign - "$RESOURCE_ITEM" >"$BUILD_DIR/resource-sign.log" 2>&1; then
    cat "$BUILD_DIR/resource-sign.log" >&2
    fail "$(localize "Could not sign a resource library." "资源目录中的运行库签名失败。")"
  fi
done
if ! codesign --force --deep --sign - "$BUILD_APP" >"$BUILD_DIR/codesign.log" 2>&1; then
  tail -40 "$BUILD_DIR/codesign.log" >&2
  fail "$(localize "Re-signing failed." "重新签名失败。")"
fi

blue "$(localize "[5/6] Verifying the new copy..." "[5/6] 严格验证新副本…")"
if ! codesign --verify --deep --strict --verbose=2 "$BUILD_APP" >"$BUILD_DIR/verify.log" 2>&1; then
  cat "$BUILD_DIR/verify.log" >&2
  fail "$(localize "Signature verification failed. The previous copy has not been replaced." "新副本签名验证失败。旧副本尚未被替换。")"
fi
for RESOURCE_ITEM in "${RESOURCE_CODE[@]}"; do
  if ! codesign --verify --deep --strict "$RESOURCE_ITEM"; then
    fail "$(localize "Resource library verification failed." "资源目录中的运行库校验失败。")"
  fi
done

if pgrep -f "$CLONE_PROCESS_PATTERN" >/dev/null 2>&1; then
  yellow "$(localize "Asking WeChat ${CLONE_INDEX} to quit..." "正在退出微信 ${CLONE_INDEX}…")"
  osascript -e "tell application id \"$CLONE_BUNDLE_ID\" to quit" >/dev/null 2>&1 || true

  for _attempt in {1..20}; do
    if ! pgrep -f "$CLONE_PROCESS_PATTERN" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done

  if pgrep -f "$CLONE_PROCESS_PATTERN" >/dev/null 2>&1; then
    fail "$(localize "WeChat ${CLONE_INDEX} is still running. Quit it manually and run this script again." "微信 ${CLONE_INDEX} 仍在运行。请手动退出后重新运行脚本。")"
  fi
fi

if [[ -e "$CLONE_APP" ]]; then
  BACKUP_STAMP=$(date '+%Y%m%d-%H%M%S')
  BACKUP_APP="$HOME/.Trash/WeChat${CLONE_INDEX}-backup-$BACKUP_STAMP.app"

  if [[ -e "$BACKUP_APP" ]]; then
    BACKUP_APP="$HOME/.Trash/WeChat${CLONE_INDEX}-backup-$BACKUP_STAMP-$$.app"
  fi

  mv "$CLONE_APP" "$BACKUP_APP" || fail "$(localize "Could not move the previous copy to Trash." "无法把旧副本移到废纸篓。")"
fi

if ! mv "$BUILD_APP" "$CLONE_APP"; then
  if [[ -n "$BACKUP_APP" && -d "$BACKUP_APP" && ! -e "$CLONE_APP" ]]; then
    if mv "$BACKUP_APP" "$CLONE_APP"; then
      BACKUP_APP=""
    fi
  fi
  fail "$(localize "Could not install the new copy; attempted to restore the previous copy." "无法安装新副本；已尝试恢复旧副本。")"
fi

BUILT_CLONES+=("$CLONE_APP")
if [[ -n "$BACKUP_APP" ]]; then
  BACKUP_APPS+=("$BACKUP_APP")
fi
cleanup
BUILD_DIR=""
done

blue "$(localize "[6/6] Starting and checking all WeChat instances..." "[6/6] 启动并检查所有微信实例…")"
open "$SOURCE_APP" || fail "$(localize "Could not launch the original app." "原版微信启动失败。")"
for CLONE_APP in "${BUILT_CLONES[@]}"; do
  open "$CLONE_APP" || fail "$(localize "Could not launch ${CLONE_APP:t}. Previous copies remain in Trash." "${CLONE_APP:t} 启动失败，旧副本仍在废纸篓中。")"
done
sleep 15

ALL_RUNNING=1
if pgrep -f "$SOURCE_PROCESS_PATTERN" >/dev/null 2>&1; then
  SOURCE_RUNNING="$(localize "yes" "是")"
else
  SOURCE_RUNNING="$(localize "no" "否")"
  ALL_RUNNING=0
fi

printf "$(localize '\nOriginal WeChat running: %s\n' '\n原版微信运行：%s\n')" "$SOURCE_RUNNING"
for (( CLONE_INDEX = 2; CLONE_INDEX <= TOTAL_INSTANCES; CLONE_INDEX++ )); do
  CLONE_PROCESS_PATTERN="^/Applications/WeChat${CLONE_INDEX}\\.app/Contents/MacOS/WeChat( |$)"
  if pgrep -f "$CLONE_PROCESS_PATTERN" >/dev/null 2>&1; then
    CLONE_RUNNING="$(localize "yes" "是")"
  else
    CLONE_RUNNING="$(localize "no" "否")"
    ALL_RUNNING=0
  fi
  printf "$(localize 'WeChat %s running: %s\n' '微信 %s 运行：%s\n')" "$CLONE_INDEX" "$CLONE_RUNNING"
done

if (( ALL_RUNNING == 0 )); then
  yellow "$(localize "The copies were installed and verified, but not all requested instances are running." "副本均已安装并通过验证，但没有检测到所有请求的微信实例。")"
  for BACKUP_APP in "${BACKUP_APPS[@]}"; do
    yellow "$(localize "Previous copy backup: $BACKUP_APP" "旧副本备份：$BACKUP_APP")"
  done
  pause_before_close
  exit 2
fi

green "$(localize "Done: all ${TOTAL_INSTANCES} WeChat instances are running." "完成：${TOTAL_INSTANCES} 个微信实例均已运行。")"
if (( ${#BACKUP_APPS[@]} > 0 )); then
  for BACKUP_APP in "${BACKUP_APPS[@]}"; do
    printf "$(localize 'Previous copy moved to Trash: %s\n' '旧副本已移到废纸篓：%s\n')" "$BACKUP_APP"
  done
  printf '%s\n' "$(localize "Delete the backup manually after checking your second account and chat history." "确认第二个账号和聊天记录正常后，可以手动删除它。")"
fi

printf '%s\n' "$(localize "If macOS asks for notification, camera or microphone access, grant access as needed." "如果系统询问通知、相机或麦克风权限，请按需要重新授权。")"

printf '\n'
blue "$(localize "Change copy icons manually" "手动更换副本图标")"
printf "$(localize 'Icon folder: %s\n' '图标文件夹：%s\n')" "$CUSTOM_ICON_DIR"
printf '%s\n' "$(localize "1. In Applications, right-click a WeChatN.app copy and choose Get Info." "1. 在“应用程序”中右键点击 WeChatN.app 副本，选择“显示简介”。")"
printf '%s\n' "$(localize "2. Drag an icon from the wechat_icons folder onto the small icon at the top left of the Get Info window to replace it." "2. 将 wechat_icons 文件夹中的图标拖到“显示简介”窗口左上角的小图标上，覆盖原图标。")"
pause_before_close
