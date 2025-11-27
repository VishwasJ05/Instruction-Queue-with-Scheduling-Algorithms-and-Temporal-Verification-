`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////

module dep_graph_with_valid (
    input  [31:0] instr_flat,   // {I3,I2,I1,I0}
    input  [3:0]  valid_bits,   // valid entries

    output [15:0] raw_flat,     // flattened row-major (i*4 + j)
    output [15:0] war_flat,
    output [15:0] waw_flat,
    output [15:0] dep_flat,
    output [3:0]  ready
);

    // -------- Internal 2-bit fields extracted from packed instructions --------
    wire [1:0] opcode [0:3];
    wire [1:0] src1   [0:3];
    wire [1:0] src2   [0:3];
    wire [1:0] dest   [0:3];

    assign opcode[0] = instr_flat[7:6];
    assign src1[0]   = instr_flat[5:4];
    assign src2[0]   = instr_flat[3:2];
    assign dest[0]   = instr_flat[1:0];

    assign opcode[1] = instr_flat[15:14];
    assign src1[1]   = instr_flat[13:12];
    assign src2[1]   = instr_flat[11:10];
    assign dest[1]   = instr_flat[9:8];

    assign opcode[2] = instr_flat[23:22];
    assign src1[2]   = instr_flat[21:20];
    assign src2[2]   = instr_flat[19:18];
    assign dest[2]   = instr_flat[17:16];

    assign opcode[3] = instr_flat[31:30];
    assign src1[3]   = instr_flat[29:28];
    assign src2[3]   = instr_flat[27:26];
    assign dest[3]   = instr_flat[25:24];

    // -------- Internal registers for matrices --------
    reg [15:0] raw_f;
    reg [15:0] war_f;
    reg [15:0] waw_f;
    reg [15:0] dep_f;
    reg [3:0]  ready_r;

    integer i, j;

    // Continuous recompute of dependency matrices (combinational)
    always @(*) begin
        raw_f   = 16'b0;
        war_f   = 16'b0;
        waw_f   = 16'b0;
        dep_f   = 16'b0;
        ready_r = 4'b0000;

        // RAW (nearest producer) - for each consumer j, scan i = j-1 downto 0
        for (j = 0; j < 4; j = j + 1) begin
            if (valid_bits[j]) begin
                // src1
                begin : RAW_SRC1
                    for (i = j-1; i >= 0; i = i - 1) begin
                        if (valid_bits[i] && (dest[i] == src1[j])) begin
                            raw_f[(i*4)+j] = 1'b1;
                            disable RAW_SRC1;
                        end
                    end
                end

                // src2
                begin : RAW_SRC2
                    for (i = j-1; i >= 0; i = i - 1) begin
                        if (valid_bits[i] && (dest[i] == src2[j])) begin
                            raw_f[(i*4)+j] = 1'b1;
                            disable RAW_SRC2;
                        end
                    end
                end

            end
        end

        // WAR & WAW (i < j)
        for (i = 0; i < 4; i = i + 1) begin
            if (valid_bits[i]) begin
                for (j = i+1; j < 4; j = j + 1) begin
                    if (valid_bits[j]) begin
                        // WAR: j writes reg read by i
                        if ((dest[j] == src1[i]) || (dest[j] == src2[i]))
                            war_f[(i*4)+j] = 1'b1;

                        // WAW: both write same dest
                        if (dest[i] == dest[j])
                            waw_f[(i*4)+j] = 1'b1;
                    end
                end
            end
        end

        // Combined dependencies
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1)
                dep_f[(i*4)+j] = raw_f[(i*4)+j] | war_f[(i*4)+j] | waw_f[(i*4)+j];

        // Ready vector (ready if valid and no RAW predecessors)
        for (j = 0; j < 4; j = j + 1) begin
            if (!valid_bits[j])
                ready_r[j] = 1'b0;
            else begin
                ready_r[j] = 1'b1;
                for (i = 0; i < 4; i = i + 1)
                    if (raw_f[(i*4)+j] == 1'b1)
                        ready_r[j] = 1'b0;
            end
        end
    end

    assign raw_flat = raw_f;
    assign war_flat = war_f;
    assign waw_flat = waw_f;
    assign dep_flat = dep_f;
    assign ready    = ready_r;

endmodule
