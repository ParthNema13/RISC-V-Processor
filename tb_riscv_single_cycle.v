`timescale 1ns/1ps
// ============================================================
// Testbench for the single-cycle RISC-V processor
// Runs the preloaded program and checks registers + memory.
// ============================================================
module tb_riscv_single_cycle;
    reg clk = 0;
    reg rst = 1;
    integer errors = 0;

    riscv_single_cycle dut (
        .clk (clk),
        .rst (rst)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    // Check one register value and report PASS/FAIL
    task check_reg;
        input integer r;
        input [31:0]  expected;
        begin
            if (dut.rf.regs[r] !== expected) begin
                errors = errors + 1;
                $display("FAIL: x%0d = %0d, expected %0d", r, dut.rf.regs[r], expected);
            end else begin
                $display("PASS: x%0d = %0d", r, dut.rf.regs[r]);
            end
        end
    endtask

    initial begin
        $dumpfile("riscv_single_cycle.vcd");   // waveform file for viewing
        $dumpvars(0, tb_riscv_single_cycle);

        // Reset for two clock edges
        @(posedge clk);
        @(posedge clk);
        rst = 0;

        // Let the 12-instruction program run
        repeat (30) @(posedge clk);
        #1;

        $display("---- Register checks ----");
        check_reg(1, 5);    // ADDI
        check_reg(2, 10);   // ADDI
        check_reg(3, 15);   // ADD
        check_reg(4, 5);    // SUB
        check_reg(5, 15);   // LW
        check_reg(6, 0);    // Skipped by BEQ -> must stay 0
        check_reg(7, 99);   // ADDI after branch
        check_reg(8, 0);    // AND
        check_reg(9, 15);   // OR

        $display("---- Memory checks ----");
        if (dut.dm.mem[0] !== 32'd15) begin
            errors = errors + 1;
            $display("FAIL: mem[0] = %0d, expected 15", dut.dm.mem[0]);
        end else
            $display("PASS: mem[0] = %0d", dut.dm.mem[0]);

        if (errors == 0)
            $display("==> ALL TESTS PASSED");
        else
            $display("==> %0d TEST(S) FAILED", errors);

        $finish;
    end
endmodule
