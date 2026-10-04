`timescale 1ns/1ps

// =============================================================================
//  mesh_router_5x5.sv — Single node router for a 2D Mesh NoC
//
//  ARCHITECTURE:
//    Each of the 5 input ports has a 1-entry elastic buffer (register slice).
//    The buffer decouples the upstream handshake from the routing decision.
//    Routing and arbitration operate on the BUFFERED data.
//
//  INPUT BUFFER per port:
//    - buf_vld: 1 when a packet is stored and waiting to be routed
//    - buf_data: the stored packet
//    - in_rdy: high when buffer is empty (can accept new packet)
//    - A packet is accepted (clocked in) when in_vld & in_rdy
//    - A packet is released (clocked out) when it wins arbitration AND out_rdy
//
//  XY ROUTING: X-first, then Y, then LOCAL
//  ARBITRATION: Round-robin per output port
//  HANDSHAKE: valid/ready (transfer on posedge when BOTH high)
// =============================================================================

module mesh_router_5x5 #(
    parameter int CURR_X = 0,
    parameter int CURR_Y = 0,
    parameter int MESH_TYPE = 0  // 0: 4x4 Mesh ([7:6]=X, [5:4]=Y), 1: 5x5 Mesh ([7:5]=X, [4:2]=Y)
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [4:0]       in_vld,
    output logic [4:0]       in_rdy,
    input  logic [4:0][7:0]  in_data,
    output logic [4:0]       out_vld,
    input  logic [4:0]       out_rdy,
    output logic [4:0][7:0]  out_data
);

    // -----------------------------------------------------------------------
    // 1-entry input elastic buffers (one per port)
    // buf_vld[i]: buffer holds a packet
    // buf_data[i]: stored packet
    // -----------------------------------------------------------------------
    logic [4:0]      buf_vld;
    logic [4:0][7:0] buf_data;

    // Individual data wires for clean indexing (avoids packed array issues)
    wire [7:0] bd0 = buf_data[0];
    wire [7:0] bd1 = buf_data[1];
    wire [7:0] bd2 = buf_data[2];
    wire [7:0] bd3 = buf_data[3];
    wire [7:0] bd4 = buf_data[4];

    // -----------------------------------------------------------------------
    // XY Routing function
    // -----------------------------------------------------------------------
    function automatic logic [2:0] xy_route(
        input logic [2:0] dest_x,
        input logic [2:0] dest_y
    );
        logic [2:0] cx, cy;
        cx = 3'(CURR_X); cy = 3'(CURR_Y);
        if      (dest_x > cx) return 3'd1; // EAST
        else if (dest_x < cx) return 3'd2; // WEST
        else if (dest_y > cy) return 3'd3; // NORTH
        else if (dest_y < cy) return 3'd4; // SOUTH
        else                  return 3'd0; // LOCAL
    endfunction

    // Destination port per buffered packet
    wire [2:0] dp0 = (MESH_TYPE == 1) ? xy_route(bd0[7:5], bd0[4:2]) : xy_route({1'b0, bd0[7:6]}, {1'b0, bd0[5:4]});
    wire [2:0] dp1 = (MESH_TYPE == 1) ? xy_route(bd1[7:5], bd1[4:2]) : xy_route({1'b0, bd1[7:6]}, {1'b0, bd1[5:4]});
    wire [2:0] dp2 = (MESH_TYPE == 1) ? xy_route(bd2[7:5], bd2[4:2]) : xy_route({1'b0, bd2[7:6]}, {1'b0, bd2[5:4]});
    wire [2:0] dp3 = (MESH_TYPE == 1) ? xy_route(bd3[7:5], bd3[4:2]) : xy_route({1'b0, bd3[7:6]}, {1'b0, bd3[5:4]});
    wire [2:0] dp4 = (MESH_TYPE == 1) ? xy_route(bd4[7:5], bd4[4:2]) : xy_route({1'b0, bd4[7:6]}, {1'b0, bd4[5:4]});

    // -----------------------------------------------------------------------
    // Request matrix: buf_vld[i] && dp==j && out_rdy[j]
    // -----------------------------------------------------------------------
    wire r00 = buf_vld[0] && (dp0==3'd0) && out_rdy[0];
    wire r01 = buf_vld[1] && (dp1==3'd0) && out_rdy[0];
    wire r02 = buf_vld[2] && (dp2==3'd0) && out_rdy[0];
    wire r03 = buf_vld[3] && (dp3==3'd0) && out_rdy[0];
    wire r04 = buf_vld[4] && (dp4==3'd0) && out_rdy[0];

    wire r10 = buf_vld[0] && (dp0==3'd1) && out_rdy[1];
    wire r11 = buf_vld[1] && (dp1==3'd1) && out_rdy[1];
    wire r12 = buf_vld[2] && (dp2==3'd1) && out_rdy[1];
    wire r13 = buf_vld[3] && (dp3==3'd1) && out_rdy[1];
    wire r14 = buf_vld[4] && (dp4==3'd1) && out_rdy[1];

    wire r20 = buf_vld[0] && (dp0==3'd2) && out_rdy[2];
    wire r21 = buf_vld[1] && (dp1==3'd2) && out_rdy[2];
    wire r22 = buf_vld[2] && (dp2==3'd2) && out_rdy[2];
    wire r23 = buf_vld[3] && (dp3==3'd2) && out_rdy[2];
    wire r24 = buf_vld[4] && (dp4==3'd2) && out_rdy[2];

    wire r30 = buf_vld[0] && (dp0==3'd3) && out_rdy[3];
    wire r31 = buf_vld[1] && (dp1==3'd3) && out_rdy[3];
    wire r32 = buf_vld[2] && (dp2==3'd3) && out_rdy[3];
    wire r33 = buf_vld[3] && (dp3==3'd3) && out_rdy[3];
    wire r34 = buf_vld[4] && (dp4==3'd3) && out_rdy[3];

    wire r40 = buf_vld[0] && (dp0==3'd4) && out_rdy[4];
    wire r41 = buf_vld[1] && (dp1==3'd4) && out_rdy[4];
    wire r42 = buf_vld[2] && (dp2==3'd4) && out_rdy[4];
    wire r43 = buf_vld[3] && (dp3==3'd4) && out_rdy[4];
    wire r44 = buf_vld[4] && (dp4==3'd4) && out_rdy[4];

    // -----------------------------------------------------------------------
    // Round-robin pointers
    // -----------------------------------------------------------------------
    logic [2:0] rr0, rr1, rr2, rr3, rr4;

    // -----------------------------------------------------------------------
    // Round-robin grant (fully unrolled case for iverilog compatibility)
    // -----------------------------------------------------------------------
    function automatic logic [4:0] rr_grant(
        input logic [4:0] req,
        input logic [2:0] ptr
    );
        case (ptr)
            3'd0: begin
                if      (req[0]) return 5'b00001;
                else if (req[1]) return 5'b00010;
                else if (req[2]) return 5'b00100;
                else if (req[3]) return 5'b01000;
                else if (req[4]) return 5'b10000;
                else             return 5'b00000;
            end
            3'd1: begin
                if      (req[1]) return 5'b00010;
                else if (req[2]) return 5'b00100;
                else if (req[3]) return 5'b01000;
                else if (req[4]) return 5'b10000;
                else if (req[0]) return 5'b00001;
                else             return 5'b00000;
            end
            3'd2: begin
                if      (req[2]) return 5'b00100;
                else if (req[3]) return 5'b01000;
                else if (req[4]) return 5'b10000;
                else if (req[0]) return 5'b00001;
                else if (req[1]) return 5'b00010;
                else             return 5'b00000;
            end
            3'd3: begin
                if      (req[3]) return 5'b01000;
                else if (req[4]) return 5'b10000;
                else if (req[0]) return 5'b00001;
                else if (req[1]) return 5'b00010;
                else if (req[2]) return 5'b00100;
                else             return 5'b00000;
            end
            default: begin  // 3'd4
                if      (req[4]) return 5'b10000;
                else if (req[0]) return 5'b00001;
                else if (req[1]) return 5'b00010;
                else if (req[2]) return 5'b00100;
                else if (req[3]) return 5'b01000;
                else             return 5'b00000;
            end
        endcase
    endfunction

    wire [4:0] g0 = rr_grant({r04,r03,r02,r01,r00}, rr0);
    wire [4:0] g1 = rr_grant({r14,r13,r12,r11,r10}, rr1);
    wire [4:0] g2 = rr_grant({r24,r23,r22,r21,r20}, rr2);
    wire [4:0] g3 = rr_grant({r34,r33,r32,r31,r30}, rr3);
    wire [4:0] g4 = rr_grant({r44,r43,r42,r41,r40}, rr4);

    // -----------------------------------------------------------------------
    // Output MUX: drive from buffered data of winning input
    // -----------------------------------------------------------------------
    assign out_vld[0] = |g0;
    assign out_vld[1] = |g1;
    assign out_vld[2] = |g2;
    assign out_vld[3] = |g3;
    assign out_vld[4] = |g4;

    assign out_data[0] = g0[0]?bd0 : g0[1]?bd1 : g0[2]?bd2 : g0[3]?bd3 : g0[4]?bd4 : 8'h00;
    assign out_data[1] = g1[0]?bd0 : g1[1]?bd1 : g1[2]?bd2 : g1[3]?bd3 : g1[4]?bd4 : 8'h00;
    assign out_data[2] = g2[0]?bd0 : g2[1]?bd1 : g2[2]?bd2 : g2[3]?bd3 : g2[4]?bd4 : 8'h00;
    assign out_data[3] = g3[0]?bd0 : g3[1]?bd1 : g3[2]?bd2 : g3[3]?bd3 : g3[4]?bd4 : 8'h00;
    assign out_data[4] = g4[0]?bd0 : g4[1]?bd1 : g4[2]?bd2 : g4[3]?bd3 : g4[4]?bd4 : 8'h00;

    // -----------------------------------------------------------------------
    // Input ready: buffer is empty = can accept new packet
    // -----------------------------------------------------------------------
    // Ready: buffer empty OR being released this cycle (1-cycle lookahead)
    assign in_rdy[0] = ~buf_vld[0] | rel0;
    assign in_rdy[1] = ~buf_vld[1] | rel1;
    assign in_rdy[2] = ~buf_vld[2] | rel2;
    assign in_rdy[3] = ~buf_vld[3] | rel3;
    assign in_rdy[4] = ~buf_vld[4] | rel4;

    // -----------------------------------------------------------------------
    // Buffer control:
    //   Accept: in_vld[i] && in_rdy[i]   (store incoming packet)
    //   Release: g?[i] != 0              (packet won arbitration AND out_rdy)
    //   Note: both can happen in the same cycle (accept new, release old)
    //   but since buffer is 1-entry, we release first so we can accept same cycle.
    // -----------------------------------------------------------------------
    wire [4:0] buf_accept  = in_vld & in_rdy;        // new packet coming in
    wire [4:0] buf_release = {g4[0]|g4[1]|g4[2]|g4[3]|g4[4], // port4 granted something?
                               g3[0]|g3[1]|g3[2]|g3[3]|g3[4],
                               g2[0]|g2[1]|g2[2]|g2[3]|g2[4],
                               g1[0]|g1[1]|g1[2]|g1[3]|g1[4],
                               g0[0]|g0[1]|g0[2]|g0[3]|g0[4]};
    // Actually release[i] = any output granted input i this cycle
    wire rel0 = g0[0]|g1[0]|g2[0]|g3[0]|g4[0];
    wire rel1 = g0[1]|g1[1]|g2[1]|g3[1]|g4[1];
    wire rel2 = g0[2]|g1[2]|g2[2]|g3[2]|g4[2];
    wire rel3 = g0[3]|g1[3]|g2[3]|g3[3]|g4[3];
    wire rel4 = g0[4]|g1[4]|g2[4]|g3[4]|g4[4];

    // Accept conditions: take new data if buffer empty OR being released this cycle
    // This allows back-to-back packet flow without stalling
    wire can_accept0 = ~buf_vld[0] | rel0;
    wire can_accept1 = ~buf_vld[1] | rel1;
    wire can_accept2 = ~buf_vld[2] | rel2;
    wire can_accept3 = ~buf_vld[3] | rel3;
    wire can_accept4 = ~buf_vld[4] | rel4;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buf_vld  <= 5'b0;
            buf_data <= '0;
        end else begin
            // Port 0: accept if vld AND (empty or releasing); else clear on release
            if (in_vld[0] && can_accept0) begin
                buf_vld[0]  <= 1'b1;
                buf_data[0] <= in_data[0];
            end else if (rel0) begin
                buf_vld[0]  <= 1'b0;
            end
            // Port 1
            if (in_vld[1] && can_accept1) begin
                buf_vld[1]  <= 1'b1;
                buf_data[1] <= in_data[1];
            end else if (rel1) begin
                buf_vld[1]  <= 1'b0;
            end
            // Port 2
            if (in_vld[2] && can_accept2) begin
                buf_vld[2]  <= 1'b1;
                buf_data[2] <= in_data[2];
            end else if (rel2) begin
                buf_vld[2]  <= 1'b0;
            end
            // Port 3
            if (in_vld[3] && can_accept3) begin
                buf_vld[3]  <= 1'b1;
                buf_data[3] <= in_data[3];
            end else if (rel3) begin
                buf_vld[3]  <= 1'b0;
            end
            // Port 4
            if (in_vld[4] && can_accept4) begin
                buf_vld[4]  <= 1'b1;
                buf_data[4] <= in_data[4];
            end else if (rel4) begin
                buf_vld[4]  <= 1'b0;
            end
        end
    end

    // -----------------------------------------------------------------------
    // Round-robin pointer advance
    // -----------------------------------------------------------------------
    function automatic logic [2:0] next_rr(input logic [4:0] g);
        if      (g[0]) return 3'd1;
        else if (g[1]) return 3'd2;
        else if (g[2]) return 3'd3;
        else if (g[3]) return 3'd4;
        else           return 3'd0;
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr0<=3'd0; rr1<=3'd0; rr2<=3'd0; rr3<=3'd0; rr4<=3'd0;
        end else begin
            if (|g0) rr0 <= next_rr(g0);
            if (|g1) rr1 <= next_rr(g1);
            if (|g2) rr2 <= next_rr(g2);
            if (|g3) rr3 <= next_rr(g3);
            if (|g4) rr4 <= next_rr(g4);
        end
    end

endmodule
