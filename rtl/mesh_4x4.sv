`timescale 1ns/1ps

// =============================================================================
//  mesh_4x4.sv  —  4x4 2D Mesh NoC (bidirectional links, corrected)
// =============================================================================

module mesh_4x4 (
    input  logic              clk,
    input  logic              rst_n,
    input  logic [15:0]       local_in_vld,
    output logic [15:0]       local_in_rdy,
    input  logic [15:0][7:0]  local_in_data,
    output logic [15:0]       local_out_vld,
    input  logic [15:0]       local_out_rdy,
    output logic [15:0][7:0]  local_out_data
);

    localparam int LOCAL=0, EAST=1, WEST=2, NORTH=3, SOUTH=4;

    wire [4:0]      ri_vld  [0:3][0:3];  // inputs  to router (valid)
    wire [4:0][7:0] ri_data [0:3][0:3];  // inputs  to router (data)
    wire [4:0]      ro_rdy  [0:3][0:3];  // ready   to router output
    wire [4:0]      ro_vld  [0:3][0:3];  // outputs from router (valid)
    wire [4:0][7:0] ro_data [0:3][0:3];  // outputs from router (data)
    wire [4:0]      ri_rdy  [0:3][0:3];  // ready   from router input

    genvar gy, gx;
    generate
        for (gy = 0; gy < 4; gy++) begin : row
            for (gx = 0; gx < 4; gx++) begin : col
                mesh_router_5x5 #(.CURR_X(gx),.CURR_Y(gy)) u_r (
                    .clk     (clk), .rst_n   (rst_n),
                    .in_vld  (ri_vld [gy][gx]), .in_rdy  (ri_rdy [gy][gx]),
                    .in_data (ri_data[gy][gx]),
                    .out_vld (ro_vld [gy][gx]), .out_rdy (ro_rdy [gy][gx]),
                    .out_data(ro_data[gy][gx])
                );
            end
        end
    endgenerate

    // LOCAL ports
    generate
        for (gy = 0; gy < 4; gy++) begin : lc_y
            for (gx = 0; gx < 4; gx++) begin : lc_x
                localparam int ID = gy*4+gx;
                assign ri_vld [gy][gx][LOCAL] = local_in_vld [ID];
                assign ri_data[gy][gx][LOCAL] = local_in_data[ID];
                assign ro_rdy [gy][gx][LOCAL] = local_out_rdy[ID];
                assign local_in_rdy  [ID]     = ri_rdy [gy][gx][LOCAL];
                assign local_out_vld [ID]     = ro_vld [gy][gx][LOCAL];
                assign local_out_data[ID]     = ro_data[gy][gx][LOCAL];
            end
        end
    endgenerate

    // Horizontal bidirectional links (for x=0..2, each pair has two channels)
    generate
        for (gy = 0; gy < 4; gy++) begin : ew_y
            for (gx = 0; gx < 3; gx++) begin : ew_x
                // EAST channel: (gx,gy) EAST output  ->  (gx+1,gy) WEST input
                assign ri_vld [gy][gx+1][WEST] = ro_vld [gy][gx  ][EAST];
                assign ri_data[gy][gx+1][WEST] = ro_data[gy][gx  ][EAST];
                assign ro_rdy [gy][gx  ][EAST] = ri_rdy [gy][gx+1][WEST];
                // WEST channel: (gx+1,gy) WEST output -> (gx,gy) EAST input
                assign ri_vld [gy][gx  ][EAST] = ro_vld [gy][gx+1][WEST];
                assign ri_data[gy][gx  ][EAST] = ro_data[gy][gx+1][WEST];
                assign ro_rdy [gy][gx+1][WEST] = ri_rdy [gy][gx  ][EAST];
            end
        end
    endgenerate

    // Vertical bidirectional links (for y=0..2)
    generate
        for (gy = 0; gy < 3; gy++) begin : ns_y
            for (gx = 0; gx < 4; gx++) begin : ns_x
                // NORTH channel: (gx,gy) NORTH output -> (gx,gy+1) SOUTH input
                assign ri_vld [gy+1][gx][SOUTH] = ro_vld [gy  ][gx][NORTH];
                assign ri_data[gy+1][gx][SOUTH] = ro_data[gy  ][gx][NORTH];
                assign ro_rdy [gy  ][gx][NORTH] = ri_rdy [gy+1][gx][SOUTH];
                // SOUTH channel: (gx,gy+1) SOUTH output -> (gx,gy) NORTH input
                assign ri_vld [gy  ][gx][NORTH] = ro_vld [gy+1][gx][SOUTH];
                assign ri_data[gy  ][gx][NORTH] = ro_data[gy+1][gx][SOUTH];
                assign ro_rdy [gy+1][gx][SOUTH] = ri_rdy [gy  ][gx][NORTH];
            end
        end
    endgenerate

    // =========================================================================
    // BOUNDARY TERMINATIONS
    //
    // Port naming from the ROUTER's perspective:
    //   WEST port  (idx 2): data arriving FROM the west  / departing TO the west
    //   EAST port  (idx 1): data arriving FROM the east  / departing TO the east
    //   SOUTH port (idx 4): data arriving FROM the south / departing TO the south
    //   NORTH port (idx 3): data arriving FROM the north / departing TO the north
    //
    // Western edge (x=0): nothing to the WEST of these routers
    //   -> WEST input idle:  ri_vld[y][0][WEST] = 0
    //   -> WEST output void: ro_rdy[y][0][WEST] = 1  (always drain)
    // Eastern edge (x=3): nothing to the EAST
    //   -> EAST input idle:  ri_vld[y][3][EAST] = 0
    //   -> EAST output void: ro_rdy[y][3][EAST] = 1
    // Southern edge (y=0): nothing to the SOUTH
    //   -> SOUTH input idle: ri_vld[0][x][SOUTH] = 0
    //   -> SOUTH output void: ro_rdy[0][x][SOUTH] = 1
    // Northern edge (y=3): nothing to the NORTH
    //   -> NORTH input idle: ri_vld[3][x][NORTH] = 0
    //   -> NORTH output void: ro_rdy[3][x][NORTH] = 1
    // =========================================================================
    generate
        for (gy = 0; gy < 4; gy++) begin : bnd_w
            assign ri_vld [gy][0][WEST] = 1'b0;
            assign ri_data[gy][0][WEST] = 8'h00;
            assign ro_rdy [gy][0][WEST] = 1'b1;
        end
    endgenerate
    generate
        for (gy = 0; gy < 4; gy++) begin : bnd_e
            assign ri_vld [gy][3][EAST] = 1'b0;
            assign ri_data[gy][3][EAST] = 8'h00;
            assign ro_rdy [gy][3][EAST] = 1'b1;
        end
    endgenerate
    generate
        for (gx = 0; gx < 4; gx++) begin : bnd_s
            assign ri_vld [0][gx][SOUTH] = 1'b0;
            assign ri_data[0][gx][SOUTH] = 8'h00;
            assign ro_rdy [0][gx][SOUTH] = 1'b1;
        end
    endgenerate
    generate
        for (gx = 0; gx < 4; gx++) begin : bnd_n
            assign ri_vld [3][gx][NORTH] = 1'b0;
            assign ri_data[3][gx][NORTH] = 8'h00;
            assign ro_rdy [3][gx][NORTH] = 1'b1;
        end
    endgenerate

endmodule
