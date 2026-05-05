module I2C_MASTER (
    input clk,  //tang nano 9k 27MHz clk
    input rst_n,    //synchronous active low reset
    input start_bit,    //flag (?) to start the communication
    input [15:0] DATA_IN,   //data that will be written down if OP = 0
    input [6:0] TARGET_ADDR,    //address of the device 7'h60 for DAC, for ADC when put to ground 7'h48
    input OP,   //operation: 0 for write 1 for read
    input [7:0]conf,    // 8'h40 for DAC, 8'h01 for ADC 
    inout wire SDA, 
    output reg SCL,
    output reg [15:0] DATA_OUT,  //data read from sensor/module
    output wire busy //this flas is used to know when I2C master is busy
);
    /* 
    sda_out is used to achieve this tri-state that is necessary for input/output
    from my understand when we pull the SDA to z (high impedance i believe) it is effectively leaving it up for grabs
    when it is up for grabs other devices can drive it themselves
    in this case when the master sets sda_out to 1 meaning they are waiting for a response from the slave
    the slave uses this opportunity to send the ACK/NACK signal to the master
    */

    reg sda_out = 1;
    assign SDA = (sda_out == 1'b0) ? 1'b0 : 1'bz;
    

    reg [2:0] state = 0; //2 < log2(5) < 3
    localparam IDLE = 0, START = 1, PROCESS_BYTE = 2, ACK = 3, STOP = 4;

    reg [8:0] clk_cnt = 0;  //used to count posedge of clk to change the match the frequency of master with slave, 8 < log2(270) < 9 
    reg [7:0] byte_to_send = 0; //one byte of data to be written down
    reg [2:0] bit_cnt = 0;  //bit counter to remember which bit we are at in a byte
    reg [1:0] ack_byte = 0; //to reduce the states need only one ACK is used along with these 2 bits, 0=ADDR, 1=CMD, 2=DATA_H, 3=DATA_L
    reg nack_error; //error flag for when slave does not acknowledge data

    localparam SPEED_LIMIT = 9'd67; //27M/400k = 67.5 ≈ 67, minus one as we start from 0
    localparam HALF_SPEED  = 9'd33; //67 / 2 = 33.5 ≈ 33

    assign busy = (state != IDLE); //if we are not idle raise busy flag

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= 0;
            clk_cnt <= 0;
            byte_to_send <= 0;
            ack_byte <= 0;
            SCL <= 1;
            sda_out <= 1;
            nack_error <= 0;
            DATA_OUT <= 0;
        end else begin
            case (state)
                IDLE: begin 
                    /*
                    waiting until the begin flag is recieved
                    scl is pulled high and sda is pulled to z to signify that we are not operating
                    when flag is recieved we go to start state and reset clk_cnt
                    */
                    SCL <= 1;
                    sda_out <= 1;
                    if(start_bit) begin
                        state <= START;
                        clk_cnt <= 0;
                    end
                end

                START: begin 
                    /*
                    now that we have recieved the flag to start
                    we wait one clk and then check whether sda out has been pulled to 1 by the slave or not
                    if it has we pull it to zero and then next clk we set scl to zero to start the clk between master and slave 
                    we also initialize the address data to be sent along with OP
                    */
                    clk_cnt <= clk_cnt + 1;
                    if (clk_cnt == SPEED_LIMIT) begin
                        clk_cnt <= 0;
                        if(sda_out == 1) begin
                            sda_out <= 0;
                        end else if (sda_out == 0) begin
                            SCL <= 0;
                            state <= PROCESS_BYTE;
                            byte_to_send <= {TARGET_ADDR, OP};
                            bit_cnt <= 7;
                        end
                    end
                end 
                 
                PROCESS_BYTE: begin
                    /*
                    here we "process" the byte deciding whether to read a byte or write a byte
                    as we first need to send the address we always first write
                    afterwards the action depends of the OP bit

                    one concern is whether I should have the read/write if conditions inside the clk_cnt if conditions
                    i think it won't matter because unlike software the check is just a wire rather than checking bit by bit
                    */

                    clk_cnt <= clk_cnt + 1;

                    if (~OP || ack_byte == 0) begin //write

                        if (clk_cnt == 0) begin //set sda to the output we want to give
                            sda_out <= byte_to_send[bit_cnt];
                        end
                        
                        if(clk_cnt == HALF_SPEED) begin // posedge of SCL
                            SCL <= 1;
                        end

                        if(clk_cnt == SPEED_LIMIT) begin //negedge of SCL
                            clk_cnt <= 0;
                            SCL <= 0;
                            if(bit_cnt == 0) begin
                                state <= ACK;
                            end else begin //decrease bit_cnt and repeat 7 more times
                                bit_cnt <= bit_cnt - 1;
                            end
                        end

                    end else if (OP && ack_byte > 0) begin  //read
                        if (clk_cnt == 0) begin 
                            sda_out <= 1;
                        end
                        
                        if(clk_cnt == HALF_SPEED) begin //we decide of which parts of our output we need to read here
                            SCL <= 1;
                            if (ack_byte == 1) begin 
                                DATA_OUT[bit_cnt + 8] <= SDA; 
                            end else if (ack_byte == 2) begin
                                DATA_OUT[bit_cnt] <= SDA;
                            end
                        end

                        if(clk_cnt == SPEED_LIMIT) begin //transition to ack / looping to read more bits
                            clk_cnt <= 0;
                            SCL <= 0;
                            if(bit_cnt == 0) begin
                                state <= ACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1;
                            end
                        end
                    end
                end

                ACK: begin
                    /*
                    here we acknowledge that the operation has been done and received or recieve confirmation
                    */
                    clk_cnt <= clk_cnt +1;
                    if (~OP || ack_byte == 0) begin

                        if (clk_cnt == 0) begin
                            if (OP && ack_byte > 0) begin
                                if (ack_byte == 1) sda_out <= 0; // ACK the 1st byte
                                else               sda_out <= 1; // NACK the 2nd byte
                            end else begin
                                // Otherwise, release bus to listen for Slave's ACK
                                sda_out <= 1;
                            end
                        end

                        if (clk_cnt == HALF_SPEED) begin
                            SCL <= 1;
                            if (SDA == 1) begin
                                nack_error <= 1;
                            end
                        end

                        if (clk_cnt == SPEED_LIMIT) begin
                            SCL <= 0;
                            clk_cnt <= 0;
                            ack_byte <= ack_byte + 1;
                            /*
                            0 is for sending the adress and op bits
                            1 and 2 is for sending 16 bits to the device (we need 12 for our DAC)
                            */
                            case (ack_byte)
                                0: begin 
                                    state <= PROCESS_BYTE;
                                    byte_to_send <= conf; 
                                    bit_cnt <= 7;
                                end
                                1: begin 
                                    state <= PROCESS_BYTE;
                                    byte_to_send <= DATA_IN[15:8]; 
                                    bit_cnt <= 7;
                                end
                                2: begin 
                                    state <= PROCESS_BYTE;
                                    byte_to_send <= DATA_IN[7:0]; 
                                    bit_cnt <= 7;
                                end
                                3: begin 
                                    state <= STOP;
                                    ack_byte <= 0; 
                                end
                            endcase

                            if(nack_error) begin
                                state <= STOP;
                                nack_error <= 0;
                                ack_byte <= 0;
                            end
                        end
                    end else if (OP && ack_byte > 0) begin
                        if (clk_cnt == 0) begin
                            if (ack_byte == 1) begin 
                                sda_out <= 0; 
                            end else begin
                                sda_out <= 1;
                            end
                        end

                        if (clk_cnt == HALF_SPEED) begin
                            SCL <= 1;
                        end

                        if (clk_cnt == SPEED_LIMIT) begin
                            SCL <= 0;
                            clk_cnt <= 0;
                            ack_byte <= ack_byte + 1;
                            /*
                            from my ADC I need to read 16 bits/2 bytes of data
                            when ack_byte == 0, from the ack state we increase it to one and got back to process byte
                            as ack_byte == 1 then this time we read one byte and come back to ack and this time get in this conditional block
                            this time ack_byte is incremented by one and case 1 is used meaning we get one more byte
                            then we transition to stop as we got our read data.  
                            */
                            case (ack_byte)
                                1: begin 
                                    state <= PROCESS_BYTE;
                                    bit_cnt <= 7;
                                end

                                2: begin 
                                    state <= STOP; 
                                    ack_byte <= 0;
                                end
                            endcase
                        end
                    end
                end

                STOP: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if(clk_cnt == 0) begin
                        sda_out <= 0; 
                        SCL <= 0;
                    end
                    if(clk_cnt == HALF_SPEED) SCL <= 1;

                    if(clk_cnt == SPEED_LIMIT) begin 
                        sda_out <= 1; 
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
    
endmodule