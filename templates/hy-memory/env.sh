# Hy Memory 2.0 运行配置（**无密钥**，可直接复制到 ~/hy-memory-spike/env.sh 后 source）
#
# 布局：本机实测配置，2026-10-16 跑通。数据、模型、记忆全在本机，
#       只有「事实抽取用的 LLM」走 MiniMax 官方 API。
#
# 用法：
#   mkdir -p ~/hy-memory-spike && cp env.sh ~/hy-memory-spike/env.sh
#   # 密钥【手动】：把 MiniMax 官方 API key 写入 ~/hy-memory-spike/minimax.key
#   chmod 600 ~/hy-memory-spike/minimax.key
#   source ~/hy-memory-spike/env.sh
#
# ⚠️ 换机密钥不要从旧机拷 —— 见 intent/secrets.md 的 hy-memory 一节。

# 数据落盘位置（SQLite + 索引）
export MEMORY_DATA_DIR=$HOME/hy-memory-spike/data

# ── 抽取/改写用的 LLM：直连 MiniMax 官方 API ────────────────────────────────
# 🔴 为什么直连而不经本机 LiteLLM(4000)：经网关写入要 37–74s，且会被
#    deepseek-v4-pro 的「空 system message」400 拒；直连只要 3.5–5.4s。
export MEMORY_LLM_API_KEY=$(cat $HOME/hy-memory-spike/minimax.key)
export MEMORY_LLM_BASE_URL=https://api.minimaxi.com/v1
export MEMORY_LLM_MODEL=MiniMax-M3
# 🔴 必须有这一行：不加时 MiniMax 会把 <think> 塞进 content，污染抽取 JSON
#    （单次 completion 116 token → 24 token）。
export MEMORY_LLM_EXTRA_BODY='{"thinking":{"type":"disabled"}}'

# ── 嵌入：本地 CPU fastembed，经自写 shim 暴露成 OpenAI 兼容接口 ─────────────
export MEMORY_EMBEDDER_API_KEY=dummy          # 本地 shim 不校验，但变量必须给
export MEMORY_EMBEDDER_BASE_URL=http://127.0.0.1:19528/v1
export MEMORY_EMBEDDER_MODEL=bge-small-zh-v1.5
export MEMORY_EMBEDDING_DIMS=512

export MEMORY_PIPELINE_DEFAULT_VERSION=pro
