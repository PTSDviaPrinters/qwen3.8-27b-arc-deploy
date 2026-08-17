# Qwen3.8-27B — Model Spec

Data pulled from the HF API on **2026-08-17** (not from memory).

## Official checkpoint — Qwen/Qwen3.8-27B
| Property | Value |
|---|---|
| Total parameters | **27.78 B** (all BF16) |
| Weights on disk (BF16) | **~55.6 GB** (18 shards) |
| Architecture | `Qwen3_5ForConditionalGeneration` (multimodal: image + video + text) |
| Model type | `qwen3_5` |
| Context | **262,144 native**, extensible to **1,000,000** (rope override; vLLM cmd in README) |
| Thinking | on by default; `reasoning_effort` tunable; off per request |
| License | Apache-2.0 |
| Scale signal | 415K downloads · 10.5K likes |
| Encoding | OpenAI-compatible chat templates; vision tags `<|vision_start|>` / `<|image_pad|>` / `<|video_pad|>` |

Notes:
- This is a **vision-language model** (image *and* video), vision encoder included in the param count.
- vLLM/SGLang/tokenspeed all support it; DGX Spark is an officially supported vLLM target.

## GGUF quant matrix (unsloth/Qwen3.8-27B-GGUF, 2.7M downloads)
| Quant | Size | Verdict |
|---|---|---|
| BF16 (HF stock) | 55.6 GB | Max quality — needs a free 128 GB box |
| **Q8_0** | **29.1 GB** | Near-lossless (~1 pt) · pick if a full unit is free |
| **Q6_K** | **22.9 GB** | **Sweet spot — fits Arc B70 (23.8 GB w/ mmproj)** |
| Q5_K_M | 19.8 GB | Good |
| Q4_K_M | 17.1 GB | Fine for chat; real drops on math/reasoning + vision |
| Q3_K_M | 13.8 GB | Don't bother — 128 GB units don't need this |
| IQ2/IQ3 | 9–12 GB | Irrelevant here (exists for 12 GB cards) |

`mmproj-F16.gguf` (0.93 GB) is separate — always keep F16; it's nothing.

## The quant answer
For a 27B on 128 GB-class hardware, **quantizing is a convenience, not a necessity**. Q8_0/Q6_K are within ~1 point of BF16 on most benchmarks. Q4_K_M starts eating meaningful points on reasoning and (more visibly) on vision. **Do not go below Q4_K_M** — the vision tower degrades fast, and you have the memory.
