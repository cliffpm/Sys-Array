// =============================================================================
// tb_pe.sv - Directed testbench for the single PE (Phase 1)
// =============================================================================
`timescale 1ns/1ps

module tb_pe;

    localparam int DATA_WIDTH = 8;
    localparam int ACC_WIDTH  = 32;
    localparam time CLK_PERIOD = 10ns;

    logic clk;
    logic rst_n;
    logic load_weight;
    logic signed [DATA_WIDTH-1:0] weight_in;
    logic signed [DATA_WIDTH-1:0] act_in;
    logic signed [DATA_WIDTH-1:0] act_out;
    logic signed [ACC_WIDTH-1:0]  psum_in;
    logic signed [ACC_WIDTH-1:0]  psum_out;

    int pass_count = 0;
    int fail_count = 0;

    int f_arr[4];
    int past_arr[6];

    pe #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .load_weight(load_weight),
        .weight_in  (weight_in),
        .act_in     (act_in),
        .act_out    (act_out),
        .psum_in    (psum_in),
        .psum_out   (psum_out)
    );

    // Clock generation
   
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Reset task 
    task automatic apply_reset();
        rst_n       = 0; // remember active low reset
        load_weight = 0;
        weight_in   = '0;
        act_in      = '0;
        psum_in     = '0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    endtask

    // Load a weight into the PE 
    task automatic load_pe_weight(input logic signed [DATA_WIDTH-1:0] w);
        @(negedge clk);
        load_weight = 1;
        weight_in   = w;
        @(negedge clk);
        load_weight = 0;
    endtask





    //   1. Drive act_in = act_val, psum_in = psum_val for one cycle
    //   2. Wait the correct number of cycles for YOUR pipeline latency
    //      (this is the part you need to get right - use @(posedge clk)
    //      or @(negedge clk) the right number of times)
    //   3. Compare psum_out against expected_psum_out
    //   4. Print [PASS] or [FAIL] with the test name, increment
    //      pass_count/fail_count accordingly

    task automatic apply_and_check(
        input  logic signed [DATA_WIDTH-1:0] act_val,
        input  logic signed [ACC_WIDTH-1:0]  psum_val,
        input  logic signed [ACC_WIDTH-1:0]  expected_psum_out,
        input  string                        test_name
    );

        // act_in and psum_in are the logic wires we hooked up to the DUT, and we
        // are assigning them the values of the params. in this task
        act_in  = act_val;
        psum_in = psum_val;
        @(negedge clk);
        act_in = 0;
        psum_in = 0;

        

        repeat(1)@(negedge clk); // TODO: adjust this to match YOUR pipeline latency
        if (psum_out !== expected_psum_out) begin
            $display("[FAIL] %s: psum_out = %0d, expected = %0d", test_name, psum_out, expected_psum_out);
            fail_count++;
        end else begin
            $display("[PASS] %s: psum_out = %0d", test_name, psum_out);
            pass_count++;
        end

        if (act_out !== act_val) begin
            $display("[FAIL] %s: act_out = %0d, expected = %0d", test_name, act_out, act_val);
            fail_count++;
        end else begin
            $display("[PASS] %s: act_out = %0d", test_name, act_out);
            pass_count++;
        end

    endtask

  
    initial begin
        $display("========================================");
        $display(" PE Directed Testbench - Phase 1");
        $display("========================================");

        apply_reset();

        $display("basic_positive_mac");
        load_pe_weight(5);
        apply_and_check(3,0,15,"basic_positive_mac");
        

        $display("accumulate_nonzero_psum");
        apply_and_check(4,100,120,"accumulate_nonzero_psum");

        $display("negative_activation");
        apply_and_check(-3,0,-15,"negative_activation");

        $display("negative_weight");
        load_pe_weight(-7);
        apply_and_check(6,0,-42, "negative_weight");

        $display("neg_times_neg");
        apply_and_check(-6,0,42,"neg_times_neg");

        $display("max_magnitude_operands");
        load_pe_weight(-128);
        apply_and_check(-128,0,16384,"max_magnitude_operands");

        $display("zero_weight_passthrough");
        load_pe_weight(0);
        apply_and_check(127,500,500,"zero_weight_passthrough");

        $display("zero_activation_passthrough");
        load_pe_weight(9);
        apply_and_check(0,77,77, "zero_activation_passthrough");
        

        // continous act_in flow checks

        repeat(5)@(negedge clk); // wait a few cycles to let the pipeline drain

        // int f_arr[4] = '{10,20,30,40};
        // int past_arr[6] = '{0,0,10,20,30,40};

        f_arr[0] = 10;
        f_arr[1] = 20;
        f_arr[2] = 30;
        f_arr[3] = 40;

        past_arr[0] = 0;
        past_arr[1] = 0;
        past_arr[2] = 10;
        past_arr[3] = 20;
        past_arr[4] = 30;
        past_arr[5] = 40;

        for (int i = 0; i < 6; i++) begin
            if (i < 4) act_in = f_arr[i];

            if (i > 1) begin
                if (act_out != past_arr[i]) begin
                    $display("[FAIL] continuous_act_in_flow: act_out = %0d, expected = %0d", act_out, past_arr[i]);
                    fail_count++;
                end else begin
                    $display("[PASS] continuous_act_in_flow: act_out = %0d", act_out);
                    pass_count++;
                end

            end



            @(negedge clk);
        end 




        // -------------------------------------------------------------------
        $display("========================================");
        $display(" RESULTS: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================");

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED - see log above");

        $finish;
    end

    // -------------------------------------------------------------------
    // Waveform dump (given)
    // -------------------------------------------------------------------
    initial begin
        $dumpfile("pe_wave.vcd");
        $dumpvars(0, tb_pe);
    end

    // Safety timeout
    initial begin
        #10000;
        $display("[TIMEOUT] Testbench did not finish in time");
        $finish;
    end

endmodule