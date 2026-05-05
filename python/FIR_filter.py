import socket
import struct
from collections import deque
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
import numpy as np

UDP_IP = "127.0.0.1"
UDP_PORT = 5006


sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((UDP_IP, UDP_PORT))
sock.setblocking(False)

raw_history = deque(maxlen=2000)
FIR_result = deque(maxlen=2000)
cap_vol = 0

from scipy.signal import firwin

TAPS = 101           
CUTOFF_HZ = 50.0 
SAMPLE_RATE = 4500 
coeffs = firwin(numtaps=TAPS, cutoff=CUTOFF_HZ, fs=SAMPLE_RATE, pass_zero=True)

filter_buffer = deque(maxlen=TAPS)

def process(raw_value):
    global filter_buffer
    global coeffs
    if len(filter_buffer) < TAPS:
        return 0.0
    result = sum(c * val for c, val in zip(coeffs, reversed(filter_buffer)))
    return result


def update(frame):
    try:
        while True:
            data, addr = sock.recvfrom(1024)
            val = struct.unpack('d', data)[0]
            raw_history.append(val)
            filter_buffer.append(val)
            result = process(val)
            FIR_result.append(result)
    except BlockingIOError:
        pass

    plt.cla()
    plt.plot(raw_history, color='lightgray', label='Raw Signal', alpha=0.7)
    plt.plot(FIR_result, color='red', label='Demodulated Output', linewidth=2)
    plt.title("FIR Filter (Cutoff=50Hz)")
    plt.legend(loc='upper right')
    plt.ylim(-10, 10)

ani = FuncAnimation(plt.gcf(), update, interval=20)
plt.show()