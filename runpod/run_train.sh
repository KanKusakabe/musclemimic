#!/bin/bash

# スクリプト自身の絶対パスと、各種ディレクトリを自動取得
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
STOP_SCRIPT="${SCRIPT_DIR}/stop.sh"

# 1. プロジェクトルートへ移動（どこから実行しても必ずここに飛ぶ）
cd "$PROJECT_DIR" || exit 1
echo "📂 プロジェクトディレクトリに移動しました: $(pwd)"

# 2. 実験の実行
echo "▶️ Running experiment..."
source $HOME/.local/bin/env
uv run --no-sync fullbody/experiment.py --config-name=conf_fullbody_demo \
  ++experiment.env_params.mjx_backend=mjx \
  ++experiment.env_params.num_envs=8192 \
  ++experiment.ppo_config.num_minibatches=128 \
  ++experiment.ppo_config.total_timesteps=80000000

EXIT_CODE=$?

# 3. Git 自動コミット＆Push
echo "📦 Committing and pushing results to Git..."
git add .
CURRENT_DATE=$(date "+%Y-%m-%d %H:%M:%S")
git commit -m "Auto-commit: Training run finished at $CURRENT_DATE (Exit code: $EXIT_CODE)"

if git push; then
    echo "✅ Git push successful."
else
    echo "❌ Error: Git push failed."
fi

# 4. 自動停止スクリプトの呼び出し
echo "🛑 Proceeding to auto-stop the Pod..."
if [ -f "$STOP_SCRIPT" ]; then
    bash "$STOP_SCRIPT"
else
    echo "❌ Error: stop.sh not found at $STOP_SCRIPT"
fi
