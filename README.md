# Verilog FIR Filter

A hardware low-pass FIR filter implemented on the Gowin Tang Nano 9K FPGA. An ADS1115 ADC reads the input signal over I2C, the FPGA filters it, and an MCP4725 DAC outputs the result. Input/output waveforms were measured with an Arduino.

---

## Hardware

| Component | Role | I2C Address |
|---|---|---|
| Tang Nano 9K | FPGA — runs FIR + I2C logic | — |
| ADS1115 | 16-bit ADC input | `0x48` |
| MCP4725 | 12-bit DAC output | `0x60` |
| Arduino | Measures input & output signals | — |

---

## File Overview

| File | Description |
|---|---|
| `FIR.v` | 51-tap low-pass FIR filter core |
| `I2C_MASTER.v` | Custom 400 kHz I2C master |
| `top.v` | Top-level: ADC → FIR → DAC pipeline |
| `FIR_brain/TB_FIR.v` | FIR testbench (impulse response) |
| `I2C/PHY_WRITE_TEST_I2C.v` | Hardware write test for MCP4725 |
| `I2C/PHY_READ_TEST_I2C.v` | Hardware read test for ADS1115 |
| `python/FIR_MODULE_COEFF_GEN.py` | Generates Verilog coefficients |
| `python/FIR_filter.py` | Real-time FIR visualizer (UDP) |
| `python/udp_real_time_sin.m` | MATLAB multi-tone signal generator |

---

## Changing the Cutoff Frequency

Open `python/FIR_MODULE_COEFF_GEN.py` and edit:

```python
TAPS        = 51    # Number of taps (keep odd)
CUTOFF_HZ   = 10    # ← your desired cutoff in Hz
SAMPLE_RATE = 860   # ← your ADC sample rate in Hz
```

Run the script and paste the printed `case` block into `FIR.v`, replacing the existing `get_coeff` function. That's it — no manual math needed.


---

## Python Scripts

**`FIR_filter.py`** — Listens for samples over UDP and plots the raw vs. filtered signal in real time. Useful for verifying filter behaviour in software before deploying to hardware.

**`udp_real_time_sin.m`** (MATLAB) — Streams a mixed-frequency test signal (1–450 Hz) over UDP to `FIR_filter.py` so you can visually confirm the filter's frequency response.

---

