#!/bin/bash

# Docker 映像建置腳本
# 用於建置包含 React + Vite、Firebase、WordPress、PHP 和 Claude Code 的 IgniStack 開發環境

set -e  # 遇到錯誤時停止執行

echo "開始建置 IgniStack Docker 映像..."

# 設定變數
IMAGE_NAME="ignistack-dev-sandbox"
DOCKERFILE_PATH="./docker/Dockerfile"

# 檢查 Dockerfile 是否存在
if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "錯誤: 找不到 Dockerfile 在 $DOCKERFILE_PATH"
    exit 1
fi

# 檢查 Docker 是否正在運行
if ! docker info > /dev/null 2>&1; then
    echo "錯誤: Docker 未運行，請先啟動 Docker"
    exit 1
fi

# 建置 Docker 映像
echo "正在建置映像: $IMAGE_NAME"
docker build -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" .

# 檢查建置是否成功
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Docker 映像建置成功!"
    echo "映像名稱: $IMAGE_NAME"
    echo ""
    echo "📋 技術棧:"
    echo "  - React + Vite 前端開發"
    echo "  - Firebase 後端服務"
    echo "  - WordPress CMS (PHP 8.4)"
    echo "  - sync-fire-wp 同步插件"
    echo "  - Claude Code AI 開發助手"
    echo "  - CoSpec AI Markdown 編輯器"
    echo "  - WebTTY 共享終端"
    echo ""
    echo "🚀 使用方式:"
    echo "  互動式執行: docker run -it --rm -p 80:80 -p 9681:9681 -p 9280:9280 -p 5000:5000 -p 5001:5001 -v \$(pwd):/home/flexy/workspace $IMAGE_NAME"
    echo "  使用 WebTTY 模式: docker run -it --rm -p 80:80 -p 9681:9681 -p 9280:9280 -p 5000:5000 -p 5001:5001 -e ENABLE_WEBTTY=true -v \$(pwd):/home/flexy/workspace $IMAGE_NAME"
    echo ""
    echo "🌐 重要端口:"
    echo "  80: WordPress CMS"
    echo "  9681: WebTTY (ttyd) - 共享終端"
    echo "  9280: CoSpec AI Markdown 編輯器 (前端)"
    echo "  5000-5001: Firebase Emulators"
    echo ""
    echo "🔧 環境變數 (可選):"
    echo "  ANTHROPIC_AUTH_TOKEN: Claude Code API 權杖"
    echo "  FIREBASE_TOKEN: Firebase CLI 權杖"
    echo "  WORDPRESS_DB_HOST: WordPress 數據庫主機"
    echo "  WORDPRESS_DB_USER: WordPress 數據庫用戶"
    echo "  WORDPRESS_DB_PASS: WordPress 數據庫密碼"
    echo "  WORDPRESS_DB_NAME: WordPress 數據庫名稱"
    echo "  ENABLE_WEBTTY: 啟用 WebTTY 模式 (true/false)"
    echo ""
    echo "💡 工作流程:"
    echo "  1. 啟動容器後，訪問 http://localhost 進行 WordPress 安裝"
    echo "  2. 安裝並激活 sync-fire-wp 插件以同步 WordPress 到 Firestore"
    echo "  3. 使用 Firebase CLI 進行前端/後端開發 (npm run dev, firebase emulators:start)"
    echo "  4. 使用 CoSpec AI 編輯器進行文檔編寫 (訪問 http://localhost:9280)"
    echo "  5. 使用 WebTTY 共享終端進行協作 (訪問 http://localhost:9681)"
else
    echo ""
    echo "❌ Docker 映像建置失敗!"
    exit 1
fi