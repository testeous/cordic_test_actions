function [  ] = cordic_abs_example()
% PARAMETERS
WORD_LENGTH = 32; 
IS_SIGNED = 1;
OUT_LENGTH = WORD_LENGTH; 
CORDIC_STAGES = 17; 
MULT_STAGES = 20; 
GUARD_BITS = 6;
MULT_GUARD_BITS = 7;

% class definition
example_cordic_abs = cordic_abs_class(WORD_LENGTH, IS_SIGNED, OUT_LENGTH, CORDIC_STAGES, MULT_STAGES, GUARD_BITS, MULT_GUARD_BITS); % пример работы конструктора.
% example_cordic_abs объект класса cordic_abs_class, с заданными при инициализации приватными параметрами

% GENERATION FUNCTION
% ========================================================================================================================
Fs = 1000;            % Sampling frequency
T = 1/Fs;             % Sampling period
L = 2048;              % Length of signal
t = (0:L-1)*T;        % Time vector
%init class with diff properties

S = 0.7*sin(2*pi*50*t) + sin(2*pi*120*t); % Form a signal containing a 50 Hz sinusoid of amplitude 0.7 and
                                          % a 120 Hz sinusoid of amplitude 1
X = (S + 2*randn(size(t))); % Corrupt the signal with zero-mean white noise with a variance of 4
% ========================================================================================================================

%   division into the real and imaginary parts

% bit
x_real_part_bit = fi(real(fft(X)), 1, WORD_LENGTH, 0);
x_imag_part_bit = fi(imag(fft(X)), 1, WORD_LENGTH, 0);

% sym
x_real_part_sym = sym(real(fft(X)));
x_imag_part_sym = sym(imag(fft(X)));

% PLOT GRAPH
figure;
subplot(3,1,1);% битовая модель
f_bit = example_cordic_abs.cordic_abs(x_real_part_bit, x_imag_part_bit);
plot(f_bit,'k');
grid on;
title('rezult fast ABS bit');

subplot(3,1,2);% символьная модель
f_sym = example_cordic_abs.cordic_abs(x_real_part_sym, x_imag_part_sym);
plot(f_sym);
grid on;
title('rezult fast ABS sym');

subplot(3,1,3);% разница работы sym/bit моделей
plot(f_sym - f_bit, 'm');
grid on;
title('sym - bit');

end
