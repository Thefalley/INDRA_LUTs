param([string]$VivadoBin = 'C:/AMDDesignTools/2025.2/Vivado/bin')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot/../..").Path
$run = New-Item -ItemType Directory -Force "$PSScriptRoot/run_check"
New-Item -ItemType Directory -Force "$run/tb" | Out-Null
Copy-Item "$repo/tb/task15.mem", "$repo/tb/task15_ref.mem" "$run/tb"
Push-Location $run
try {
    & "$VivadoBin/xvlog.bat" -sv "$repo/src/tasks/task_15/task_15.sv" "$PSScriptRoot/tb_stages.sv" "$PSScriptRoot/tb_general.sv"
    if ($LASTEXITCODE -ne 0) { throw 'Compile failed' }
    foreach ($bench in @('tb_stages','tb_general')) {
        & "$VivadoBin/xelab.bat" $bench -s $bench
        if ($LASTEXITCODE -ne 0) { throw "Elaboration failed: $bench" }
        & "$VivadoBin/xsim.bat" $bench -runall -log "$bench.log"
        $pass = if ($bench -eq 'tb_stages') { 'STAGE_CHECK_PASS' } else { 'GENERAL_PASS' }
        if ($LASTEXITCODE -ne 0 -or !(Select-String -Path "$bench.log" -Pattern $pass -SimpleMatch -Quiet) -or (Select-String -Path "$bench.log" -Pattern 'Fatal:|Error:|TIMEOUT' -Quiet)) {
            throw "Simulation failed: $bench"
        }
    }
} finally { Pop-Location }
