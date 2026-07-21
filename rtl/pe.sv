module pe #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
)(
    input  logic                          clk,
    input  logic                          rst_n,  // active low reset (resets when reset is low)
    input  logic                          load_weight,
    input  logic signed [DATA_WIDTH-1:0]  weight_in,
    input  logic signed [DATA_WIDTH-1:0]  act_in,
    output logic signed [DATA_WIDTH-1:0]  act_out,
    input  logic signed [ACC_WIDTH-1:0]   psum_in,
    output logic signed [ACC_WIDTH-1:0]   psum_out
);


    logic signed [DATA_WIDTH-1:0] weight_reg;



    always_ff @(posedge clk) begin
        if (!rst_n) weight_reg <= 0;
        else if(load_weight) weight_reg <= weight_in;
        // else just keep weight_reg <= weight_reg
    end 


    // 2 stage design, multiply first, then add

    logic signed [(DATA_WIDTH*2)-1:0] prod_reg;
    logic signed [DATA_WIDTH-1:0] act_reg1, act_reg2;
    logic signed [ACC_WIDTH-1:0] psum_reg;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            prod_reg <= 0;
            act_reg1  <= 0;
            psum_reg <= 0;
        end else begin
            prod_reg <= weight_reg * act_in;
            act_reg1  <= act_in;
            psum_reg <= psum_in;
        end
    end

    logic signed [ACC_WIDTH-1:0] psum_out_reg;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            psum_out_reg <= 0;
            act_reg2 <= 0;
        end
        else begin
            psum_out_reg <= psum_reg + prod_reg;
            act_reg2 <= act_reg1;
        end
    end

    assign act_out = act_reg2;
    assign psum_out = psum_out_reg;



endmodule


