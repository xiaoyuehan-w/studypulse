#!/usr/bin/env bash
# StudyPulse 出包脚本 —— 版本号单一事实源是 pubspec.yaml
# 用法：bash tool/release.sh "备注"     例：bash tool/release.sh 首页骨架
# 做的事：①读 pubspec 版本 ②写 lib/app_version.dart（并校验一致）③构建 ④按版本命名复制到 04-交付物
set -euo pipefail

NOTE="${1:-dev}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VER_LINE="$(grep -m1 '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//')"
VER_NAME="${VER_LINE%%+*}"
VER_CODE="${VER_LINE##*+}"

echo "▶ 版本：$VER_NAME (build $VER_CODE)  备注：$NOTE"

# 写入版本常量（App 内显示用，避免再次出现"设置页写死 1.0.0"）
cat > lib/app_version.dart <<EOF
/// 版本常量 —— **由构建脚本 tool/release.sh 自动写入，请勿手改**。
/// 单一事实源是 pubspec.yaml 的 version 字段；脚本会把两者对齐并校验。
library;

const String appVersion = '$VER_NAME';
const String appBuild = '$VER_CODE';
const String appVersionFull = '\$appVersion+\$appBuild';
EOF
echo "▶ 已写入 lib/app_version.dart"

# 校验一致性（防止版本漂移）
if ! grep -q "appVersion = '$VER_NAME'" lib/app_version.dart; then
  echo "✗ 版本写入不一致，终止"; exit 1
fi

echo "▶ flutter analyze"
flutter analyze

echo "▶ flutter test"
flutter test

echo "▶ flutter build apk --release"
flutter build apk --release

APK="build/app/outputs/flutter-apk/app-release.apk"
OUT_NAME="StudyPulse-${VER_NAME}+${VER_CODE}-${NOTE}.apk"

# 交付目录：优先 <项目>/../04-交付物；在 subst 盘（如 Z:）下相对路径会失效，故回退到工作区绝对路径
DEST="${STP_DELIVER_DIR:-}"
if [ -z "$DEST" ]; then
  if [ -d "$ROOT/../04-交付物" ]; then
    DEST="$ROOT/../04-交付物"
  elif [ -d "/e/wpx ai办公区域/04-交付物" ]; then
    DEST="/e/wpx ai办公区域/04-交付物"
  else
    DEST="$ROOT/dist"; mkdir -p "$DEST"
  fi
fi
cp -f "$APK" "$DEST/$OUT_NAME"
echo "▶ 已输出：04-交付物/$OUT_NAME"
echo "✓ 完成。装机后请在「设置 → 关于」确认显示 v$VER_NAME+$VER_CODE"
