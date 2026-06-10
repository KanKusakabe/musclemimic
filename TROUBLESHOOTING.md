# MuscleMimic: Environment Setup & Troubleshooting Guide

このドキュメントは、ローカル環境やクラウドGPU（RunPodなど）で musclemimic の全身シミュレーション（fullbody）を実行するための最適な設定と、既知のエラーに対するトラブルシューティングをまとめたものです。

## 1. 実行時の鉄則（Hydraの上書き回避）

`musclemimic` はデフォルトでA100等のハイエンドGPUを想定した設定になっています。自身の環境に合わせて設定を変える場合、設定ファイルを直接書き換えるのではなく、実行時のコマンドライン引数（`++`）で強制的にパラメータを上書きする運用を強く推奨します（Hydraの階層構造による意図しない設定上書きを防ぐため）。

推奨されるベースコマンド:

```bash
uv run fullbody/experiment.py --config-name=conf_fullbody_demo ++experiment.env_params.mjx_backend=mjx ++experiment.env_params.num_envs=1024 ++experiment.ppo_config.num_minibatches=128 ++experiment.ppo_config.num_steps=10
```

## 2. VRAM別パラメータ設定ガイド（クラウドGPU / ローカル環境）

JAX/MJXのメモリ消費量と学習速度は、主に `num_envs`（並列環境数）と、PPOの `num_minibatches`（分割数）に依存します。利用するGPUの VRAM（ビデオメモリ）容量 に合わせて、引数を最適化してください。

### 💡 パラメータ調整の基本法則

*   **num_envs**: 大きくするほど実時間（Wall-clock time）の学習効率は上がりますが、VRAMを大量に消費します。
*   **num_minibatches**: 1回の学習ステップで処理するデータの分割数です。OOM（メモリ不足）が起きる場合は、この数値を **増やす（例: 32 → 64 → 128）** ことで、1回あたりのVRAM消費ピークを抑えることができます。

### 🖥️ GPUクラス別 推奨設定テーブル

| GPUクラス (VRAM) | 代表的なGPUモデル | 推奨 num_envs | 推奨 num_minibatches | 推奨実行コマンド (引数部分) |
| :--- | :--- | :--- | :--- | :--- |
| **12GB - 16GB**<br>(最小要件) | RTX 4070<br>RTX A4000<br>T4 | 1024 〜 2048 | 128 | `++experiment.env_params.num_envs=1024 ++experiment.ppo_config.num_minibatches=128` |
| **24GB**<br>(推奨/ミドル) | RTX 3090 / 4090<br>RTX A5000<br>L4 | 4096 | 128 | `++experiment.env_params.num_envs=4096 ++experiment.ppo_config.num_minibatches=128` |
| **40GB - 48GB**<br>(ハイエンド) | RTX A6000<br>A40 | 8192<br>(デフォルト) | 128<br>(デフォルト設定のままで動作可能) | `++experiment.env_params.num_envs=8192` |
| **80GB**<br>(エンタープライズ) | A100 (80GB)<br>H100 | 16384 | 64 〜 128 | `++experiment.env_params.num_envs=16384 ++experiment.ppo_config.num_minibatches=128` |

> **Note**: 上記の数値は目安です。もし特定のGPUで `RESOURCE_EXHAUSTED` (OOM) が発生した場合は、一段階下のVRAMクラスの設定を試すか、`num_minibatches` を倍に増やして調整してください。マルチGPU環境の場合はトータルのVRAMが増加するため、さらに大きな `num_envs` を設定し、圧倒的な速度で学習を回すことが可能になります。

## 3. トラブルシューティング

### 💥 エラー1: Warpバックエンドによるセグメンテーション違反 (Exit 139)

*   **症状**: `using warp backend...` というログの直後に `[ble: exit 139]` (Segmentation Fault) でプロセスが強制終了する。
*   **原因**: MuJoCo MJXのWarpバックエンドが、全身筋骨格モデルの複雑な自己衝突（Self-collision）の接触判定バッファ上限を超過し、メモリアクセス違反を起こしているため。
*   **解決策**: コマンドライン引数に `++experiment.env_params.mjx_backend=mjx` を付与し、物理演算のバックエンドをJAX標準のMJXに切り替える。

### 💥 エラー2: JAX XLAコンパイル時のOOM (Out of Memory)

*   **症状**: 初回の巨大なコンパイル処理の直後、`RESOURCE_EXHAUSTED: Out of memory while trying to allocate X.XX GiB` が表示されて学習が開始されない。
*   **原因**: デフォルト設定（`num_envs: 8192` や、デモ用ファイルで上書きされる `2048` など）が、実行環境のVRAM許容量を超過しているため。
*   **解決策**: 前述の「VRAM別パラメータ設定ガイド」を参照し、ご自身のVRAMに合わせた安全な設定へスケールダウンする。

### 💥 エラー3: Orbax（チェックポイント管理）初期化直後のフリーズ（デッドロック）

*   **症状**: `CheckpointManager created, root_directory=...` というログの後、GPU使用率が上がらず10分以上プロセスが完全に停止する。
*   **原因**: 過去のJAXコンパイルキャッシュの破損、古いチェックポイントファイルとの競合、またはファイルシステムへのアクセス時のデッドロック。
*   **解決策**: プロセスを強制終了（Ctrl + C）し、以下のコマンドで各種キャッシュと出力ファイルを完全に消去してから再実行する。

```bash
# キャッシュと過去のチェックポイントを完全に削除
rm -rf ~/.musclemimic/.jax_cache/*
rm -rf ~/Project/musclemimic/checkpoints/*
rm -rf ~/Project/musclemimic/wandb/*
rm -rf ~/Project/musclemimic/outputs/*
```

