#!/usr/bin/env bash
# =============================================================================
#  sim/run_all.sh
#  Bash script to compile and execute all NoC SystemVerilog testbenches.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

RTL_DIR="rtl"
DV_DIR="dv"
SIM_DIR="sim"

echo "======================================================================"
echo " Running SystemVerilog NoC Mesh Testbenches using Icarus Verilog       "
echo "======================================================================"
echo ""

TESTBENCHES=(
    "tb_router:${DV_DIR}/tb_router.sv ${RTL_DIR}/mesh_router_5x5.sv"
    "tb_mesh_directed:${DV_DIR}/tb_mesh_directed.sv ${RTL_DIR}/mesh_4x4.sv ${RTL_DIR}/mesh_router_5x5.sv"
    "tb_mesh_directed_16x16:${DV_DIR}/tb_mesh_directed_16x16.sv ${RTL_DIR}/mesh_4x4.sv ${RTL_DIR}/mesh_router_5x5.sv"
    "tb_mesh_single:${DV_DIR}/tb_mesh_single.sv ${RTL_DIR}/mesh_4x4.sv ${RTL_DIR}/mesh_router_5x5.sv"
    "tb_mesh_backpressure:${DV_DIR}/tb_mesh_backpressure.sv ${RTL_DIR}/mesh_4x4.sv ${RTL_DIR}/mesh_router_5x5.sv"
    "tb_mesh_random:${DV_DIR}/tb_mesh_random.sv ${RTL_DIR}/mesh_4x4.sv ${RTL_DIR}/mesh_router_5x5.sv"
    "tb_mesh_large:${DV_DIR}/tb_mesh_large.sv ${RTL_DIR}/mesh_4x4.sv ${RTL_DIR}/mesh_router_5x5.sv"
    "tb_mesh_5x5:${DV_DIR}/tb_mesh_5x5.sv ${RTL_DIR}/mesh_5x5.sv ${RTL_DIR}/mesh_router_5x5.sv"
)

FAIL_COUNT=0

for item in "${TESTBENCHES[@]}"; do
    IFS=":" read -r name files <<< "$item"
    vvp_file="${SIM_DIR}/${name}.vvp"
    log_file="${SIM_DIR}/${name}.log"

    echo "Running ${name}..."
    iverilog -g2012 -o "$vvp_file" $files
    vvp "$vvp_file" > "$log_file"
    rm -f "$vvp_file"

    if grep -q "FAIL:" "$log_file" || grep -q "timeout" "$log_file" || ! grep -q "FINAL RESULT: PASS" "$log_file"; then
        echo "  Result: FAIL (Check ${log_file})"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        echo "  Result: PASS"
    fi
    echo ""
done

echo "======================================================================"
if [ $FAIL_COUNT -eq 0 ]; then
    echo " ALL TESTBENCHES PASSED SUCCESSFULLY!"
else
    echo " SOME TESTBENCHES FAILED. Check logs in ${SIM_DIR}/"
    exit 1
fi
echo "======================================================================"
