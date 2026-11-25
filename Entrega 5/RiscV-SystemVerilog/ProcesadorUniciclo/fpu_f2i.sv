// ============================================================================
// Archivo: fpu_f2i.sv
// Función: Convierte un número IEEE-754 de 32 bits (float32) a un entero con
//          signo de 32 bits (int32 en Complemento a 2), aplicando truncamiento
//          hacia cero y las reglas de saturación de RISC-V (CPUlator).
// ============================================================================

module fpu_f2i (
  input  logic        sign,    // Bit de signo del flotante (viene de fpu_unpack)
  input  logic [7:0]  exp,     // Exponente sesgado de 8 bits (viene de fpu_unpack)
  input  logic [22:0] frac,    // Fracción de 23 bits (viene de fpu_unpack)
  input  logic [23:0] mant,    // Mantisa de 24 bits {1'b1, frac} (viene de fpu_unpack)
  input  logic        is_inf,  // Bandera en 1 si el flotante es +Inf o -Inf
  input  logic        is_nan,  // Bandera en 1 si el flotante es NaN
  output logic [31:0] int_out  // Salida: entero con signo de 32 bits (int32)
);

  import fpu_pkg::*; // Importamos INT32_MAX (32'h7FFF_FFFF) e INT32_MIN (32'h8000_0000)

  // --------------------------------------------------------------------------
  // Declaración de señales internas (cables combinacionales)
  // --------------------------------------------------------------------------
  logic [7:0]  real_exp;   // Exponente real sin sesgo (exp - 127), rango útil: 0 a 31
  logic [31:0] ext_mant;   // Mantisa de 24 bits extendida a 32 bits con ceros a la izquierda
  logic [31:0] mag_int;    // Magnitud entera positiva ya alineada (sin parte fraccionaria)
  logic [31:0] signed_int; // Entero final con signo aplicado (en Complemento a 2 si sign == 1)

  // --------------------------------------------------------------------------
  // BLOQUE 1: Cálculo del exponente real y alineación de la mantisa
  // --------------------------------------------------------------------------
  // Restamos el sesgo (bias = 127) para saber la potencia real de 2 del número.
  // Ejemplo: si exp = 130, real_exp = 130 - 127 = 3 (equivale a 2^3 = 8).
  assign real_exp = exp - 8'd127;

  // Extendemos la mantisa de 24 bits a 32 bits agregando 8 ceros a la izquierda.
  // En este vector de 32 bits:
  // - El bit [23] es el entero '1' implícito (peso 2^0 antes de desplazar).
  // - Los bits [22:0] son los 23 bits fraccionarios (a la derecha del punto binario).
  assign ext_mant = {8'd0, mant};

  // Desplazamos ext_mant para eliminar los bits fraccionarios según real_exp:
  always_comb begin
    if (real_exp < 8'd23) begin
      // Si el exponente real es menor a 23, todavía sobran bits fraccionarios a la derecha.
      // Desplazamos a la DERECHA (23 - real_exp) posiciones: los bits fraccionarios caen fuera
      // del bus y se pierden (truncamiento hacia cero).
      mag_int = ext_mant >> (8'd23 - real_exp);
    end else begin
      // Si el exponente real es 23 o mayor (hasta 31), el número es tan grande que necesita
      // ceros enteros a la derecha. Desplazamos a la IZQUIERDA (real_exp - 23) posiciones.
      mag_int = ext_mant << (real_exp - 8'd23);
    end
  end

  // --------------------------------------------------------------------------
  // BLOQUE 2: Aplicación del signo (conversión a Complemento a 2)
  // --------------------------------------------------------------------------
  // Si el flotante era negativo (sign == 1), convertimos la magnitud positiva a negativo
  // invirtiendo sus bits y sumando 1. Si era positivo (sign == 0), pasa sin cambios.
  assign signed_int = sign ? (~mag_int + 32'd1) : mag_int;

  // --------------------------------------------------------------------------
  // BLOQUE 3: Selección final con prioridades de Saturación RISC-V y Cero
  // --------------------------------------------------------------------------
  always_comb begin
    // PRIORIDAD 1: Saturación Positiva (INT32_MAX = +2,147,483,647 = 32'h7FFF_FFFF)
    // Se activa si:
    // - La entrada es NaN (regla estándar de RISC-V / CPUlator), O
    // - El número es positivo (sign == 0) y es +Infinito o su exponente es >= 158
    //   (exp = 158 significa real_exp = 31, es decir, >= +2,147,483,648.0, que no cabe en int32).
    if (is_nan || (!sign && (is_inf || exp >= 8'd158))) begin
      int_out = INT32_MAX;

    // PRIORIDAD 2: Saturación Negativa (INT32_MIN = -2,147,483,648 = 32'h8000_0000)
    // Se activa si el número es negativo (sign == 1) y además:
    // - Es -Infinito, O
    // - Su exponente es > 158, O
    // - Su exponente es == 158 con fracción != 0 (es decir, estrictamente menor a -2,147,483,648.0).
    // (Nota: si exp == 158 y frac == 0, el valor es exactamente -2,147,483,648.0, que SÍ cabe
    // en int32 y pasa por el 'else' normal produciendo exactamente 32'h8000_0000).
    end else if (sign && (is_inf || exp > 8'd158 || (exp == 8'd158 && frac != 23'd0))) begin
      int_out = INT32_MIN;

    // PRIORIDAD 3: Magnitud menor que 1.0 (incluye +0.0, -0.0, subnormales y fracciones 0.xxxx)
    // Si el exponente sesgado es menor a 127, el exponente real es negativo (2^-1, 2^-2, etc.).
    // Al truncar hacia cero, cualquier número entre -0.99999 y +0.99999 vale 0 entero.
    end else if (exp < 8'd127) begin
      int_out = 32'd0;

    // PRIORIDAD 4: Caso normal dentro del rango válido [-2147483648, +2147483647]
    end else begin
      int_out = signed_int;
    end
  end

endmodule