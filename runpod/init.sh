#!/bin/bash
set -e

# スクリプト自身の絶対パスと、プロジェクトのルートディレクトリを自動取得
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

echo "📂 プロジェクトルートを認識しました: $PROJECT_DIR"

echo "🔄 [1/5] システムパッケージの更新とインストール..."
apt update && apt install -y tmux vim nvtop ffmpeg build-essential curl wget git

# runpodctl (自動停止CLI) のインストール
if ! command -v runpodctl &> /dev/null; then
    echo "🛑 Installing runpodctl..."
    curl -sSL https://runpod.io/install/runpodctl | sh
    mv runpodctl /usr/bin/
fi

echo "📦 [2/5] uv のインストールと環境設定..."
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.local/bin/env
    echo 'source $HOME/.local/bin/env' >> ~/.bashrc
fi

echo "🔑 [3/5] GitHub SSH 認証とユーザー設定..."
mkdir -p ~/.ssh
# SSH鍵はGit管理外の RunPodルート(/workspace) にある想定
if [ -f "/workspace/.ssh/id_ed25519" ]; then
    cp /workspace/.ssh/id_ed25519 ~/.ssh/id_ed25519
    chmod 600 ~/.ssh/id_ed25519
    ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null
    echo "✅ SSH鍵を設定しました。"
else
    echo "⚠️ Warning: /workspace/.ssh/id_ed25519 が見つかりません。"
fi

# Gitのユーザー情報（コミット用）を自動設定
git config --global user.name "Kan Kusakabe"
git config --global user.email "kan86yeaoh@gmail.com"
echo "✅ Gitのユーザー情報を設定しました。"

echo "🔐 [4/5] RunPod Secrets からの認証逆算とログイン..."
# SSH経由等で変数が消えている場合、コンテナ大元(PID 1)から強制抽出
if [ -z "$KEY_WANDB" ]; then
    export KEY_WANDB=$(cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | grep '^KEY_WANDB=' | cut -d= -f2-)
    export KEY_HF=$(cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | grep '^KEY_HF=' | cut -d= -f2-)
    export KEY_GITHUB=$(cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | grep '^KEY_GITHUB=' | cut -d= -f2-)
    export RUNPOD_POD_ID=$(cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | grep '^RUNPOD_POD_ID=' | cut -d= -f2-)
fi

{
    echo "export HF_TOKEN=\"$KEY_HF\""
    echo "export WANDB_API_KEY=\"$KEY_WANDB\""
    echo "export GITHUB_TOKEN=\"$KEY_GITHUB\""
    echo "export RUNPOD_POD_ID=\"$RUNPOD_POD_ID\""
} >> ~/.bashrc

if [ -n "$KEY_WANDB" ]; then
    pip install -q wandb || true
    if command -v wandb &> /dev/null; then
        wandb login "$KEY_WANDB"
        echo "✅ WandB ログインに成功しました。"
    fi
else
    echo "⚠️ Warning: KEY_WANDB が取得できませんでした。"
fi

echo "🔄 [5/5] プロジェクトの依存関係同期 (uv sync)..."
if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    source $HOME/.local/bin/env
    uv sync
    echo "✅ uv sync が完了しました。"
else
    echo "❌ Error: プロジェクトディレクトリ ($PROJECT_DIR) が見つかりません。"
fi

echo "🎉 全ての初期化が完了しました！"
