"""Minimal OpenAI-compatible /v1/embeddings shim backed by fastembed (local CPU, no API key).

Hy Memory 的嵌入层只认 OpenAI 兼容的 /v1/embeddings；fastembed 是进程内库，
所以用 ~30 行 FastAPI 包一层，跑在 127.0.0.1:19528（只监听回环）。

本机实测组合：BAAI/bge-small-zh-v1.5 / 512 维 / CPU。
换模型只需改环境变量 LOCAL_EMBED_MODEL 与 LOCAL_EMBED_DIMS，
并同步改 env.sh 里的 MEMORY_EMBEDDER_MODEL / MEMORY_EMBEDDING_DIMS。
"""
import os
from fastapi import FastAPI
from pydantic import BaseModel
from fastembed import TextEmbedding

MODEL_NAME = os.getenv("LOCAL_EMBED_MODEL", "BAAI/bge-small-zh-v1.5")
DIMS = int(os.getenv("LOCAL_EMBED_DIMS", "512"))
_model = TextEmbedding(MODEL_NAME)
app = FastAPI()


class Req(BaseModel):
    input: list
    model: str | None = None


@app.get("/health")
def health():
    return {"ok": True, "model": MODEL_NAME, "dims": DIMS}


@app.post("/v1/embeddings")
def embeddings(req: Req):
    vecs = [v.tolist() for v in _model.embed(req.input)]
    return {
        "object": "list",
        "data": [{"object": "embedding", "index": i, "embedding": v} for i, v in enumerate(vecs)],
        "model": req.model or MODEL_NAME,
        "usage": {"prompt_tokens": 0, "total_tokens": 0},
    }
