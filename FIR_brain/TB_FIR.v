`timescale 1ns/1ps

module TB_FIR ();
    
    reg clk = 0;
    always #5 clk = ~clk; //100M Hz 

    reg rst_n = 0;
    reg signed [15:0] in_adc;
    wire [11:0] out_dac;
    
    FIR_Filter DUT (
        .clk(clk),
        .rst_n(rst_n),
        .in_adc(in_adc),
        .out_dac(out_dac)
    );

    initial begin
        $dumpfile("FIR_waveform.vcd");
        $dumpvars(0, TB_FIR);

        @(negedge clk);
        rst_n = 1; in_adc = 16'b0111111111111111;
        @(negedge clk);
        in_adc = 16'd0;
        repeat (101) @(negedge clk);

        #10 $stop;
    end
endmodule