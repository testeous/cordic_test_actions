clear
clc
% PARAMETERS
WORD_LENGTH = 32; 
IS_SIGNED = 1;
OUT_LENGTH = WORD_LENGTH; 
CORDIC_STAGES = 17; 
MULT_STAGES = 20; 
GUARD_BITS = 6;
MULT_GUARD_BITS = 7;

% class definition
%dpigen -args {fi(910098479,1,32,0), fi(1697368146,1,32,0), 32, 17, 20, 7} bit_cordic_abs_vm % пример работы конструктора.
% example_cordic_abs объект класса cordic_abs_class, с заданными при инициализации приватными параметрами
f_bit = bit_cordic_abs_vm(fi(1060466592,1,32,0), fi(1070791042,1,32,0))
