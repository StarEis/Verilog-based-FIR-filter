module top(
    input btn1,
    input btn2,
    input clk,
    inout wire SDA,
    output wire SCL
);

    reg btn1_d, btn1_d2;
    wire start_pulse;

    always @(posedge clk) begin
        btn1_d <= ~btn1;      
        btn1_d2 <= btn1_d;    
    end

    assign start_pulse = btn1_d & ~btn1_d2; 

    I2C_MASTER DUT (
        .clk(clk),
        .rst_n(btn2),        
        .start_bit(start_pulse), 
        .DATA_IN(16'd1023),
        .TARGET_ADDR(7'h60), 
        .OP(1'b0),     
        .conf(8'h40),     
        .SDA(SDA),
        .SCL(SCL),
        .DATA_OUT()
    );
endmodule