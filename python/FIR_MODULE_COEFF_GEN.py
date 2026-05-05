from scipy.signal import firwin
import numpy as np

TAPS = 51          
CUTOFF_HZ = 10
SAMPLE_RATE = 860
coeffs = firwin(numtaps=TAPS, cutoff=CUTOFF_HZ, fs=SAMPLE_RATE, pass_zero=True)

variable_name = "coeffs"
input_name = "idx"
bit_length = 16
multi = 2**bit_length
message = f"function signed [15:0] get_{variable_name}; //cut off: {CUTOFF_HZ} Hz\n  input [{int(np.floor(np.log2(TAPS)))}:0] {input_name}; \n  case({input_name})\n"

# print(sum(coeffs))
for i in range(51):
    if(i > 9):
        message += f"       6'd{i}: get_{variable_name} = 16'd{int(round(coeffs[i] * multi, 0))}; //{coeffs[i]%.3}\n"
    else:
        message += f"       6'd{i}:  get_{variable_name} = 16'd{int(round(coeffs[i] * multi, 0))}; //{coeffs[i]%.3}\n"
message += f"       default: get_{variable_name} = 16'd0; \n   endcase\nendfunction"
print(message)

