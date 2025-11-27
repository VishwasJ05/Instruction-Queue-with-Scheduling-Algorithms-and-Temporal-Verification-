`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////

module instruction_queue_rs (
    input  clk,
    input  reset,              // synchronous active-high reset

    // enqueue interface
    input        enqueue,
    input  [7:0] instr_in,

    // retire from scheduler (one-hot)
    input  [3:0] retire_onehot,

    // window output for DAG + scheduler
    output [31:0] instr_flat_out,  // packed 4x8-bit instructions
    output [3:0]  valid_bits,

    output full,
    output empty
);

    // Internal storage (parallel arrays)
    reg [1:0] opcode [0:3];
    reg [1:0] src1   [0:3];
    reg [1:0] src2   [0:3];
    reg [1:0] dest   [0:3];
    reg       valid  [0:3];

    integer i;
    reg [2:0] count;        // number of valid entries (0..4)

    
    integer del_cnt;
    integer free_idx;

    // Synchronous logic
    always @(posedge clk) begin
        if (reset) begin
            count <= 0;
            for (i = 0; i < 4; i = i + 1) begin
                opcode[i] <= 2'b00;
                src1[i]   <= 2'b00;
                src2[i]   <= 2'b00;
                dest[i]   <= 2'b00;
                valid[i]  <= 1'b0;
            end
        end else begin
            // 1) Retire: compute retire count and invalidate entries
            del_cnt = retire_onehot[0] + retire_onehot[1] +
                      retire_onehot[2] + retire_onehot[3];

            for (i = 0; i < 4; i = i + 1) begin
                if (retire_onehot[i]) begin
                    valid[i] <= 1'b0;
                end
            end

            if (del_cnt != 0)
                count <= count - del_cnt;

            // 2) Enqueue (only if enqueue asserted)
            if (enqueue) begin
                free_idx = -1;
                for (i = 0; i < 4; i = i + 1) begin
                    if ((free_idx == -1) && (valid[i] == 1'b0)) begin
                        free_idx = i;
                    end
                end

                if (free_idx != -1) begin
                    opcode[free_idx] <= instr_in[7:6];
                    src1[free_idx]   <= instr_in[5:4];
                    src2[free_idx]   <= instr_in[3:2];
                    dest[free_idx]   <= instr_in[1:0];
                    valid[free_idx]  <= 1'b1;
                    count <= count + 1;
                end
            end
        end
    end

    // Combinational: pack outputs
    assign valid_bits = { valid[3], valid[2], valid[1], valid[0] };

    assign instr_flat_out[7:0]   = { opcode[0], src1[0], src2[0], dest[0] };
    assign instr_flat_out[15:8]  = { opcode[1], src1[1], src2[1], dest[1] };
    assign instr_flat_out[23:16] = { opcode[2], src1[2], src2[2], dest[2] };
    assign instr_flat_out[31:24] = { opcode[3], src1[3], src2[3], dest[3] };

    // Status
    assign full  = (count == 4);
    assign empty = (count == 0);

endmodule
