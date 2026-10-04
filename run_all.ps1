# run_all.ps1
# PowerShell script to compile, run, and verify all SystemVerilog testbenches in the directory.

# Ensure we are in the script's directory
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
if ($PSScriptRoot) {
    Set-Location $PSScriptRoot
}

# Define the testbenches and their files
$Testbenches = @(
    @{
        Name = "tb_router"
        Files = @("tb_router.sv", "mesh_router_5x5.sv")
        Description = "Router local, east, west, north, south routing tests"
    },
    @{
        Name = "tb_mesh_directed"
        Files = @("tb_mesh_directed.sv", "mesh_4x4.sv", "mesh_router_5x5.sv")
        Description = "Basic 4x4 mesh directed corner-to-corner routing tests"
    },
    @{
        Name = "tb_mesh_directed_16x16"
        Files = @("tb_mesh_directed_16x16.sv", "mesh_4x4.sv", "mesh_router_5x5.sv")
        Description = "Exhaustive 4x4 mesh routing tests for all 16x16 node pairs"
    },
    @{
        Name = "tb_mesh_single"
        Files = @("tb_mesh_single.sv", "mesh_4x4.sv", "mesh_router_5x5.sv")
        Description = "4x4 mesh congestion / back-to-back single destination tests"
    },
    @{
        Name = "tb_mesh_backpressure"
        Files = @("tb_mesh_backpressure.sv", "mesh_4x4.sv", "mesh_router_5x5.sv")
        Description = "4x4 mesh backpressure and destination release tests"
    },
    @{
        Name = "tb_mesh_random"
        Files = @("tb_mesh_random.sv", "mesh_4x4.sv", "mesh_router_5x5.sv")
        Description = "4x4 mesh random traffic simulation with random backpressure"
    },
    @{
        Name = "tb_mesh_large"
        Files = @("tb_mesh_large.sv", "mesh_4x4.sv", "mesh_router_5x5.sv")
        Description = "4x4 mesh large random traffic simulation (20,000 packets)"
    },
    @{
        Name = "tb_mesh_5x5"
        Files = @("tb_mesh_5x5.sv", "mesh_5x5.sv", "mesh_router_5x5.sv")
        Description = "5x5 mesh directed corner-to-corner and center routing tests"
    }
)

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " Running SystemVerilog NoC Mesh Testbenches using Icarus Verilog       " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

$Results = @()

foreach ($tb in $Testbenches) {
    $name = $tb.Name
    $files = $tb.Files
    $desc = $tb.Description
    $vvp_file = "$name.vvp"
    $log_file = "$name.log"

    Write-Host "Running $name : $desc..." -ForegroundColor Yellow

    # Compile the files
    $files_str = $files -join " "
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

    # Run the simulation, saving output in UTF-8
    $sim_cmd = "vvp $vvp_file"
    Invoke-Expression $sim_cmd | Out-File -Encoding utf8 $log_file

    # Verify simulation results
    $status = "PASS"
    if (Test-Path $log_file) {
        $log_content = Get-Content $log_file
        
        # Check for failure pattern
        $has_fail = $false
        foreach ($line in $log_content) {
            # Match "FAIL:" (with colon), "timeout", or a non-zero fail count "FAIL = X" (X > 0)
            if ($line -like "*FAIL:*" -or $line -like "*timeout*" -or ($line -match "FAIL\s*=\s*[1-9]")) {
                $has_fail = $true
                break
            }
        }

        # Check if simulation completed properly
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

    # Clean up compilation outputs
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
