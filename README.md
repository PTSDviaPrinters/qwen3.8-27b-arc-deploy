# Qwen3.8-27B — Fit & Deploy Package

**Date:** 2026-08-17 · **Status:** ready to deploy
**Question answered:** *How does Qwen3.8-27B fit on our 2× DGX Sparks alongside DeepSeek V4 Flash, how big is it, and is it worth running quantized?*

**Short verdict:**
- ❌ **Does NOT fit alongside DeepSeek on the 2× Spark stack.** The Spark boxes are TP=2-locked to DeepSeek (NVFP4 ~158 GB weights) with only ~18 GiB of usable KV left. The MiaAI recipe's own coexist test barely squeezed in a **Qwen3-VL-4B** (~1 GiB KV); a 27B needs 17–23+ GB. Not possible at any practical quant.
- ✅ **Fits the Intel Arc Pro B70 (32 GB) at Q6_K (~23 GB total)** — same slot/rig where Qwen3.6-27B already ran via llama.cpp-SYCL. DeepSeek on the Sparks stays 100% untouched.
- Q6 on a 27B is near-lossless. On the Arc it's also the biggest quant that fits.

## Repo contents
| File | What it is |
|---|---|
| `README.md` | This overview |
| `docs/MODEL-SPEC.md` | Size, context, quant matrix, provenance (HF numbers pulled 2026-08-17) |
| `docs/SPARK-FIT.md` | Full 2× DGX Spark + DeepSeek coexist analysis with real numbers + source links |
| `docs/ARC-DEPLOY.md` | Step-by-step: download → serve on Arc B70 → wire into Hermes aux vision |
| `scripts/download-qwen38-arc.ps1` | One-shot downloader for the two GGUFs (Q6_K + mmproj), resumable, size-verified |
| `scripts/start-qwen38-arc.ps1` | llama-server launch for the Arc (port 8081, mmproj attached) |

## Key links
- Model card (official): https://huggingface.co/Qwen/Qwen3.8-27B
- GGUF (unsloth, 2.7M downloads): https://huggingface.co/unsloth/Qwen3.8-27B-GGUF
- Their running recipe (2× Spark DeepSeek): https://github.com/MiaAI-Lab/DeepSeek-v4-Flash-DSpark-2x-DGX-Spark
- Coexist experiment (read this): `results/vl-nvfp4-coexist-2026-08-11.md` in the recipe repo

## Files to download (23.8 GB total)
```
https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/main/Qwen3.8-27B-Q6_K.gguf   22.88 GB
https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/main/mmproj-F16.gguf          0.93 GB
```

## Quick deploy (verified on the Arc box 2026-08-17)
GGUFs already downloaded to `M:\LLM's\.lmstudio\unsloth\` (Q6_K 22.88 GB + mmproj-F16 0.93 GB).
The staged launcher lives at `M:\LLMs\start-qwen38-arc.ps1` — run it:
```powershell
powershell -ExecutionPolicy Bypass -File M:\LLMs\start-qwen38-arc.ps1
# 2. test
curl http://localhost:8081/v1/models   # expect qwen3.8-27b-q6
```
Full detail in `docs/ARC-DEPLOY.md` (incl. Hermes `auxiliary.vision` wiring).
