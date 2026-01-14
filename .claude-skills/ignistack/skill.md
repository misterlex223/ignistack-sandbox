# IgniStack Integration Skill

## Overview

IgniStack Sandbox 是一個基於 Docker 的開發環境，提供 WordPress (SQLite) + Firebase + React 的完整技術棧。

**核心特色**：
- WordPress 使用 SQLite 資料庫（無需 MySQL）
- 持久化實例管理，支援多個隔離環境
- AI 整合（Claude/OpenAI）內容生成
- Firebase 即時同步
- Schema 驅動開發
- **無需建置映像**，直接從 GitHub Container Registry 拉取

## Prerequisites

在使用此 Skill 之前，請確保：

1. **Docker 已安裝並運行**
   ```bash
   docker --version
   docker ps
   ```

2. **Docker 登入 GitHub Container Registry**（如果映像是私有的）
   ```bash
   docker login ghcr.io
   ```

3. **可選：設定 API Tokens**
   - `ANTHROPIC_AUTH_TOKEN`：Claude Code CLI
   - `FIREBASE_TOKEN`：Firebase CLI
   - `OPENAI_API_KEY`：IgnisAI 插件

## Quick Start

最簡單的方式開始使用：

```
/ignistack init my-first-project
```

這會：
1. 自動從 `ghcr.io/misterlex223/ignistack-sandbox:latest` 拉取映像
2. 建立並啟動一個完整的開發環境
3. 配置 WordPress、Firebase、WebTTY 等服務

## Available Commands

### Environment Setup

#### `/ignistack init`
初始化專案並建立 IgniStack 開發環境。

**用法**：
```
/ignistack init [project-name] [options]
```

**選項**：
- `--port <port>`：WordPress 連接埠（預設：8080）
- `--mount <path>`：掛載本地專案目錄到容器
- `--firebase-port <port>`：Firebase 連接埠（預設：5000）
- `--firebase-ui-port <port>`：Firebase UI 連接埠（預設：4000）
- `--ttyd-port <port>`：WebTTY 連接埠（預設：9681）
- `--cospec-port <port>`：CoSpec AI 連接埠（預設：9280）
- `--image <tag>`：指定映像版本（預設：ghcr.io/misterlex223/ignistack-sandbox:latest）

**範例**：
```
# 基本使用
/ignistack init my-app

# 自訂連接埠並掛載專案
/ignistack init my-app --port 8080 --mount /path/to/my-app

# 使用特定映像版本
/ignistack init my-app --image ghcr.io/misterlex223/ignistack-sandbox:v1.2.0
```

#### `/ignistack create-instance`
建立獨立的持久化 WordPress 實例。

**用法**：
```
/ignistack create-instance <name> [options]
```

**選項**：
- `--port <port>`：WordPress 連接埠
- `--ttyd-port <port>`：WebTTY 連接埠
- `--cospec-port <port>`：CoSpec AI 連接埠
- `--firebase-port <port>`：Firebase 連接埠

**範例**：
```
/ignistack create-instance production --port 8081
```

### Instance Management

#### `/ignistack list`
列出所有 WordPress 實例及其狀態。

**輸出範例**：
```
AVAILABLE INSTANCES:
Name: my-app
Status: Running
WordPress: http://localhost:8080
WebTTY: http://localhost:9681
Firebase: http://localhost:5000
Container: ignistack-wp-my-app
```

#### `/ignistack start <name>`
啟動指定的 WordPress 實例。

#### `/ignistack stop <name>`
停止指定的 WordPress 實例。

#### `/ignistack restart <name>`
重啟指定的 WordPress 實例。

#### `/ignistack info <name>`
顯示實例的詳細資訊（連接埠、路徑、狀態、容器 ID）。

#### `/ignistack remove <name>`
永久刪除實例（⚠️ 會刪除所有資料，包括 WordPress 資料庫和檔案）。

### Development Workflow

#### `/ignistack wp <command>`
在 WordPress 實例中執行 WP-CLI 命令。

**範例**：
```
/ignistack wp plugin list
/ignistack wp core version
/ignistack wp post list
/ignistack wp option get siteurl
```

#### `/ignistack schema <action>`
管理 Schema 定義和 TypeScript 類型匯出。

**動作**：
- `list`：列出所有 schemas
- `validate <post-type>`：驗證 schema 語法
- `register <post-type>`：在 WordPress 中註冊 schema
- `export <post-type>`：匯出 TypeScript 類型
- `export-all`：匯出所有 schemas

**範例**：
```
/ignistack schema export-all --output=/path/to/types
/ignistack schema validate product
```

#### `/ignistack ai <action>`
執行 AI 相關操作（需要 OPENAI_API_KEY）。

**動作**：
- `generate-alt-text`：為所有圖片生成 alt text
- `generate-content <post-id> <field>`：生成內容
- `generate-form <description>`：從描述生成 ACF 欄位群組

**範例**：
```
/ignistack ai generate-form "Product fields: name, price, SKU"
/ignistack ai generate-alt-text
```

### Troubleshooting

#### `/ignistack logs <container-name>`
查看容器日誌。

**選項**：
- `--follow`：持續監控日誌（類似 tail -f）
- `--tail <lines>`：顯示最後 N 行

#### `/ignistack shell <container-name>`
進入容器的 bash shell。

**範例**：
```
/ignistack shell ignistack-wp-my-app
```

#### `/ignistack doctor`
執行環境檢查診斷，檢查：
- Docker 安裝和運行狀態
- 映像是否存在
- 連接埠是否被佔用
- 實例目錄權限

