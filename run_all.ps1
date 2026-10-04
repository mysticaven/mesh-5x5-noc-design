# =============================================================================
#  run_all.ps1 (Root Convenience Script)
# =============================================================================

$ScriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
& "$ScriptDir\sim\run_all.ps1"
