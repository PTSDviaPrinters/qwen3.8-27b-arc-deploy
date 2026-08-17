# Deploy Qwen3.8-27B on the Arc Pro B70 (32 GB)

Target machine: the workstation where the **Intel Arc Pro B70 (32 GB)** lives (the `.30` box in our LAN story). DeepSeek on the Sparks is **untouched** — this is a completely separate service.

## 0. Pre-existing env (from our setup — verify on the target box)
- llama.cpp-SYCL build: source `M:\LLMs\llama-cpp-sycl\llama.cpp`, builds via `M:\LLMs\llama-cpp-sycl\build-latest.sh [tag]`, deploy dir `M:\LLMs\llama-b9334-bin-win-sycl-x64\`
- Intel LLVM 2026.0.0, Level-Zero backend, Arc Pro B70 32 GB (SM12.1-like / SYCL `l0`)
- GGUF collection: `M:\LLM's\.lmstudio\unsloth\`
- The old Qwen3.6-27B ran MTP spec-decode via `M:\LLMs\start-toby-27b-mtp.ps1` and served at `localhost:8081`

> If the old binary predates `qwen3_5`, rebuild: `build-latest.sh` (see llama-cpp-sycl skill for flags). `qwen3_5` arch support landed in llama.cpp by Aug 2026; verify `llama-server.exe -m <model> --version` loads the arch without "unknown architecture".

## 1. Download (~23.8 GB total, resumable, size-verified)
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\download-qwen38-arc.ps1
```
Or raw:
```powershell
cd "M:\LLM's\.lmstudio\unsloth"
$env:HF_XET_HIGH_PERFORMANCE=1
curl.exe -L -C - -o Qwen3.8-27B-Q6_K.gguf "https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/main/Qwen3.8-27B-Q6_K.gguf"
curl.exe -L -C - -o mmproj-F16.gguf       "https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/main/mmproj-F16.gguf"
```
Expected sizes: **Q6_K = 22.88 GB** · **mmproj-F16 = 0.93 GB** (the script verifies).

## 2. Serve (start-qwen38-arc.ps1)
Point `$LLAMA_BIN` at your SYCL deploy dir, then it runs roughly:
```powershell
& "$LLAMA_BIN\llama-server.exe" `
  -m "M:\LLM's\.lmstudio\unsloth\Qwen3.8-27B-Q6_K.gguf" `
  --mmproj "M:\LLM's\.lmstudio\unsloth\mmproj-F16.gguf" `
  -ngl 99 --host 0.0.0.0 --port 8081 `
  -c 32768 --parallel 2
```
Notes:
- `-ngl 99` = full offload to the Arc (Q6 + mmproj ≈ 23.8 GB < 32 GB, comfortable)
- `-c 32768` is a sane default; the model natively supports 256K — raise it if you have the RAM for KV, but 32–64K is the practical spot on shared memory
- MTP spec-decode: if your build has the draft model path from the Qwen3.6 era, the 3.8 draft equivalents may exist (Jackrong/esatapedico publish MTP GGUFs) — optional, adds complexity, skip for v1

## 3. Smoke test
```powershell
curl.exe http://localhost:8081/v1/models
# text
curl.exe http://localhost:8081/v1/chat/completions -H "Content-Type: application/json" -d '{\"model\":\"qwen3.8-27b-q6\",\"messages\":[{\"role\":\"user\",\"content\":\"Say OK\"}]}'
# vision (same API, image as data URL in content):
# https://platform.openai.com/docs/guides/vision → base64 data URL in image_url
```

## 4. Wire into Hermes as the vision model
DeepSeek V4 Flash is text-only (confirmed in the recipe docs), so this box plugs the vision gap:
- Config: set the **auxiliary vision** provider to `http://<arc-box>:8081/v1`, model `qwen3.8-27b-q6`.
- `vision_analyze` and any image task then route to the Arc; the main model (DeepSeek via the Sparks) is untouched.
- Belt-and-suspenders: keep it as `auxiliary.vision` only — do **not** make it the main model; it's for image tasks.

## 5. Verdict recap (full: SPARK-FIT.md)
- ❌ 27B on the 2× Spark stack with DeepSeek: **no** (needs 17–23 GB; total slack is ~18 GiB of DeepSeek's own KV).
- ✅ This Arc path: full near-lossless quality, zero impact on DeepSeek, ~15 min once the GGUF is down.
- On-Spark alternative if you insist: recipe's Qwen3-VL-**4B** sidecar (`ENABLE_VL_SIDECAR=1`) — weaker vision, costs DeepSeek ~0.9M KV tokens.
