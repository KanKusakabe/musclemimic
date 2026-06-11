#!/bin/bash

echo "🛑 ポッドの自動停止処理を開始します..."

# 環境変数が消えている場合に備えて大元から取得
if [ -z "$RUNPOD_POD_ID" ]; then
    export RUNPOD_POD_ID=$(cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | grep '^RUNPOD_POD_ID=' | cut -d= -f2-)
fi

if [ -n "$RUNPOD_POD_ID" ]; then
    echo "⏳ Pod ID: $RUNPOD_POD_ID を停止（Stop）します..."
    
    if command -v runpodctl &> /dev/null; then
        runpodctl pod stop "$RUNPOD_POD_ID"
    else
        echo "❌ Error: runpodctl コマンドが見つかりません。手動で停止してください。"
    fi
else
    echo "❌ Error: RUNPOD_POD_ID が取得できません。手動で停止してください。"
    exit 1
fi
