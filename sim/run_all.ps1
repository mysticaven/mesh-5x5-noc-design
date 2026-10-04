# =============================================================================
#  sim/run_all.ps1
#  PowerShell script to compile and execute all NoC SystemVerilog testbenches.
# =============================================================================

$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$ProjectRoot  = Resolve-Path "$PSScriptRoot\.."
Set-Location $ProjectRoot

$RTL_DIR = "rtl"
$DV_DIR  = "dv"
$SIM_DIR = "sim"

$Testbenches = @(
    @{
        Name = "tb_router"
        Files = @("$DV_DIR/tb_router.sv", "$RTL_DIR/mesh_router_5x5.sv")
        Description = "Unit tests for 5-port router node"
    },
    @{
        Name = "tb_mesh_directed"
        Files = @("$DV_DIR/tb_mesh_directed.sv", "$RTL_DIR/mesh_4x4.sv", "$RTL_DIR/mesh_router_5x5.sv")
        Description = "4x4 mesh directed corner-to-corner routing tests"
    },
    @{
        Name = "tb_mesh_directed_16x16"
        Files = @("$DV_DIR/tb_mesh_directed_16x16.sv", "$RTL_DIR/mesh_4x4.sv", "$RTL_DIR/mesh_router_5x5.sv")
        Description = "Exhaustive 4x4 mesh routing tests for all 16x16 node pairs"
    },
    @{
        Name = "tb_mesh_single"
        Files = @("$DV_DIR/tb_mesh_single.sv", "$RTL_DIR/mesh_4x4.sv", "$RTL_DIR/mesh_router_5x5.sv")
        Description = "4x4 mesh congestion / back-to-back single destination tests"
    },
    @{
        Name = "tb_mesh_backpressure"
        Files = @("$DV_DIR/tb_mesh_backpressure.sv", "$RTL_DIR/mesh_4x4.sv", "$RTL_DIR/mesh_router_5x5.sv")
        Description = "4x4 mesh backpressure and destination release tests"
    },
    @{
        Name = "tb_mesh_random"
        Files = @("$DV_DIR/tb_mesh_random.sv", "$RTL_DIR/mesh_4x4.sv", "$RTL_DIR/mesh_router_5x5.sv")
        Description = "4x4 mesh random traffic simulation with random backpressure"
    },
    @{
        Name = "tb_mesh_large"
        Files = @("$DV_DIR/tb_mesh_large.sv", "$RTL_DIR/mesh_4x4.sv", "$RTL_DIR/mesh_router_5x5.sv")
        Description = "4x4 mesh large random traffic simulation (20,000 packets)"
    },
    @{
        Name = "tb_mesh_5x5"
        Files = @("$DV_DIR/tb_mesh_5x5.sv", "$RTL_DIR/mesh_5x5.sv", "$RTL_DIR/mesh_router_5x5.sv")
        Description = "5x5 mesh directed corner-to-corner and center routing tests"
    }
)

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " Running SystemVerilog NoC Mesh Testbenches using Icarus Verilog       " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

$Results = @()

foreach ($tb in $Testbenches) {
    $name     = $tb.Name
    $files    = $tb.Files
    $desc     = $tb.Description
    $vvp_file = "$SIM_DIR/$name.vvp"
    $log_file = "$SIM_DIR/$name.log"

    Write-Host "Running $name : $desc..." -ForegroundColor Yellow

    # Compile files using IEEE 1800-2012 SystemVerilog
    $files_str  = $files -join " "
    $compile_cmd = "iverilog -g2012 -o $vvp_file $files_str"
    Invoke-Expression $compile_cmd 2>$null

    if (-not (Test-Path $vvp_file)) {
        Write-Host "  Compilation FAILED!" -ForegroundColor Red
        $Results += [PSCustomObject]@{
            Testbench = $name
            Compile   = "FAIL"
            SimResult = "N/A"
            LogFile   = "N/A"
        }
        continue
    }

    # Execute simulation
    $sim_cmd = "vvp $vvp_file"
    Invoke-Expression $sim_cmd | Out-File -Encoding utf8 $log_file

    # Verify simulation status
    $status = "PASS"
    if (Test-Path $log_file) {
        $log_content = Get-Content $log_file
        
        $has_fail = $false
        foreach ($line in $log_content) {
            if ($line -like "*FAIL:*" -or $line -like "*timeout*" -or ($line -match "FAIL\s*=\s*[1-9]")) {
                $has_fail = $true
                break
            }
        }

        $finished = $false
        foreach ($line in $log_content) {
            if ($line -like "*TEST COMPLETE*" -or $line -like "*FINAL RESULT: PASS*") {
                $finished = $true
                break
            }
        }

        if ($has_fail -or -not $finished) {
            $status = "FAIL"
        }
    } else {
        $status = "NO LOG"
    }

    # Clean compiled binaries
    if (Test-Path $vvp_file) {
        Remove-Item $vvp_file -Force
    }

    if ($status -eq "PASS") {
        Write-Host "  Simulation Result: PASS" -ForegroundColor Green
    } else {
        Write-Host "  Simulation Result: FAIL (Check $log_file)" -ForegroundColor Red
    }
    Write-Host ""

    $Results += [PSCustomObject]@{
        Testbench = $name
        Compile   = "OK"
        SimResult = $status
        LogFile   = $log_file
    }
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "                           SUMMARY OF RESULTS                         " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$Results | Format-Table -AutoSize
