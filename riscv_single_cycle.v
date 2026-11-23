// ============================================================
// 32-bit Single-Cycle RISC-V Processor (RV32I subset)
// Supported instructions: ADD, SUB, AND, OR, ADDI, LW, SW, BEQ
// ============================================================

// ---------- Program Counter + top-level datapath ----------
module riscv_single_cycle (
    input clk,
    input rst
);
    reg  [31:0] pc;

    wire [31:0] pc_plus4 = pc + 32'd4;
    wire [31:0] instr;

    // Instruction fields
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire       funct7_5 = instr[30];

    // Control signals
    wire       reg_write, alu_src, mem_read, mem_write, mem_to_reg, branch;
    wire [1:0] alu_op;
    wire [3:0] alu_ctrl;

    // Datapath wires
    wire [31:0] imm, rd1, rd2, alu_b, alu_result, mem_rdata, wb_data;
    wire [31:0] branch_target, pc_next;
    wire        zero;

    // 1. Fetch
    imem im (
        .addr  (pc),
        .instr (instr)
    );

    // 2. Decode / control
    control_unit cu (
        .opcode    (opcode),
        .reg_write (reg_write),
        .alu_src   (alu_src),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .mem_to_reg(mem_to_reg),
        .branch    (branch),
        .alu_op    (alu_op)
    );

    imm_gen ig (
        .instr (instr),
        .imm   (imm)
    );

    regfile rf (
        .clk (clk),
        .we  (reg_write),
        .rs1 (rs1),
        .rs2 (rs2),
        .rd  (rd),
        .wd  (wb_data),
        .rd1 (rd1),
        .rd2 (rd2)
    );

    // 3. Execute
    alu_control ac (
        .alu_op   (alu_op),
        .funct3   (funct3),
        .funct7_5 (funct7_5),
        .alu_ctrl (alu_ctrl)
    );

    assign alu_b = alu_src ? imm : rd2;   // choose register or immediate

    alu alu_u (
        .a          (rd1),
        .b          (alu_b),
        .alu_ctrl   (alu_ctrl),
        .result     (alu_result),
        .zero       (zero)
    );

    // 4. Memory
    dmem dm (
        .clk   (clk),
        .we    (mem_write),
        .addr  (alu_result),
        .wd    (rd2),
        .rdata (mem_rdata)
    );

    // 5. Write back
    assign wb_data = mem_to_reg ? mem_rdata : alu_result;

    // 6. Next PC
    assign branch_target = pc + imm;
    assign pc_next = (branch & zero) ? branch_target : pc_plus4;

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'd0;
        else
            pc <= pc_next;
    end
endmodule


// ---------- Instruction memory (program is preloaded here) ----------
module imem (
    input  [31:0] addr,
    output [31:0] instr
);
    reg [31:0] mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'h00000013;          // NOP (addi x0, x0, 0)

        mem[0]  = 32'h00500093;  // addi x1, x0, 5
        mem[1]  = 32'h00A00113;  // addi x2, x0, 10
        mem[2]  = 32'h002081B3;  // add  x3, x1, x2   -> 15
        mem[3]  = 32'h40110233;  // sub  x4, x2, x1   -> 5
        mem[4]  = 32'h0020F433;  // and  x8, x1, x2   -> 0
        mem[5]  = 32'h0020E4B3;  // or   x9, x1, x2   -> 15
        mem[6]  = 32'h00302023;  // sw   x3, 0(x0)    -> mem[0] = 15
        mem[7]  = 32'h00002283;  // lw   x5, 0(x0)    -> x5 = 15
        mem[8]  = 32'h00518463;  // beq  x3, x5, +8   (equal, so jump)
        mem[9]  = 32'h00100313;  // addi x6, x0, 1    (SKIPPED)
        mem[10] = 32'h06300393;  // addi x7, x0, 99   -> 99
        mem[11] = 32'h00000063;  // beq  x0, x0, 0    (halt loop)
    end

    assign instr = mem[addr[9:2]];   // word-aligned access
endmodule


// ---------- Register file: 32 x 32-bit, x0 is always zero ----------
module regfile (
    input         clk,
    input         we,
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [4:0]  rd,
    input  [31:0] wd,
    output [31:0] rd1,
    output [31:0] rd2
);
    reg [31:0] regs [0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'd0;
    end

    // Asynchronous (combinational) reads; x0 reads as 0
    assign rd1 = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

    // Synchronous write on the rising clock edge; writes to x0 are ignored
    always @(posedge clk) begin
        if (we && (rd != 5'd0))
            regs[rd] <= wd;
    end
endmodule


// ---------- Immediate generator ----------
module imm_gen (
    input  [31:0] instr,
    output reg [31:0] imm
);
    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            7'b0100011: // S-type (SW)
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            7'b1100011: // B-type (BEQ)
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            default:    // I-type (ADDI, LW)
                imm = {{20{instr[31]}}, instr[31:20]};
        endcase
    end
endmodule


// ---------- Main control unit ----------
module control_unit (
    input  [6:0] opcode,
    output reg   reg_write,
    output reg   alu_src,
    output reg   mem_read,
    output reg   mem_write,
    output reg   mem_to_reg,
    output reg   branch,
    output reg [1:0] alu_op
);
    always @(*) begin
        // Default: everything off
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        branch     = 1'b0;
        alu_op     = 2'b00;

        case (opcode)
            7'b0110011: begin // R-type: ADD, SUB, AND, OR
                reg_write = 1'b1;
                alu_op    = 2'b10;
            end
            7'b0010011: begin // I-type: ADDI
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b00;
            end
            7'b0000011: begin // LW
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                alu_op     = 2'b00;
            end
            7'b0100011: begin // SW
                alu_src   = 1'b1;
                mem_write = 1'b1;
                alu_op    = 2'b00;
            end
            7'b1100011: begin // BEQ
                branch = 1'b1;
                alu_op = 2'b01;
            end
            default: ;
        endcase
    end
endmodule


// ---------- ALU control: turns alu_op + funct fields into an ALU operation ----------
module alu_control (
    input  [1:0] alu_op,
    input  [2:0] funct3,
    input        funct7_5,
    output reg [3:0] alu_ctrl
);
    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0010;          // ADD (for ADDI, LW, SW)
            2'b01: alu_ctrl = 4'b0110;          // SUB (for BEQ)
            default: begin                      // R-type: look at funct3/funct7
                case (funct3)
                    3'b000: alu_ctrl = funct7_5 ? 4'b0110 : 4'b0010; // SUB : ADD
                    3'b110: alu_ctrl = 4'b0001; // OR
                    3'b111: alu_ctrl = 4'b0000; // AND
                    default: alu_ctrl = 4'b0010;
                endcase
            end
        endcase
    end
endmodule


// ---------- ALU ----------
module alu (
    input  [31:0] a,
    input  [31:0] b,
    input  [3:0]  alu_ctrl,
    output reg [31:0] result,
    output        zero
);
    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = a & b;   // AND
            4'b0001: result = a | b;   // OR
            4'b0010: result = a + b;   // ADD
            4'b0110: result = a - b;   // SUB
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);
endmodule


// ---------- Data memory: 256 words ----------
module dmem (
    input         clk,
    input         we,
    input  [31:0] addr,
    input  [31:0] wd,
    output [31:0] rdata
);
    reg [31:0] mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'd0;
    end

    assign rdata = mem[addr[9:2]];     // LW: asynchronous read

    always @(posedge clk) begin
        if (we)
            mem[addr[9:2]] <= wd;      // SW: synchronous write
    end
endmodule
