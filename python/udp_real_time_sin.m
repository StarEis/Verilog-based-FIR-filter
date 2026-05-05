if exist('u', 'var')
    clear u;
end

u = udpport("LocalHost", "127.0.0.1", "LocalPort", 5005);
t = 0;
dt = 1/4500; 

disp('Transmitting AM Signal...');

freqs = [1, 5, 15, 30, 45, 60, 120, 200, 350, 450];
% freqs = 450;
while true
    mixed_signal = sin(2 * pi * t * freqs');
    tx_signal = sum(mixed_signal);
    write(u, tx_signal, "double", "127.0.0.1", 5006);
    t = t + dt;
    pause(dt); 
end