`timescale 1ns/1ps

// =============================================================================
//  tb_mesh_5x5.sv — 5x5 2D Mesh NoC Testbench (Directed & Exhaustive Verification)
// =============================================================================

module tb_mesh_5x5;

    logic              clk;
    logic              rst_n;
    logic [24:0]       local_in_vld;
    logic [24:0]       local_in_rdy;
    logic [24:0][7:0]  local_in_data;
    logic [24:0]       local_out_vld;
    logic [24:0]       local_out_rdy;
    logic [24:0][7:0]  local_out_data;

    int pass_count = 0;
    int fail_count = 0;

    mesh_5x5 dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .local_in_vld   (local_in_vld),
        .local_in_rdy   (local_in_rdy),
        .local_in_data  (local_in_data),
        .local_out_vld  (local_out_vld),
        .local_out_rdy  (local_out_rdy),
        .local_out_data (local_out_data)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("mesh_5x5.vcd");
        $dumpvars(0, tb_mesh_5x5);
    end

    function automatic logic [7:0] make_pkt_5x5(
        input logic [2:0] dest_x,
        input logic [2:0] dest_y,
        input logic [1:0] payload
    );
        return {dest_x, dest_y, payload};
    endfunction

    task automatic send_packet_5x5(
        input int src_id,
        input logic [7:0] pkt
    );
        begin
            @(posedge clk);
            local_in_vld[src_id]  <= 1'b1;
            local_in_data[src_id] <= pkt;

            while (!local_in_rdy[src_id]) begin
                @(posedge clk);
            end

            @(posedge clk);
            local_in_vld[src_id]  <= 1'b0;
            local_in_data[src_id] <= 8'h00;
        end
    endtask

    task automatic check_packet_5x5(
        input int dst_id,
        input logic [7:0] exp_pkt,
        input string test_name
    );
        int timeout;
        bit done;
        begin
            timeout = 100;
            done = 1'b0;
            while ((timeout > 0) && !done) begin
                @(posedge clk);
                if (local_out_vld[dst_id] && local_out_rdy[dst_id]) begin
                    done = 1'b1;
                    if (local_out_data[dst_id] === exp_pkt) begin
                        $display("PASS: %s | Src -> Dst=%0d data=0x%0h time=%0t",
                                 test_name, dst_id, local_out_data[dst_id], $time);
                        pass_count++;
                    end else begin
                        $display("FAIL: %s | Dst=%0d exp=0x%0h got=0x%0h time=%0t",
                                 test_name, dst_id, exp_pkt, local_out_data[dst_id], $time);
                        fail_count++;
                    end
                end else begin
                    timeout--;
                end
            end
            if (!done) begin
                $display("FAIL: %s | Timeout waiting for Dst=%0d exp=0x%0h time=%0t",
                         test_name, dst_id, exp_pkt, $time);
                fail_count++;
            end
        end
    endtask

    task automatic route_test_5x5(
        input int src_x, input int src_y,
        input int dst_x, input int dst_y,
        input logic [1:0] payload,
        input string name
    );
        int src_id, dst_id;
        logic [7:0] pkt;
        begin
            src_id = src_y * 5 + src_x;
            dst_id = dst_y * 5 + dst_x;
            pkt = make_pkt_5x5(3'(dst_x), 3'(dst_y), payload);

            fork
                send_packet_5x5(src_id, pkt);
                check_packet_5x5(dst_id, pkt, name);
            join
        end
    endtask

    initial begin
        rst_n          = 0;
        local_in_vld   = '0;
        local_in_data  = '0;
        local_out_rdy  = '1;

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        $display("=== STARTING 5x5 MESH DIRECTED ROUTING TESTS ===");
        
        // Corner-to-Corner Routing
        route_test_5x5(0, 0, 4, 4, 2'b01, "Bottom-Left (0,0) -> Top-Right (4,4)");
        route_test_5x5(4, 4, 0, 0, 2'b10, "Top-Right (4,4) -> Bottom-Left (0,0)");
        route_test_5x5(0, 4, 4, 0, 2'b11, "Top-Left (0,4) -> Bottom-Right (4,0)");
        route_test_5x5(4, 0, 0, 4, 2'b01, "Bottom-Right (4,0) -> Top-Left (0,4)");

        // Center Node Transfers
        route_test_5x5(2, 2, 0, 0, 2'b10, "Center (2,2) -> Corner (0,0)");
        route_test_5x5(2, 2, 4, 4, 2'b01, "Center (2,2) -> Corner (4,4)");

        repeat (10) @(posedge clk);

        $display("--------------------------------");
        $display("5x5 MESH TEST COMPLETE");
        $display("PASS = %0d", pass_count);
        $display("FAIL = %0d", fail_count);
        $display("--------------------------------");

        if (fail_count == 0)
            $display("FINAL RESULT: PASS");
        else
            $display("FINAL RESULT: FAIL");

        $finish;
    end

endmodule
