# 2× DGX Spark + DeepSeek — can Qwen3.8-27B coexist?

**Short answer: No.** This doc has the real numbers.

Source of truth: the exact recipe we run —
<https://github.com/MiaAI-Lab/DeepSeek-v4-Flash-DSpark-2x-DGX-Spark>
(its coexist experiment, `results/vl-nvfp4-coexist-2026-08-11.md`, *is* this question asked and answered by the recipe authors).

## What the recipe runs on our 2 units
- `deepseek-ai/DeepSeek-V4-Flash-0731`, **~300 B params**, NVFP4 (4-bit) weights ≈ **~79 GiB/rank × 2**, TP=2, DSpark spec-decode (MTP-5), `nvfp4_ds_mla` KV, **1M-token** ceiling.
- Image: `ghcr.io/anemll/dspark-vllm-gx10:0.1.1`. Weights/quant metadata: recipe's `docs/DEEPSEEK_V4_FLASH_0731.md` (FP8→NVFP4 serving lane).

## Memory ledger (text-only, default profile)
From boot log in the recipe README:

| Line | Value |
|---|---|
| GPU_MEMORY_UTILIZATION_TEXT | 0.835 |
| Available KV cache memory | **18.08 GiB** |
| GPU KV cache size | **2,493,464 tokens** |
| Max concurrency @ 1M-token requests | 2.38× |

**The entire 256 GB budget is DeepSeek.** The 18 GiB of usable KV is the only slack, and that slack is DeepSeek's own context pool.

## The coexist experiment (authors tested, 2026-08-11)
They shoved a **Qwen3-VL-4B** (AWQ 4-bit) onto `:8889` as a "VL sidecar":

| Config | Result |
|---|---|
| main util 0.835, seqs 6 | main KV 1,811,802 — **VL init = NCCL CUDA OOM** |
| main util **0.82**, seqs 4 | main KV **1,598,877** · VL KV **55,232 tok (~1.01 GiB)** @ 32K |
| main util 0.80, seqs 6 | main KV 1,488,433 · VL fp8 init = KV shortfall |
| 4-bit VL workaround | `int4_per_token_head` + `TRITON_ATTN` (true nvfp4 KV is SM100-only) |

Key numbers:
- Qwen3-VL-**4B** got **≈1 GiB** of KV. It needed `MAX_NUM_SEQS` cut 6→4, main KV lost ~35% (2.49M → 1.6M), util dropped 0.835→0.82, and the worker had **1.19 GiB free** total.
- A **27B** quant needs **17–23 GB** — **~20×** the 4B's whole allocation. It would nuke DeepSeek's KV pool to zero, and the worker free-memory gate (`free < util × 121.63 GiB`) blocks it before it even starts.

## Verdicts
1. **Qwen3.8-27B on the 2× Spark stack alongside DeepSeek: not possible** at any practical quant, at any DeepSeek setting that stays usable.
2. **On-Spark vision path that DOES exist:** the recipe's intended sidecar — Qwen3-VL-**4B** on `:8889` (`ENABLE_VL_SIDECAR=1`, `PREPARE_VL_SIDECAR_MODEL=1`, default `VL_SIDECAR_GPU_UTIL=0.04`). Cost: DeepSeek KV 2.49M → ~1.6M, seqs 6→4. Weaker vision than the 27B, but sanctioned and tested.
3. **Full-quality path (recommended):** run Qwen3.8-27B-**Q6_K** on the Arc Pro B70 (32 GB) on the workstation — see `ARC-DEPLOY.md`. DeepSeek untouched.
4. **Future option:** a dedicated 3rd Spark would host Qwen3.8-27B in BF16/Q8 comfortably — that's the "add a unit if you ever need it" lane, not a 2-unit option.
