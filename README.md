# custom-ci-tool

一個**不依賴現成 CI 伺服器**（如 Jenkins/GitHub Actions）的輕量級 CI 腳本框架。
特色是以 **Bash** 撰寫、**模組化元件（components）** + **專案/環境目錄（projects）** 的方式組裝 pipeline，並內建 **建置歷史/日誌管理**、**指令自動補全**，適合在受限環境（只能用 Podman 建鏡像、用 `kubectl` 部署，但不能在叢集內架 CI）的場景快速落地。

---

## 功能總覽

* **可組裝的 Pipeline 元件**：以 `components/`（例如 `git-clone.sh`、`build-image.sh`、`push-image.sh`、）拼裝各專案的 `pipeline.sh`。
* **專案/環境分離**：`projects/<project>/<env>/` 存放該專案環境的 `build.conf` 與 `pipeline.sh`。
* **建置紀錄與日誌**：在 `builds/` 下維護每次建置的 log 與 history。
* **Bash 自動補全**：提供 `ci-tool` 的 tab-completion（專案/環境/歷史 build-id 智能補全）。
* **簡單、可移植**：純 Shell，便於在任何有 Bash 的環境落地；可配合 Docker/Podman、`kubectl`、Slack Webhook 等外部工具。

---

## 目錄結構

```text
/custom-ci-tool/
├── common/                     # 共用函式（log、錯誤處理、diff 等）
├── components/                 # 可重用的 pipeline 元件
│   ├── git-clone.sh
│   ├── build-image.sh
│   └── push-image.sh
├── projects/
│   └── <project>/
│       └── <env>/              # 例如 dev / uat / prod
│           ├── build.conf      # 該專案/環境的設定
│           └── pipeline.sh     # 用 components 組裝而成的流程
├── builds/
│   ├── logs/<project>/<env>/   # 各次建置的 log
│   └── history/<project>/<env>/history.csv  # 建置歷史（CSV）
├── build.sh                    # 入口腳本（或由 ci-tool 轉呼叫）
├── ci-tool                     # 主 CLI（建議加入 PATH）
├── ci-tool-completion.bash     # Bash 補全
├── logs.sh                     # 讀取/篩選 log 的輔助腳本
├── setup-ci-tool.sh            # 一鍵安裝（拷貝到 ~/.local/bin 或連結）
└── status.sh                   # 檢視建置狀態/歷史（彙整 CSV）
```

---

## 安裝

### 方式：使用安裝腳本

```bash
cd custom-ci-tool
./setup-ci-tool.sh    # 將 ci-tool/補全等檔案安裝到標準位置（依腳本邏輯）
source ~/.bashrc.     # 立即啟用設定
```
---

## 快速開始

以下示範如何以 **demo 專案** 的 `dev` 環境執行建置與查看狀態/日誌（你的 repo 已內含 `projects/demo-project/dev` 範例）。

1. 建立/調整專案設定
   在 `projects/<project>/<env>/build.conf` 中設定必要變數（例如：`GIT_REPO`、`GIT_BRANCH`、鏡像名稱/Registry、部署目標…）。
   在同資料夾的 `pipeline.sh` 中，使用 `components/` 元件組裝流程，例如：

```bash
#!/bin/bash
set -euo pipefail

components/git-clone.sh
components/build-image.sh
components/push-image.sh
```

2. 執行建置

```bash
# 方式一：使用主 CLI
ci-tool build <project> <env>

# 方式二：直接呼叫 build.sh
./build.sh <project> <env>
```

3. 查看狀態與歷史

```bash
# 顯示近期建置狀態（預設顯示最近 N 筆，支援以專案/環境過濾）
ci-tool status
ci-tool status <project> <env>
ci-tool status -n 10 <project>

# 僅看某次建置的 log
ci-tool logs <project> <env> <build_id>

# 也可直接開啟儲存在 builds/logs/<project>/<env>/ 下的檔案
```

---

## 指令與補全

* `ci-tool build <project> <env> [--<args>...]`：執行對應專案/環境的 `pipeline.sh`
* `ci-tool status [-n <count>] [<project> [<env> [<build_id>]]]`：彙整/顯示建置歷史
* `ci-tool logs [<project> [<env> [<build_id>]]]`：檢視建置日誌（支援條件過濾）
