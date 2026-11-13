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
# Used when the script runs without the downloaded package, e.g. one-liner mode.
REPO_ICON_ARCHIVE="https://github.com/yueshaosheng/wechat-multi-launch/archive/refs/heads/main.tar.gz"
ICON_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wechat-multi-launch"
# Icon files ship as wechat_<style>.icns; order here is the rotation order.
ICON_STYLES=(flat classic minimal blue purple dark gradient)
ICON_MODE="rotate"
ICON_STYLE=""
ICON_ORDER=()
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
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

# Prints the icon style for a clone index, or returns 1 when the original
# WeChat icon should be kept.
icon_style_for_index() {
  local index="$1"
  local slot
  case "$ICON_MODE" in
    none)  return 1 ;;
    style) printf '%s' "$ICON_STYLE" ;;
    order) slot=$(( index - 1 ))
           if (( slot >= 1 && slot <= ${#ICON_ORDER[@]} )); then
             printf '%s' "${ICON_ORDER[$slot]}"
           else
             slot=$(( ((index - 2) % ${#ICON_STYLES[@]}) + 1 ))
             printf '%s' "${ICON_STYLES[$slot]}"
           fi ;;
    *)     slot=$(( ((index - 2) % ${#ICON_STYLES[@]}) + 1 ))
           printf '%s' "${ICON_STYLES[$slot]}" ;;
  esac
}

# Replaces the bundle icon before signing, so the new art is covered by the
# ad-hoc signature. CFBundleIconName is removed because it points at the
# AppIcon asset inside Assets.car, which would win over CFBundleIconFile.
apply_clone_icon() {
  local style="$1"
  local app="$2"
  local index="$3"
  local source_icon="$CUSTOM_ICON_DIR/wechat-${style}.icns"
  local plist="$app/Contents/Info.plist"
  local icon_name="WeChat${index}Icon"

  if [[ ! -f "$source_icon" ]]; then
    yellow "$(localize "Icon wechat-${style}.icns is missing; keeping the original icon." "缺少 wechat-${style}.icns，保留原图标。")"
    return 0
  fi

  ditto "$source_icon" "$app/Contents/Resources/${icon_name}.icns" || fail "$(localize "Could not copy the icon file." "复制图标文件失败。")"

  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string ${icon_name}" "$plist" || fail "$(localize "Could not set the bundle icon." "设置副本图标失败。")"

  if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$plist")" != "$icon_name" ]]; then
    fail "$(localize "Icon setting verification failed." "图标设置校验失败。")"
  fi
}

# One-liner runs have no local wechat_icons folder. Resolve it from the script
# directory first, then from the cache, and only then fetch the archive once.
resolve_icon_dir() {
  local candidate
  local -a found
  for candidate in "$CUSTOM_ICON_DIR" "$ICON_CACHE_DIR/wechat_icons"; do
    found=("$candidate"/wechat-*.icns(N))
    if (( ${#found} > 0 )); then
      CUSTOM_ICON_DIR="$candidate"
      return 0
    fi
  done
  return 1
}

download_icons() {
  command -v curl >/dev/null 2>&1 || return 1
  command -v tar >/dev/null 2>&1 || return 1

  local staging="$ICON_CACHE_DIR/.staging.$$"
  local -a extracted
  mkdir -p "$staging" || return 1

  if ! curl -fsSL --max-time 90 "$REPO_ICON_ARCHIVE" -o "$staging/archive.tar.gz"; then
    rm -rf -- "$staging"
    return 1
  fi

  if ! tar -xzf "$staging/archive.tar.gz" -C "$staging" 2>/dev/null; then
    rm -rf -- "$staging"
    return 1
  fi

  extracted=("$staging"/*/wechat_icons(N))
  if (( ${#extracted} == 0 )); then
    rm -rf -- "$staging"
    return 1
  fi

  mkdir -p "$ICON_CACHE_DIR" || { rm -rf -- "$staging"; return 1; }
  rm -rf -- "$ICON_CACHE_DIR/wechat_icons"
  if ! mv "${extracted[1]}" "$ICON_CACHE_DIR/wechat_icons"; then
    rm -rf -- "$staging"
    return 1
  fi

  rm -rf -- "$staging"
  CUSTOM_ICON_DIR="$ICON_CACHE_DIR/wechat_icons"
  return 0
}

trap cleanup EXIT INT TERM

printf '\033c'
blue "$(localize "WeChat Multi Launch" "微信多开 / WeChat Multi Launch")"
printf '%s\n' "----------------------------------------"
printf '%s\n' "$(localize "Create WeChat2.app, WeChat3.app and more from the installed WeChat.app." "从最新版 WeChat.app 创建 WeChat2.app、WeChat3.app 等多个副本。")"
printf '%s\n' "$(localize "Each copy uses its own Bundle ID, data directory and icon." "每个副本使用独立的 Bundle ID、数据目录和图标。")"
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

printf '\n'
if ! resolve_icon_dir; then
  printf "$(localize 'Fetching icon files from the repository...\n' '正在从仓库获取图标资源…\n')"
  if download_icons; then
    green "$(localize 'Icon files ready.' '图标资源已就绪。')"
  else
    yellow "$(localize 'Could not fetch the icon files; copies will keep the original icon.' '获取图标资源失败，副本将保留原图标。')"
  fi
fi

blue "$(localize 'Copy icons' '副本图标')"
printf '%s\n' "$(localize '  a. A different icon per copy (default)' '  a. 自动：每个副本使用不同图标（默认）')"
printf '%s\n' "$(localize '  n. Keep the original WeChat icon' '  n. 保持微信原图标')"
printf '%s\n' '  1. flat      2. classic   3. minimal   4. blue'
printf '%s\n' '  5. purple    6. dark      7. gradient'
printf "$(localize 'Choose an icon option [a/n/1-7]: ' '请选择图标方案 [a/n/1-7]：')"
read -r ICON_CHOICE

case "$ICON_CHOICE" in
  ''|a|A) ICON_MODE="rotate" ;;
  n|N|0) ICON_MODE="none" ;;
  o:*)
    # Custom per-copy order, e.g. o:3,1,2 (GUI drag-and-drop). Each number is a
    # style index 1-7 assigned to WeChat2, WeChat3, ... in sequence.
    ICON_MODE="order"
    ICON_ORDER=()
    ORDER_REST="${ICON_CHOICE#o:}"
    for ORDER_PART in ${(s:,:)ORDER_REST}; do
      if [[ "$ORDER_PART" =~ '^[1-7]$' ]]; then
        ICON_ORDER+=("${ICON_STYLES[$ORDER_PART]}")
      fi
    done
    (( ${#ICON_ORDER[@]} > 0 )) || ICON_MODE="rotate"
    ;;
  [1-7]) ICON_MODE="style"; ICON_STYLE="${ICON_STYLES[$ICON_CHOICE]}" ;;
  *)
    yellow "$(localize "Unrecognised choice; using a different icon per copy." "无法识别该选项，改为每个副本使用不同图标。")"
    ICON_MODE="rotate"
    ;;
esac

if [[ "$ICON_MODE" != "none" && ! -d "$CUSTOM_ICON_DIR" ]]; then
  yellow "$(localize "The wechat_icons folder is missing; keeping the original icon." "缺少 wechat_icons 文件夹，保留原图标。")"
  ICON_MODE="none"
fi

printf "$(localize '\nThe following copies will be created or rebuilt:\n' '\n将创建或重建以下副本：\n')"
for (( CLONE_INDEX = 2; CLONE_INDEX <= TOTAL_INSTANCES; CLONE_INDEX++ )); do
  printf '  /Applications/WeChat%s.app\n' "$CLONE_INDEX"
  printf '  %s/Library/Containers/com.tencent.xinWeChat%s\n' "$HOME" "$CLONE_INDEX"
  if ICON_PREVIEW=$(icon_style_for_index "$CLONE_INDEX"); then
    printf "$(localize '    icon: %s\n' '    图标：%s\n')" "$ICON_PREVIEW"
  fi
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
blue "$(localize "[1/7] Creating a temporary build directory..." "[1/7] 创建临时构建目录…")"
BUILD_DIR=$(mktemp -d /Applications/.wechat-multi-build.XXXXXX)
BUILD_APP="$BUILD_DIR/WeChat${CLONE_INDEX}.app"

blue "$(localize "[2/7] Copying the installed WeChat app (may take a few minutes)..." "[2/7] 复制最新版微信（约需数秒至数分钟）…")"
ditto "$SOURCE_APP" "$BUILD_APP" || fail "$(localize "Could not copy WeChat." "复制微信失败。")"

blue "$(localize "[3/7] Changing the copy's Bundle ID..." "[3/7] 修改副本 Bundle ID…")"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $CLONE_BUNDLE_ID" "$BUILD_APP/Contents/Info.plist" || fail "$(localize "Could not change the Bundle ID." "修改 Bundle ID 失败。")"

ACTUAL_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUILD_APP/Contents/Info.plist")
if [[ "$ACTUAL_BUNDLE_ID" != "$CLONE_BUNDLE_ID" ]]; then
  fail "$(localize "Bundle ID verification failed." "Bundle ID 校验失败。")"
fi

ICON_APPLIED=""
if ICON_APPLIED=$(icon_style_for_index "$CLONE_INDEX"); then
  blue "$(localize "[4/7] Applying the ${ICON_APPLIED} icon..." "[4/7] 应用 ${ICON_APPLIED} 图标…")"
  apply_clone_icon "$ICON_APPLIED" "$BUILD_APP" "$CLONE_INDEX"
else
  blue "$(localize "[4/7] Keeping the original WeChat icon." "[4/7] 保留微信原图标…")"
fi

blue "$(localize "[5/7] Re-signing the copy and its nested components..." "[5/7] 重新签署副本及其内部组件…")"
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

blue "$(localize "[6/7] Verifying the new copy..." "[6/7] 严格验证新副本…")"
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

# Same Bundle ID as the replaced copy, so drop the cached icon for this path.
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$CLONE_APP" >/dev/null 2>&1 || true
fi

BUILT_CLONES+=("$CLONE_APP")
if [[ -n "$BACKUP_APP" ]]; then
  BACKUP_APPS+=("$BACKUP_APP")
fi
cleanup
BUILD_DIR=""
done

blue "$(localize "[7/7] Starting and checking all WeChat instances..." "[7/7] 启动并检查所有微信实例…")"
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
blue "$(localize "Icons" "图标")"
if [[ "$ICON_MODE" == "none" ]]; then
  printf '%s\n' "$(localize "Copies keep the original WeChat icon." "副本保留了微信原图标。")"
else
  for (( CLONE_INDEX = 2; CLONE_INDEX <= TOTAL_INSTANCES; CLONE_INDEX++ )); do
    if ICON_APPLIED=$(icon_style_for_index "$CLONE_INDEX"); then
      printf "$(localize 'WeChat%s.app icon: %s\n' 'WeChat%s.app 图标：%s\n')" "$CLONE_INDEX" "$ICON_APPLIED"
    fi
  done
fi
printf "$(localize 'Icon folder: %s\n' '图标文件夹：%s\n')" "$CUSTOM_ICON_DIR"
printf '%s\n' "$(localize "Change one copy later: right-click WeChatN.app in Applications, choose Get Info, then drag any icon from the folder onto the small icon at the top left." "之后单独换图标：在“应用程序”中右键点击 WeChatN.app，选择“显示简介”，把文件夹中的任意图标拖到窗口左上角的小图标上。")"
printf '%s\n' "$(localize "If Finder or the Dock still shows an old icon, run: killall Dock" "如果访达或程序坞仍显示旧图标，可在终端执行：killall Dock")"
pause_before_close