## Integration with Existing Projects

### 方法一：使用 Skill 命令

1. **在現有專案目錄中**：
   ```
   /ignistack init existing-project --mount $(pwd)
   ```

2. **專案檔案會自動掛載到容器的** `/home/flexy/workspace`

3. **開始開發**：
   - 在容器中修改檔案會即時反映到本地
   - 本地檔案變更也會在容器中可見

### 方法二：使用配置檔案

在專案根目錄建立 `.ignistack.yml`：

```yaml
project_name: my-app
port: 8080
mount: ./src
firebase:
  port: 5000
  ui_port: 4000
webtty:
  port: 9681
cospec:
  port: 9280
environment:
  OPENAI_API_KEY: ${OPENAI_API_KEY}
  FIREBASE_TOKEN: ${FIREBASE_TOKEN}
```

然後執行：
```
/ignistack init --config .ignistack.yml
```

## Service URLs

啟動實例後，可以存取以下服務：

| 服務 | URL | 預設連接埠 |
|------|-----|-----------|
| WordPress Admin | http://localhost:8080/wp-admin | 8080 |
| WordPress Site | http://localhost:8080 | 8080 |
| WebTTY Terminal | http://localhost:9681 | 9681 |
| Firebase Firestore | http://localhost:5000 | 5000 |
| Firebase UI | http://localhost:4000 | 4000 |
| CoSpec AI Editor | http://localhost:9280 | 9280 |

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│          Host Machine                           │
│  ┌──────────────────────────────────────────┐  │
│  │  ~/.ignistack-instances/                 │  │
│  │    ├── instance-1/                       │  │
│  │    │    ├── wp-content/                  │  │
│  │    │    ├── wp-config.php                │  │
│  │    │    └── .instance-info               │  │
│  │    └── instance-2/                       │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │  Docker Container                        │  │
│  │  Image: ghcr.io/misterlex223/...:latest  │  │
│  │    ├── WordPress (SQLite)                │  │
│  │    │    └── wp-content/database/.ht.sqlite│
│  │    ├── Firebase Emulator                 │  │
│  │    ├── Node.js (Frontend)                │  │
│  │    ├── WebTTY (Terminal)                 │  │
│  │    ├── CoSpec AI (Editor)                │  │
│  │    └── IgnisAI Plugin                    │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## Docker Image

映像位置：`ghcr.io/misterlex223/ignistack-sandbox:latest`

### 映像內容

- **Base**: Ubuntu/Debian with PHP 8.4
- **WordPress**: Latest stable version
- **SQLite**: WordPress SQLite Integration
- **Firebase CLI**: Latest version
- **Node.js**: LTS version
- **WP-CLI**: Latest version
- **Pre-installed Plugins**:
  - ACF Pro
  - ignis-schema-wp
  - ignis-ai
  - sync-fire-wp

### 更新映像

```bash
docker pull ghcr.io/misterlex223/ignistack-sandbox:latest
```

## Common Issues

### WordPress 顯示安裝畫面
**原因**：持久化卷未正確掛載
**解決**：
```
/ignistack doctor
docker inspect <container> | grep wordpress-persistent
```

### 連接埠衝突
**原因**：連接埠已被其他容器使用
**解決**：使用不同的連接埠
```
/ignistack init my-app --port 8081
```

### 映像拉取失敗
**原因**：網路問題或未登入 GitHub Container Registry
**解決**：
```bash
docker login ghcr.io
docker pull ghcr.io/misterlex223/ignistack-sandbox:latest
```

### 容器無法啟動
**檢查日誌**：
```
/ignistack logs <container-name>
```

## Best Practices

1. **命名慣例**：使用有意義的實例名稱（如 `dev`、`staging`、`production`）
2. **連接埠規劃**：記錄每個實例使用的連接埠避免衝突
3. **定期備份**：重要實例應定期備份 `~/.ignistack-instances/<name>/` 目錄
4. **資源清理**：不使用的實例應停止以釋放系統資源
5. **映像更新**：定期拉取最新映像以獲得功能更新和安全性修補

## Advanced Usage

### 自訂環境變數

```bash
/ignistack init my-app \
  -e WP_DEBUG=true \
  -e WP_DEBUG_LOG=true \
  -e OPENAI_API_KEY=sk-xxx
```

### 多實例開發

```bash
# 建立開發環境
/ignistack create-instance dev --port 8080

# 建立測試環境
/ignistack create-instance test --port 8081

# 建立預產環境
/ignistack create-instance staging --port 8082
```

### 與 CI/CD 整合

```yaml
# .github/workflows/test.yml
- name: Start IgniStack
  run: |
    docker run -d \
      -p 8080:80 \
      -e WP_INSTANCE_NAME=ci-test \
      ghcr.io/misterlex223/ignistack-sandbox:latest

- name: Run tests
  run: |
    docker exec ignistack-wp-ci-test wp plugin test --allow-root
```

## Further Reading

- [完整文件](https://github.com/misterlex223/ignistack-sandbox)
- [WordPress Instances Guide](https://github.com/misterlex223/ignistack-sandbox/blob/main/docs/WORDPRESS-INSTANCES.md)
- [SQLite Integration Details](https://github.com/misterlex223/ignistack-sandbox/blob/main/docs/SQLITE-INTEGRATION.md)
- [Schema System Integration](https://github.com/misterlex223/ignistack-sandbox/blob/main/docs/SCHEMA-SYSTEM-INTEGRATION.md)
- [AI Integration Features](https://github.com/misterlex223/ignistack-sandbox/blob/main/docs/AI-INTEGRATION.md)
