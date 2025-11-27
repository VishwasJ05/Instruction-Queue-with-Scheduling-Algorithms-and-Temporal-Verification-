`timescale 1ns/1ps
module scheduler_resbind #(
    parameter ALU_COUNT = 1,
    parameter MUL_COUNT = 1,
    parameter DIV_COUNT = 1,

    parameter ALU_LAT = 2,
    parameter MUL_LAT = 3,
    parameter DIV_LAT = 4,

    parameter MAX_FU  = 4,
    parameter LAT_W   = 4
)(
    input clk,
    input reset,
    input sch_enable,

    input [15:0] raw_flat,
    input [3:0]  valid_bits,
    input [31:0] instr_flat,

    output [3:0] issue_onehot,
    output reg       valid_out,
    output reg [7:0] issued_instr,
    output reg [1:0] issued_fu_type,
    output reg [1:0] issued_fu_index,

    output reg [3:0] retire_onehot
);

    // --------------------------------------------------------------
    
    // --------------------------------------------------------------
    integer i;
    integer idx_issue;
    integer pick;

    // --------------------------------------------------------------
    // Unpack instructions for convenience
    // --------------------------------------------------------------
    wire [1:0] opcode [0:3];
    wire [1:0] dest   [0:3];

    assign opcode[0] = instr_flat[7:6];
    assign opcode[1] = instr_flat[15:14];
    assign opcode[2] = instr_flat[23:22];
    assign opcode[3] = instr_flat[31:30];

    assign dest[0] = instr_flat[1:0];
    assign dest[1] = instr_flat[9:8];
    assign dest[2] = instr_flat[17:16];
    assign dest[3] = instr_flat[25:24];

    // --------------------------------------------------------------
    // RAW dynamic tracker
    // --------------------------------------------------------------
    reg [15:0] raw_dyn;
    reg raw_init;

    // Once an instruction is issued, this prevents reissue
    reg [3:0] issued_mask;

    // --------------------------------------------------------------
    // FU busy counters + next-state
    // --------------------------------------------------------------
    reg [LAT_W-1:0] alu_busy [0:MAX_FU-1];
    reg [LAT_W-1:0] mul_busy [0:MAX_FU-1];
    reg [LAT_W-1:0] div_busy [0:MAX_FU-1];

    reg [LAT_W-1:0] nxt_alu_busy [0:MAX_FU-1];
    reg [LAT_W-1:0] nxt_mul_busy [0:MAX_FU-1];
    reg [LAT_W-1:0] nxt_div_busy [0:MAX_FU-1];

    // FU → IQ index mapping
    reg [1:0] fu_idx_alu [0:MAX_FU-1];
    reg [1:0] fu_idx_mul [0:MAX_FU-1];
    reg [1:0] fu_idx_div [0:MAX_FU-1];

    // --------------------------------------------------------------
    // RAW column masks
    // --------------------------------------------------------------
    wire [3:0] raw_mask [0:3];

    assign raw_mask[0] = { raw_dyn[12], raw_dyn[8],  raw_dyn[4],  raw_dyn[0] };
    assign raw_mask[1] = { raw_dyn[13], raw_dyn[9],  raw_dyn[5],  raw_dyn[1] };
    assign raw_mask[2] = { raw_dyn[14], raw_dyn[10], raw_dyn[6],  raw_dyn[2] };
    assign raw_mask[3] = { raw_dyn[15], raw_dyn[11], raw_dyn[7],  raw_dyn[3] };

    // --------------------------------------------------------------
    // READY logic
    // --------------------------------------------------------------
    reg [3:0] ready_dep;
    reg [3:0] ready;
    reg [3:0] sel;

    reg [3:0] alu_free, mul_free, div_free;

    // Dependence ready
    always @(*) begin
        ready_dep = 4'b0000;
        for (i=0;i<4;i=i+1) begin
            if (valid_bits[i] && !issued_mask[i] &&
                ((raw_mask[i] & valid_bits) == 0))
                ready_dep[i] = 1'b1;
        end
    end

    // FU availability
    always @(*) begin
alu_free = 0;
mul_free = 0;
div_free = 0;

for (i = 0; i < MAX_FU; i = i + 1) begin
    if (i < ALU_COUNT && alu_busy[i] == 0)
        alu_free = alu_free + 1;

    if (i < MUL_COUNT && mul_busy[i] == 0)
        mul_free = mul_free + 1;

    if (i < DIV_COUNT && div_busy[i] == 0)
        div_free = div_free + 1;
end


        end
   

    // Dependence + FU binding
    always @(*) begin
        ready = 4'b0000;
        if (ready_dep[0] && alu_free > 0) ready[0] = 1'b1;
        if (ready_dep[1] && mul_free > 0) ready[1] = 1'b1;
        if (ready_dep[2] && alu_free > 0) ready[2] = 1'b1;
        if (ready_dep[3] && div_free > 0) ready[3] = 1'b1;
    end

    // Priority select
    always @(*) begin
        if      (ready[0]) sel = 4'b0001;
        else if (ready[1]) sel = 4'b0010;
        else if (ready[2]) sel = 4'b0100;
        else if (ready[3]) sel = 4'b1000;
        else               sel = 4'b0000;
    end

    assign issue_onehot = sch_enable ? sel : 4'b0000;

    // --------------------------------------------------------------
    // MAIN SEQUENTIAL BLOCK
    // --------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin

            raw_dyn <= 0;
            raw_init <= 0;
            issued_mask <= 0;
            retire_onehot <= 0;

            for (i=0;i<MAX_FU;i=i+1) begin
                alu_busy[i] <= 0; mul_busy[i] <= 0; div_busy[i] <= 0;
                nxt_alu_busy[i] <= 0; nxt_mul_busy[i] <= 0; nxt_div_busy[i] <= 0;
                fu_idx_alu[i] <= 0; fu_idx_mul[i] <= 0; fu_idx_div[i] <= 0;
            end

        end
        else begin

            retire_onehot <= 0;

            // ---------------------------
            // Initialize RAW once per window
            // ---------------------------
            if (!raw_init && sch_enable) begin
                raw_dyn <= raw_flat;
                raw_init <= 1;
            end

 // DECREMENT busy -> next-state (compute)
for (i=0;i<MAX_FU;i=i+1) begin
    nxt_alu_busy[i] = (alu_busy[i] > 0) ? alu_busy[i]-1 : 0;
    nxt_mul_busy[i] = (mul_busy[i] > 0) ? mul_busy[i]-1 : 0;
    nxt_div_busy[i] = (div_busy[i] > 0) ? div_busy[i]-1 : 0;
end

// COMPLETIONS (detect when next-state becomes zero but current was non-zero)
for (i=0;i<MAX_FU;i=i+1) begin
    if (i < ALU_COUNT && (nxt_alu_busy[i] == 0) && (alu_busy[i] != 0)) begin
        retire_onehot[ fu_idx_alu[i] ] <= 1'b1;
        raw_dyn[(fu_idx_alu[i]*4)+0] <= 0;
        raw_dyn[(fu_idx_alu[i]*4)+1] <= 0;
        raw_dyn[(fu_idx_alu[i]*4)+2] <= 0;
        raw_dyn[(fu_idx_alu[i]*4)+3] <= 0;
    end

    if (i < MUL_COUNT && (nxt_mul_busy[i] == 0) && (mul_busy[i] != 0)) begin
        retire_onehot[ fu_idx_mul[i] ] <= 1'b1;
        raw_dyn[(fu_idx_mul[i]*4)+0] <= 0;
        raw_dyn[(fu_idx_mul[i]*4)+1] <= 0;
        raw_dyn[(fu_idx_mul[i]*4)+2] <= 0;
        raw_dyn[(fu_idx_mul[i]*4)+3] <= 0;
    end

    if (i < DIV_COUNT && (nxt_div_busy[i] == 0) && (div_busy[i] != 0)) begin
        retire_onehot[ fu_idx_div[i] ] <= 1'b1;
        raw_dyn[(fu_idx_div[i]*4)+0] <= 0;
        raw_dyn[(fu_idx_div[i]*4)+1] <= 0;
        raw_dyn[(fu_idx_div[i]*4)+2] <= 0;
        raw_dyn[(fu_idx_div[i]*4)+3] <= 0;
    end
end

            // --------------------------------------------------
            // ISSUE ALLOCATION (AFTER COMPLETION)
            // --------------------------------------------------
            if (sch_enable && sel != 4'b0000) begin

                // decode index
                if      (sel[0]) idx_issue = 0;
                else if (sel[1]) idx_issue = 1;
                else if (sel[2]) idx_issue = 2;
                else             idx_issue = 3;

                issued_mask[idx_issue] <= 1'b1;

                // select FU
                pick = -1;

                case (idx_issue)

                    // ---------------- I0 -----------------
                    0: begin
                        if (opcode[0] == 2'b10) begin
                            for (i=0;i<MUL_COUNT;i=i+1)
                                if (pick==-1 && nxt_mul_busy[i]==0) pick=i;
                            if (pick!=-1) begin
                                nxt_mul_busy[pick] = MUL_LAT;
                                fu_idx_mul[pick] <= 0;
                                issued_fu_type <= 2'b01;
                                issued_fu_index <= pick[1:0];
                            end
                        end
                        else if (opcode[0] == 2'b11) begin
                            for (i=0;i<DIV_COUNT;i=i+1)
                                if (pick==-1 && nxt_div_busy[i]==0) pick=i;
                            if (pick!=-1) begin
                                nxt_div_busy[pick] = DIV_LAT;
                                fu_idx_div[pick] <= 0;
                                issued_fu_type <= 2'b10;
                                issued_fu_index <= pick[1:0];
                            end
                        end
                        else begin
                            for (i=0;i<ALU_COUNT;i=i+1)
                                if (pick==-1 && nxt_alu_busy[i]==0) pick=i;
                            if (pick!=-1) begin
                                nxt_alu_busy[pick] = ALU_LAT;
                                fu_idx_alu[pick] <= 0;
                                issued_fu_type <= 2'b00;
                                issued_fu_index <= pick[1:0];
                            end
                        end
                    end

                    // ---------------- I1 -----------------
                    1: begin
                        if (opcode[1] == 2'b10) begin
                            for (i=0;i<MUL_COUNT;i=i+1)
                                if (pick==-1 && nxt_mul_busy[i]==0) pick=i;
                            if (pick!=-1) begin
                                nxt_mul_busy[pick] = MUL_LAT;
                                fu_idx_mul[pick] <= 1;
                                issued_fu_type <= 2'b01;
                                issued_fu_index <= pick[1:0];
                            end
                        end
                        else if (opcode[1] == 2'b11) begin
                            for (i=0;i<DIV_COUNT;i=i+1)
                                if (pick==-1 && nxt_div_busy[i]==0) pick=i;
                            if (pick!=-1) begin
                                nxt_div_busy[pick] = DIV_LAT;
                                fu_idx_div[pick] <= 1;
                                issued_fu_type <= 2'b10;
                                issued_fu_index <= pick[1:0];
                            end
                        end
                        else begin
                            for (i=0;i<ALU_COUNT;i=i+1)
                                if (pick==-1 && nxt_alu_busy[i]==0) pick=i;
                            if (pick!=-1) begin
                                nxt_alu_busy[pick] = ALU_LAT;
                                fu_idx_alu[pick] <= 1;
                                issued_fu_type <= 2'b00;
                                issued_fu_index <= pick[1:0];
                            end
                        end
                    end

                    // ---------------- I2 -----------------
                    2: begin
                        if (opcode[2] == 2'b10) begin
                            for (i=0;i<MUL_COUNT;i=i+1)
                                if (pick==-1 && nxt_mul_busy[i]==0) pick=i;
                            if (pick!=-1) begin
                                nxt_mul_busy[pick] = MUL_LAT;
                                fu_idx_mul[pick] <= 2;
                                issued_fu_type <= 2'b01;
                                issued_fu_index <= pick[1:0];
                            end
                        end
                        else if (opcode[2] == 2'b11) begin
                            for (i=0;i<DIV_COUNT;i=i+1)
                                if (pick==-1 && nxt_div_busy[i]==0) pick=i;
                            if (pick!=-1) begin
                                nxt_div_busy[pick] = DIV_LAT;
                                fu_idx_div[pick] <= 2;
                                issued_fu_type <= 2'b10;
                                issued_fu_index <= pick[1:0];
                            end
                        end
                        else begin
                            for (i=0;i<ALU_COUNT;i=i+1)
                                if (pick==-1 && nxt_alu_busy[i]==0) pick=i;
                            if (pick!=-1) begin
                                nxt_alu_busy[pick] = ALU_LAT;
                                fu_idx_alu[pick] <= 2;
                                issued_fu_type <= 2'b00;
                                issued_fu_index <= pick[1:0];
                            end
                        end
                    end

                    // ---------------- I3 -----------------
                    3: begin
                        if (opcode[3] == 2'b10) begin
                            for (i=0;i<MUL_COUNT;i=i+1)
                                if (pick==-1 && nxt_mul_busy[i]==0) pick=i;
                            if (pick!=-1) begin
                                nxt_mul_busy[pick] = MUL_LAT;
                                fu_idx_mul[pick] <= 3;
                                issued_fu_type <= 2'b01;
                                issued_fu_index <= pick[1:0];
                            end
                        end
                        else if (opcode[3] == 2'b11) begin
                            for (i=0;i<DIV_COUNT;i=i+1)
                                if (pick==-1 && nxt_div_busy[i]==0) pick=i;
                            if (pick!=-1) begin
                                nxt_div_busy[pick] = DIV_LAT;
                                fu_idx_div[pick] <= 3;
                                issued_fu_type <= 2'b10;
                                issued_fu_index <= pick[1:0];
                            end
                        end
                        else begin
                            for (i=0;i<ALU_COUNT;i=i+1)
                                if (pick==-1 && nxt_alu_busy[i]==0) pick=i;
                            if (pick!=-1) begin
                                nxt_alu_busy[pick] = ALU_LAT;
                                fu_idx_alu[pick] <= 3;
                                issued_fu_type <= 2'b00;
                                issued_fu_index <= pick[1:0];
                            end
                        end
                    end

                endcase
            end

            // -------------------------------------------------------
            // COMMIT NEXT TO CURRENT
            // -------------------------------------------------------
            for (i=0;i<MAX_FU;i=i+1) begin
                alu_busy[i] <= nxt_alu_busy[i];
                mul_busy[i] <= nxt_mul_busy[i];
                div_busy[i] <= nxt_div_busy[i];
            end
        end
    end

    // --------------------------------------------------------------
    // ISSUE REPORTING
    // --------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            valid_out <= 0;
            issued_instr <= 0;
        end
        else begin
            valid_out <= (sch_enable && sel!=4'b0000);

            case(sel)
                4'b0001: issued_instr <= instr_flat[7:0];
                4'b0010: issued_instr <= instr_flat[15:8];
                4'b0100: issued_instr <= instr_flat[23:16];
                4'b1000: issued_instr <= instr_flat[31:24];
                default: issued_instr <= 0;
            endcase
        end
    end

endmodule
