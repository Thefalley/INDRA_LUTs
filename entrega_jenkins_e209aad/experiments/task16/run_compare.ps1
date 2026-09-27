param(
    [string]$VivadoBin = 'C:/AMDDesignTools/2025.2/Vivado/bin',
    [string]$BaselineRoot = "$PSScriptRoot/../../../stable_task4_validation"
)
$ErrorActionPreference = 'Stop'
$candidateRoot = (Resolve-Path "$PSScriptRoot/../..").Path
$baselineRoot = (Resolve-Path $BaselineRoot).Path
if ((git -C $baselineRoot rev-parse HEAD) -ne '2f379527b8c3c25260ed7d3e07e50ec21976aecf') {
    throw 'Baseline must be commit 2f379527b8c3c25260ed7d3e07e50ec21976aecf'
}
if (git -C $baselineRoot status --porcelain -- src/tasks/task_16) {
    throw 'Baseline task16 sources have uncommitted changes'
}
foreach ($variant in @('baseline','candidate')) {
    $sourceRoot = if ($variant -eq 'baseline') { $baselineRoot } else { $candidateRoot }
    $runDir = Join-Path $PSScriptRoot "run_$variant"
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    Push-Location $runDir
    try {
        $sources = Get-ChildItem "$sourceRoot/src/tasks/task_16/*.sv" | Select-Object -ExpandProperty FullName
        & "$VivadoBin/xvlog.bat" -sv @sources "$PSScriptRoot/tb_packer.sv"
        if ($LASTEXITCODE -ne 0) { throw "xvlog $variant failed" }
        & "$VivadoBin/xelab.bat" tb_packer -s packer -debug typical
        if ($LASTEXITCODE -ne 0) { throw "xelab $variant failed" }
        & "$VivadoBin/xsim.bat" packer -runall -log result.log
        if ($LASTEXITCODE -ne 0) { throw "xsim $variant failed" }
        if (!(Select-String -Path result.log -Pattern '^PASS packets=256' -Quiet)) { throw "No PASS: $variant" }
    } finally { Pop-Location }
}
