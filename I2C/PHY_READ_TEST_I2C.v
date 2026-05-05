module top(
    input btn1,
    input btn2,
    input clk,
    inout wire SDA,
    output wire SCL,
    output [5:0] leds
);
    wire rst_n = btn1;

    reg start_bit;
    reg [6:0] target_addr;
    reg op;
    reg [7:0] conf_byte;
    reg [15:0] data_in;
    wire [15:0] data_out;

    I2C_MASTER DUT (
        .clk(clk),
        .rst_n(rst_n),        
        .start_bit(start_bit), 
        .DATA_IN(data_in),
        .TARGET_ADDR(target_addr), 
        .OP(op),     
        .conf(conf_byte),     
        .SDA(SDA),
        .SCL(SCL),
        .DATA_OUT(data_out)
    );

    assign led = ~data_out[15:10];

    reg [1:0] main_state;
    reg prev_btn;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_bit <= 0;
            target_addr <= 7'h48; 
            op <= 1;              
            conf_byte <= 8'h00;
            main_state <= 0;
        end else begin
            prev_btn <= btn2;
            
            case (main_state)
                0: begin 
                    start_bit <= 0;
                    if (prev_btn == 1 && btn2 == 0) begin 
                        main_state <= 1;
                    end
                end
                
                1: begin
                    target_addr <= 7'h48;
                    op <= 1;        
                    conf_byte <= 8'h00; 
                    start_bit <= 1; 
                    main_state <= 2;
                end
                
                2: begin 
                     start_bit <= 0;
                     main_state <= 0; 
                end
            endcase
        end
    end

endmodule