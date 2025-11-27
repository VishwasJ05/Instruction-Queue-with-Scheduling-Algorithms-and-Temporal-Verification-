`timescale 1ns/1ps
module tb_debug_phase5;

    reg clk, reset, enqueue;
    reg [7:0] instr_in;

    wire [7:0] issued_instr;
    wire       valid_out;
    wire [3:0] issued_flags;
    wire       full, empty;

    wire [31:0] instr_flat;
    wire [3:0]  valid_bits;
    wire [15:0] raw_flat, war_flat, waw_flat, dep_flat;
    wire [3:0]  dag_ready;
    wire [1:0]  fu_type, fu_idx;
    wire [3:0]  retire_onehot;

    integer retire_count;   // <-- REQUIRED FIX

    top_integrated dut(
        .clk(clk), .reset(reset),
        .enqueue(enqueue), .instr_in(instr_in),
        .issued_instr(issued_instr), .valid_out(valid_out),
        .issued_flags(issued_flags), .full(full), .empty(empty),
        .dbg_instr_flat(instr_flat), .dbg_valid_bits(valid_bits),
        .dbg_raw_flat(raw_flat), .dbg_war_flat(war_flat),
        .dbg_waw_flat(waw_flat), .dbg_dep_flat(dep_flat),
        .dbg_scheduler_ready(dag_ready),
        .dbg_issued_fu_type(fu_type),
        .dbg_issued_fu_index(fu_idx)
    );

    // retirement comes from scheduler instance
    assign retire_onehot = dut.sch.retire_onehot;

    //---------------------------------------------------------
    // CLOCK
    //---------------------------------------------------------
    initial begin 
        clk = 0;
        forever #5 clk = ~clk; 
    end

    //---------------------------------------------------------
    // PRINT MATRIX TASK
    //---------------------------------------------------------
    task print_matrix(input [15:0] M);
        integer i, j;
        begin
            for(i=0; i<4; i=i+1) begin
                for(j=0; j<4; j=j+1)
                    $write("%0d ", M[i*4+j]);
                $write("\n");
            end
        end
    endtask

    //---------------------------------------------------------
    // COUNT RETIRES
    //---------------------------------------------------------
    always @(posedge clk) begin
        if (retire_onehot != 4'b0000)
            retire_count <= retire_count + 1;
    end

    //---------------------------------------------------------
    // MAIN TEST
    //---------------------------------------------------------
    integer c;

    initial begin
        reset = 1;
        enqueue = 0;
        instr_in = 0;
        retire_count = 0;      // IMPORTANT
        #20 reset = 0;

        //-----------------------------------------------------
        // PHASE-1 : ENQUEUE 4 INSTRUCTIONS
        //-----------------------------------------------------
        $display("\n=======================");
        $display("===== PHASE-1 : INSTRUCTION QUEUE =====");
        $display("=======================\n");

// SET 1
        @(posedge clk); enqueue=1; instr_in = 8'b00_01_10_11; // I0
        @(posedge clk);            instr_in = 8'b10_11_00_01; // I1
        @(posedge clk);            instr_in = 8'b01_01_10_00; // I2
        @(posedge clk);            instr_in = 8'b11_10_11_01; // I3
        @(posedge clk); enqueue = 0;


// SET 2
//     @(posedge clk); enqueue=1; instr_in = 8'b00_00_00_01; // I0
//@(posedge clk);            instr_in = 8'b00_01_10_01; // I1
//@(posedge clk);            instr_in = 8'b10_01_00_10; // I2
//@(posedge clk);            instr_in = 8'b11_01_11_11; // I3
//@(posedge clk); enqueue = 0;


// SET 3
//@(posedge clk); enqueue=1; instr_in = 8'b10_00_01_10; // I0: MUL  src0=R0 src1=R1 -> dest=R2
//@(posedge clk);            instr_in = 8'b00_10_00_11; // I1: ALU  src0=R2 src1=R0 -> dest=R3
//@(posedge clk);            instr_in = 8'b11_11_10_01; // I2: DIV  src0=R3 src1=R2 -> dest=R1
//@(posedge clk);            instr_in = 8'b00_01_11_00; // I3: ALU  src0=R1 src1=R3 -> dest=R0
//@(posedge clk); enqueue = 0;



        #2;
        $display("I0=%b  I1=%b  I2=%b  I3=%b",
                instr_flat[7:0], instr_flat[15:8],
                instr_flat[23:16], instr_flat[31:24]);
        $display("VALID_BITS=%b FULL=%b EMPTY=%b\n",
                valid_bits, full, empty);

$display("\n===== PHASE-2 : DAG (Compact) =====");

$display("RAW: %0d%0d%0d%0d  %0d%0d%0d%0d  %0d%0d%0d%0d  %0d%0d%0d%0d",
    raw_flat[0],raw_flat[1],raw_flat[2],raw_flat[3],
    raw_flat[4],raw_flat[5],raw_flat[6],raw_flat[7],
    raw_flat[8],raw_flat[9],raw_flat[10],raw_flat[11],
    raw_flat[12],raw_flat[13],raw_flat[14],raw_flat[15]);

$display("WAR: %0d%0d%0d%0d  %0d%0d%0d%0d  %0d%0d%0d%0d  %0d%0d%0d%0d",
    war_flat[0],war_flat[1],war_flat[2],war_flat[3],
    war_flat[4],war_flat[5],war_flat[6],war_flat[7],
    war_flat[8],war_flat[9],war_flat[10],war_flat[11],
    war_flat[12],war_flat[13],war_flat[14],war_flat[15]);

$display("WAW: %0d%0d%0d%0d  %0d%0d%0d%0d  %0d%0d%0d%0d  %0d%0d%0d%0d",
    waw_flat[0],waw_flat[1],waw_flat[2],waw_flat[3],
    waw_flat[4],waw_flat[5],waw_flat[6],waw_flat[7],
    waw_flat[8],waw_flat[9],waw_flat[10],waw_flat[11],
    waw_flat[12],waw_flat[13],waw_flat[14],waw_flat[15]);

$display("DEP: %0d%0d%0d%0d  %0d%0d%0d%0d  %0d%0d%0d%0d  %0d%0d%0d%0d",
    dep_flat[0],dep_flat[1],dep_flat[2],dep_flat[3],
    dep_flat[4],dep_flat[5],dep_flat[6],dep_flat[7],
    dep_flat[8],dep_flat[9],dep_flat[10],dep_flat[11],
    dep_flat[12],dep_flat[13],dep_flat[14],dep_flat[15]);

$display("READY=%b\n", dag_ready);


        //-----------------------------------------------------
        // PHASE-3+4+5 : SCHEDULING + RETIRE
        //-----------------------------------------------------
        $display("\n=======================");
        $display("===== PHASE-3+4+5 : SCHEDULER =====");
        $display("=======================\n");

        c = 0;
        while (retire_count < 4 && c < 500) begin
            @(posedge clk);

            if(valid_out)
                $display("[ISSUE ] T=%0t  instr=%b  FU=%0d  futype=%0d",
                          $time, issued_instr, fu_idx, fu_type);

            if(retire_onehot != 0)
                $display("[RETIRE] T=%0t  retire=%b", $time, retire_onehot);

            c = c + 1;
        end

        $display("\n===== END OF SIMULATION =====\n");
        $finish;
    end

endmodule
