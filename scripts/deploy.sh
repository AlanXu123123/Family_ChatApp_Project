#!/bin/bash
# 一键部署脚本：构建 Web → 部署到 Firebase Hosting → 提交并推送到 GitHub
# 用法: ./scripts/deploy.sh "提交信息"
#       ./scripts/deploy.sh                  # 使用默认提交信息

set -e

cd "$(dirname "$0")/.."

COMMIT_MSG="${1:-update: routine deployment $(date +'%Y-%m-%d %H:%M')}"

echo "==> [1/4] Flutter Web 构建..."
flutter build web --release

echo "==> [2/4] 部署到 Firebase Hosting..."
firebase deploy --only hosting --project mychat-1a8ad

echo "==> [3/4] 提交本次变更..."
if [[ -n "$(git status --porcelain)" ]]; then
  git add .
  git commit -m "$COMMIT_MSG"
  echo "==> [4/4] 推送到 GitHub..."
  git push origin main
else
  echo "==> 没有需要提交的变更，跳过 git push。"
fi

echo ""
echo "✅ 部署完成！"
echo "🌐 Web: https://familychat-private.web.app"
echo "📦 GitHub: https://github.com/AlanXu123123/Family_ChatApp_Project"
