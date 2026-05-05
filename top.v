module TOP(
    input clk,

    inout ADC_SDA,
    output ADC_SCL,

    inout DAC_SDA,
    output DAC_SCL,

    input RST_BTN, //S2 ACTIVE LOW RESET

    output [2:0] LEDS
);


reg ADC_START = 0;
wire ADC_BUSY;
reg [15:0] ADC_IN;
reg [7:0] ADC_CONF; //0X00 TO READ, 0X01 TO INIT
reg ADC_OP;
wire [15:0] ADC_OUT;

I2C_MASTER ADC (
    .clk(clk),
    .rst_n(RST_BTN),        
    .start_bit(ADC_START), 
    .DATA_IN(ADC_IN),
    .TARGET_ADDR(7'h48), 
    .OP(ADC_OP),     
    .conf(ADC_CONF),     
    .SDA(ADC_SDA),
    .SCL(ADC_SCL),
    .DATA_OUT(ADC_OUT),
    .busy(ADC_BUSY)
);

reg [15:0] FIR_IN;
wire [15:0] FIR_OUT;
wire FIR_BUSY;
reg FIR_START = 0;

FIR_Filter FILTER (
    .clk(clk),
    .rst_n(RST_BTN),
    .in_adc(FIR_IN),
    .out_dac(FIR_OUT),
    .start(FIR_START),
    .busy(FIR_BUSY)
);

reg DAC_START;
reg [15:0]DAC_IN;
wire DAC_BUSY;

I2C_MASTER DAC (
    .clk(clk),
    .rst_n(RST_BTN),        
    .start_bit(DAC_START), 
    .DATA_IN(DAC_IN),
    .TARGET_ADDR(7'h60), 
    .OP(1'b0),     
    .conf(8'h40),     
    .SDA(DAC_SDA),
    .SCL(DAC_SCL),
    .DATA_OUT(),
    .busy(DAC_BUSY)
);

// State Machine Parameters
reg [3:0] STATE = 7; 
localparam INIT_W = 0, INIT_R = 1, INIT_DAC = 6, IDLE = 2, R_ADC = 3, FIR = 4, W_DAC = 5, POWER_ON_DELAY = 7;

reg [24:0] init_timer = 0; // Expanded to 25 bits to hold 27,000,000
assign LEDS = ~STATE;

reg STARTED;
reg [19:0] sample_timer = 0;

always @(posedge clk) begin
    if(!RST_BTN) begin
        STATE <= POWER_ON_DELAY; // Go to delay state on reset
        init_timer <= 0;
        ADC_OP <= 0;
        STARTED <= 0;
        ADC_START <= 0;
        DAC_START <= 0;
        FIR_START <= 0;
    end else begin
        case (STATE)

        DELAY: begin
            if(init_timer < 25'd27_000_000) begin
                init_timer <= init_timer + 1;
            end else begin
                STATE <= INIT_W;
                init_timer <= 0; 
            end
        end

        INIT_W: begin
            if(!STARTED) begin
                ADC_CONF <= 8'h01;
                ADC_IN <= 16'hC0E3; // AIN0 config
                ADC_START <= 1;
                if(ADC_BUSY) begin
                    STARTED <= 1;
                    ADC_START <= 0;
                end
            end else begin
                if(!ADC_BUSY) begin
                    STATE <= INIT_R;
                    STARTED <= 0;
                end   
            end
        end 

        INIT_R: begin
            if(!STARTED) begin
                ADC_OP <= 0;
                ADC_CONF <= 8'h00;
                ADC_IN <= 16'hAAAA;
                ADC_START <= 1;
                if(ADC_BUSY) begin
                    STARTED <= 1;
                    ADC_START <= 0;
                end
            end else begin
                if(!ADC_BUSY) begin
                    STATE <= INIT_DAC;
                    STARTED <= 0;
                    ADC_OP <= 1; // Set ADC to Read Mode for the rest of the program
                end   
            end
        end

        INIT_DAC: begin
            if(!STARTED) begin
                DAC_IN <= 16'd0; // Send 0 to the DAC
                DAC_START <= 1;
                if(DAC_BUSY) begin
                    STARTED <= 1;
                    DAC_START <= 0;
                end
            end else begin
                if(!DAC_BUSY) begin
                    STATE <= IDLE; // Initialization complete, move to loop
                    STARTED <= 0;
                end
            end
        end
                
        IDLE: begin
            if(ADC_START) ADC_START <= 0;
            
            // 20ms delay between samples (860 SPS ADC takes ~1.2ms to finish a reading)
            if(sample_timer < 20'd540_000) begin
                sample_timer <= sample_timer + 1;
            end else begin
                STATE <= R_ADC;
                sample_timer <= 0;
            end
        end

        R_ADC: begin
            if(!STARTED) begin
                if(!ADC_BUSY) begin
                    ADC_START <= 1;
                end else begin
                    STARTED <= 1;
                    ADC_START <= 0;
                end
            end else begin
                if(!ADC_BUSY) begin
                    STARTED <= 0;
                    FIR_IN <= ADC_OUT;
                    STATE <= FIR;
                end
            end
        end

        FIR: begin
            if(!STARTED) begin
                if(!FIR_BUSY) begin
                    FIR_START <= 1;
                end else begin
                    STARTED <= 1;
                    FIR_START <= 0;
                end
            end else begin
                if(!FIR_BUSY) begin
                    STARTED <= 0;
                    DAC_IN <= FIR_OUT;
                    STATE <= W_DAC;
                end
            end
        end

        W_DAC: begin
            if(!STARTED) begin
                if(!DAC_BUSY) begin
                    DAC_START <= 1;
                end else begin
                    STARTED <= 1;
                    DAC_START <= 0;
                end 
            end else begin
                if(!DAC_BUSY) begin
                    STARTED <= 0;
                    STATE <= IDLE; // Loop back to IDLE
                end
            end
        end
            
        endcase
    end 
end

endmodule