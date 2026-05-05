module FIR_Filter #(
    parameter TAPS = 51
)(
    input clk,
    input rst_n,
    input signed [15:0] in_adc,
    output reg [15:0] out_dac,

    input start,
    output wire busy
);

reg [1:0] STATE;
localparam IDLE = 0, S_DATA = 1, CALC = 2;
reg [5:0] calc_count;

assign busy = (STATE != IDLE);

reg signed [15:0] values [TAPS-1:0];
reg signed [38:0] sum;

function signed [15:0] get_coeff;
    input [5:0] idx;
    case(idx)
        6'd0:  get_coeff = 16'd112;
        6'd1:  get_coeff = 16'd124;
        6'd2:  get_coeff = 16'd148;
        6'd3:  get_coeff = 16'd185;
        6'd4:  get_coeff = 16'd236;
        6'd5:  get_coeff = 16'd302;
        6'd6:  get_coeff = 16'd383;
        6'd7:  get_coeff = 16'd480;
        6'd8:  get_coeff = 16'd591;
        6'd9:  get_coeff = 16'd716;
        6'd10: get_coeff = 16'd854;
        6'd11: get_coeff = 16'd1001;
        6'd12: get_coeff = 16'd1157;
        6'd13: get_coeff = 16'd1319;
        6'd14: get_coeff = 16'd1483;
        6'd15: get_coeff = 16'd1648;
        6'd16: get_coeff = 16'd1809;
        6'd17: get_coeff = 16'd1963;
        6'd18: get_coeff = 16'd2108;
        6'd19: get_coeff = 16'd2241;
        6'd20: get_coeff = 16'd2359;
        6'd21: get_coeff = 16'd2458;
        6'd22: get_coeff = 16'd2538;
        6'd23: get_coeff = 16'd2597;
        6'd24: get_coeff = 16'd2632;
        6'd25: get_coeff = 16'd2644;
        6'd26: get_coeff = 16'd2632;
        6'd27: get_coeff = 16'd2597;
        6'd28: get_coeff = 16'd2538;
        6'd29: get_coeff = 16'd2458;
        6'd30: get_coeff = 16'd2359;
        6'd31: get_coeff = 16'd2241;
        6'd32: get_coeff = 16'd2108;
        6'd33: get_coeff = 16'd1963;
        6'd34: get_coeff = 16'd1809;
        6'd35: get_coeff = 16'd1648;
        6'd36: get_coeff = 16'd1483;
        6'd37: get_coeff = 16'd1319;
        6'd38: get_coeff = 16'd1157;
        6'd39: get_coeff = 16'd1001;
        6'd40: get_coeff = 16'd854;
        6'd41: get_coeff = 16'd716;
        6'd42: get_coeff = 16'd591;
        6'd43: get_coeff = 16'd480;
        6'd44: get_coeff = 16'd383;
        6'd45: get_coeff = 16'd302;
        6'd46: get_coeff = 16'd236;
        6'd47: get_coeff = 16'd185;
        6'd48: get_coeff = 16'd148;
        6'd49: get_coeff = 16'd124;
        6'd50: get_coeff = 16'd112;
        default: get_coeff = 16'd0;
    endcase
endfunction

// Combinatorial multiply: values[] is a registered array (safe),
// get_coeff() is a pure LUT (safe). Result is 32 bits, sign-extended
// into the 39-bit accumulator by the <= assignment.
wire signed [31:0] mult_result = $signed(values[calc_count]) * get_coeff(calc_count);

// Arithmetic right-shift to scale 15-bit ADC result down to 12-bit DAC range.
// Max sum ≈ 17580 * 65532 ≈ 1.15e9, fits in 31 bits. After >>> 19: ≈ 2197, fits in 12 bits.
wire signed [15:0] shifted = sum >>> 18;

integer i;

always @(posedge clk) begin
    if(!rst_n) begin
        for(i = 0; i < TAPS; i = i + 1) begin
            values[i] <= 16'd0;
        end
        calc_count <= 0;
        out_dac <= 16'd0;
        sum <= 0;
        STATE <= IDLE;
    end else begin
        case (STATE)

            IDLE: begin
                calc_count <= 0;
                if(start) STATE <= S_DATA;
            end

            S_DATA: begin
                values[0] <= in_adc;
                sum <= 0;
                for(i = 1; i < TAPS; i = i + 1) begin
                    values[i] <= values[i-1];
                end
                STATE <= CALC;
            end

            CALC: begin
                if(calc_count < TAPS) begin
                    sum <= sum + mult_result;
                    calc_count <= calc_count + 1;
                end else begin
                    // Clamp to 12-bit unsigned range, then left-align in 16-bit DAC word
                    out_dac <= (shifted > 16'sd4095) ? 16'hFFF0 :
                               (shifted < 16'sd0)    ? 16'h0000 :
                                                       {shifted[11:0], 4'b0000};
                    STATE <= IDLE;
                end
            end

        endcase
    end
end

endmodule