classdef cordic_abs_class < handle % наследование от handle обязательно

    properties(Access = private)
        word_len;       % разрядность входных данных (аналог DATA_IN_WIDTH в аппаратной реализации)
        is_signed;      % знаковость входных данных (аналог IS_SIGNED_DATA_IN в аппаратной реализации)
        out_len;        % разрядность выходных данных (аналог DATA_OUT_WIDTH в аппаратной реализации)
        cordic_stages;  % количество стадий алгоритма CORDIC
        mult_stages;    % количество стадий умножения на коэффициент 1/K, K - коэфициент деформации вектора, обусловленный алгоритмом CORDIC
        guard_bits;     % количество дополнительных цифр после точки для CORDIC (аналог GUARD_BITS_QUANTITY в аппаратной реализации)
        mult_guard_bits;% количество дополнительных цифр после точки для умножения (аналог MULT_GUARD_BITS в аппаратной реализации)
    end
%===================================================================================================
    methods(Access = public)
        function self = cordic_abs_class(word_len, is_signed, out_len, cordic_stages, mult_stages, guard_bits, mult_guard_bits)
            if nargin == 7                                  % функция для контроля объявление всех свойст класса
                    self.word_len        =   word_len;      % если хотя бы  одно поле не было объявлено, то создание объекта завершится ошибкой
                    self.is_signed       =   is_signed;
                    self.out_len         =   out_len; 
                    self.cordic_stages   =   cordic_stages;
                    self.mult_stages     =   mult_stages;
                    self.guard_bits      =   guard_bits;
                    self.mult_guard_bits =   mult_guard_bits;
            else
                error(' *** Not all arguments are entered *** ');
            end
        end

        function [ Y ] = cordic_abs(self, a, b) % функция определяет тип модели фильтра (символьная, битовая...)
            if ( length(a) ~= length(b) )    % проверка на соответствие входных аргмументов
                error('Sizes of a and b are not equal!');
            else
                switch class(a)                % определение типа подаваемых значений
                    case 'sym'
                        Y = self.sym_cordic_abs(a,b);
                    case 'embedded.fi'
                        Y = self.bit_cordic_abs(a,b);
                    case 'double'
                        Y = self.sym_cordic_abs(sym(a),sym(b));
                    otherwise
                        error('Unsupported input data type!');
                end
            end
        end

        function [y] = bit_cordic_abs(self, a, b) % битовое вычисление модуля комплексного числа
            
            fprintf('Running "bit_cordic_abs" ... ');

            if a.FractionLength ~= 0 || a.WordLength ~= self.word_len || a.Signed ~= self.is_signed % проверка на соответствие указанному при создании класса типу
                error(' ****** MISTAKE WordLength or FractionLength or Signed ! ****** ');
            else
                work_len = self.word_len + 2 + self.guard_bits;             % аналог WORK_WIDTH в аппаратной реализации
                x = fi(abs(a.data), 0, work_len, 0);
                y = fi(b, self.is_signed, work_len, 0);

                x = fi(bitshift(x, self.guard_bits), 0, work_len, 0);
                y = fi(bitshift(y, self.guard_bits), self.is_signed, work_len, 0); % младшие self.guard_bits разрядов выполняют роль разрядов после точки

                r = zeros(1, length(a));
                for i = 1:length(a)
                    x_cordic = fi([x(i), zeros(1, self.cordic_stages)], 0, work_len, 0);
                    y_cordic = fi([y(i), zeros(1, self.cordic_stages)], 1, work_len, 0);
                    for i1 = 1 : self.cordic_stages
                        x_cordic_shift = fi(round( x_cordic(i1) / (2^(i1-1)) ), 0, work_len, 0);
                        y_cordic_shift = fi(round( y_cordic(i1) / (2^(i1-1)) ), 1, work_len, 0);
                        if ( y_cordic(i1) < 0 )
                            x_cordic(i1+1) = fi((x_cordic(i1) - y_cordic_shift), 0, work_len, 0);
                            y_cordic(i1+1) = fi((y_cordic(i1) + x_cordic_shift), 1, work_len, 0);
                        else
                            x_cordic(i1+1) = fi((x_cordic(i1) + y_cordic_shift), 0, work_len, 0);
                            y_cordic(i1+1) = fi((y_cordic(i1) - x_cordic_shift), 1, work_len, 0);
                        end 
                    end

                    cordic_width    = self.word_len + 2; % аналог CORDIC_RES_WIDTH в аппаратной реализации
                    mult_width      = self.word_len + 2 + self.mult_guard_bits; % аналог MULT_STAGE_REG_WIDTH в аппаратной реализации
                    x_cordic   = fi(bitshift(x_cordic(self.cordic_stages + 1), -self.guard_bits), 0, cordic_width, 0); % выделяем целую часть результата CORDIC
                    coeff      = self.get_coeff();

                    x_cordic   = fi(x_cordic, 0, mult_width, 0);
                    mult_res   = fi(0, 0, mult_width, 0);
                    for i2 = 1 : length(coeff)
                        if ( coeff(i2) == '1' )
                            mult_res = fi(mult_res + bitshift(x_cordic, (self.mult_guard_bits - i2)), 0, mult_width, 0 ); % младшие self.mult_guard_bits разрядов выполняют роль разрядов после точки
                        end
                    end

                    if ( self.is_signed )
                        res_width = self.word_len;    % аналог RESULT_WIDTH в аппаратной реализации
                    else
                        res_width = self.word_len + 1;
                    end

                    unadapted_res = fi(bitshift(mult_res, -self.mult_guard_bits), 0, res_width, 0); % выделяем целую часть результата умножения

                    if ( res_width >= self.out_len )
                        r(i) = fi(bitshift(unadapted_res, -(res_width - self.out_len)), 0, self.out_len, 0);
                    else
                        r(i) = fi(unadapted_res, 0, self.out_len, 0);
                    end
                end
                y = r;
                fprintf('Done! \n');
            end
        end

        function [y] = sym_cordic_abs(self, a, b) % символьное вычисление модуля комплексного числа

            fprintf('Running "sym_cordic_abs" ... ');

            if(length(a) ~= length(b))
                error('Sizes of a and b are not equal!');
            end

            x = abs(a);
            y = b;

            r = zeros(1,length(a));

            for i = 1:length(a)
                x_cordic = sym([x(i), zeros(1, self.cordic_stages)]);
                y_cordic = sym([y(i), zeros(1, self.cordic_stages)]);
                for i1 = 1 : self.cordic_stages
                    x_cordic_shift = x_cordic(i1) / (2^(i1-1));
                    y_cordic_shift = y_cordic(i1) / (2^(i1-1));
                    if ( y_cordic(i1) < 0 )
                        x_cordic(i1+1) = x_cordic(i1) - y_cordic_shift;
                        y_cordic(i1+1) = y_cordic(i1) + x_cordic_shift;
                    else
                        x_cordic(i1+1) = x_cordic(i1) + y_cordic_shift;
                        y_cordic(i1+1) = y_cordic(i1) - x_cordic_shift;
                    end 
                end

                x_cordic    = x_cordic(self.cordic_stages + 1);
                coeff       = sym(bin2dec(self.get_coeff()));
                mult_res    = x_cordic * coeff;

                if ( self.is_signed )
                    res_width = self.word_len;    % аналог RESULT_WIDTH в аппаратной реализации
                else
                    res_width = self.word_len + 1;
                end
 
                if ( res_width >= self.out_len )
                    r(i) = mult_res / ( 2 ^ ( (res_width - self.out_len) + length(self.get_coeff()) ) );
                else
                    r(i) = mult_res / ( 2 ^ ( length(self.get_coeff()) ) );
                end
            end

            y = r;
            fprintf('Done! \n');
        end

        function [ res ] = get_coeff(self) % получение коэффициента 1/K в виде строки, представляющей целое число
            coeff_str   = '10011011011101001110110110101000010000110101111001100';
            cur_st      = 0;
            cur_len     = 0;
            coeff_res   = '';
            if ( self.mult_stages < 1 || 28 < self.mult_stages )
                error('mult_stages property is not correct');
            end
            while ( cur_st < self.mult_stages )
                cur_len = cur_len + 1;
                if ( coeff_str(cur_len) == '1' )
                    cur_st = cur_st + 1;
                end
                coeff_res = strcat(coeff_res, coeff_str(cur_len));
            end
            res = coeff_res;
        end
    end
end
