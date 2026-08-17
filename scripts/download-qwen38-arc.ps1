# Qwen3.8-27B - download Q6_K + mmproj to the Arc box's GGUF dir
# Resumable (curl -C -), size-verified. Run from Powershell, any dir.
# Env note: NOT an MSYS shell - native Powershell/curl.exe paths work as-is.
$ErrorActionPreference = "Stop"

$DestDir  = "M:\LLM's\.lmstudio\unsloth"
$Files = @(
    @{ name = "Qwen3.8-27B-Q6_K.gguf"; url = "https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/main/Qwen3.8-27B-Q6_K.gguf"; expected = 22880000000 },  # 22.88 GB
    @{ name = "mmproj-F16.gguf";       url = "https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/main/mmproj-F16.gguf";       expected = 930000000    }   # 0.93 GB
)

Write-Host "Target dir: $DestDir"
New-Item -ItemType Directory -Force -Path $DestDir | Out-Null

foreach ($f in $Files) {
    $out = Join-Path $DestDir $f.name
    Write-Host "`n==> $($f.name)"
    # Set the xet client for faster CDN pulls; harmless if unset
    $env:HF_XET_HIGH_PERFORMANCE = "1"
    curl.exe -L -C - -o $out $f.url
    if ($LASTEXITCODE -ne 0) { throw "curl failed for $($f.name) (exit $LASTEXITCODE)" }

    $size = (Get-Item $out).Length
    $lo = $f.expected * 0.999
    $hi = $f.expected * 1.001
    if ($size -lt $lo -or $size -gt $hi) {
        throw "SIZE MISMATCH for $($f.name): got $size bytes, expected ~$($f.expected) - delete and retry from a stable network"
    }
    Write-Host "    OK: $size bytes (within tolerance)"
}

Write-Host "`nAll done. Next: .\scripts\start-qwen38-arc.ps1"
