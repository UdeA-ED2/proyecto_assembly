//Modulo para multiplicar
module fpu_mul (
  // Entradas provenientes del desempaquetador de A (fpu_unpack)
  input  logic        s_a,     // Signo de A (0 = +, 1 = -)
  input  logic [7:0]  e_a,     // Exponente sesgado de A (0 a 255)
  input  logic [23:0] m_a,     // Mantisa de 24 bits de A (con bit implícito)
  input  logic        a_zero,  // Bandera: 1 si A es +-0.0
  input  logic        a_inf,   // Bandera: 1 si A es +-Infinito
  input  logic        a_nan,   // Bandera: 1 si A es NaN

  // Entradas provenientes del desempaquetador de B (fpu_unpack)
  input  logic        s_b,     // Signo de B (0 = +, 1 = -)
  input  logic [7:0]  e_b,     // Exponente sesgado de B (0 a 255)
  input  logic [23:0] m_b,     // Mantisa de 24 bits de B (con bit implícito)
  input  logic        b_zero,  // Bandera: 1 si B es +-0.0
  input  logic        b_inf,   // Bandera: 1 si B es +-Infinito
  input  logic        b_nan,   // Bandera: 1 si B es NaN

  // Salida de 32 bits en formato IEEE-754
  output logic [31:0] mul_out  // Resultado final de A * B
);

  import fpu_pkg::*; // Importamos la constante FP32_QNAN (32'h7FC0_0000)

  // --------------------------------------------------------------------------
  // Declaración de señales internas (cables combinacionales)
  logic               s_res;      // Signo del producto (1 bit)
  logic signed [9:0]  e_prelim;   // Exponente preliminar con signo (10 bits para evitar desborde)
  logic signed [9:0]  e_final;    // Exponente ya ajustado tras normalizar (10 bits con signo)
  logic        [47:0] prod_mant;  // Producto exacto de m_a * m_b (24 bits x 24 bits = 48 bits)
  logic        [22:0] frac_final; // Fracción final de 23 bits lista para empaquetar

  // --------------------------------------------------------------------------
  // BLOQUE 1: Cálculo de signo, exponente preliminar y producto de mantisas
  // Ley de signos: signos iguales -> 0 (+), signos distintos -> 1 (-)
  assign s_res = s_a ^ s_b;

  // Sumamos los dos exponentes (extendidos a 10 bits con signo) y restamos el sesgo 127 una vez
  assign e_prelim = $signed({2'b00, e_a}) + $signed({2'b00, e_b}) - 10'sd127;

  // Multiplicación entera sin signo de las dos mantisas de 24 bits (resultado de 48 bits)
  // En estos 48 bits, [47:46] son los 2 bits enteros y [45:0] son los 46 bits fraccionarios
  assign prod_mant = m_a * m_b;

  // --------------------------------------------------------------------------
  // Normalización de la mantisa (sin redondeo / truncamiento)
  always_comb begin
    if (prod_mant[47] == 1'b1) begin
      // Caso A: El producto es >= 2.0 (tiene forma 1x.xxxx...).
      // Corremos el punto 1 lugar a la izquierda: sumamos 1 al exponente y tomamos
      // los 23 bits inmediatamente a la derecha del bit [47], es decir, [46:24].
      e_final    = e_prelim + 10'sd1;
      frac_final = prod_mant[46:24];
    end else begin
      // Caso B: El producto está entre 1.0 y 1.999... (tiene forma 01.xxxx...).
      // El bit [46] ya es el '1' implícito: mantenemos el exponente y tomamos
      // los 23 bits inmediatamente a la derecha del bit [46], es decir, [45:23].
      e_final    = e_prelim;
      frac_final = prod_mant[45:23];
    end
  end

  // --------------------------------------------------------------------------
  // Selección final con prioridad de casos especiales y límites
  always_comb begin
    // 1. Si cualquiera de los operandos es NaN, el resultado siempre es NaN
    if (a_nan || b_nan) begin
      mul_out = FP32_QNAN;

    // 2. Indeterminación 0 * Infinito o Infinito * 0 -> devuelve NaN
    end else if ((a_zero && b_inf) || (a_inf && b_zero)) begin
      mul_out = FP32_QNAN;

    // 3. Si alguno es Infinito (y el otro no es 0 ni NaN) -> devuelve +-Infinito
    end else if (a_inf || b_inf) begin
      mul_out = {s_res, 8'hFF, 23'd0};

    // 4. Si alguno es Cero (y el otro no es Inf ni NaN) -> devuelve +-0.0
    end else if (a_zero || b_zero) begin
      mul_out = {s_res, 8'h00, 23'd0};

    // 5. Overflow: si el exponente final llegó a 255 o más -> satura a +-Infinito
    end else if (e_final >= 10'sd255) begin
      mul_out = {s_res, 8'hFF, 23'd0};

    // 6. Underflow: si el exponente final bajó a 0 o menos -> se vuelve +-0.0
    end else if (e_final <= 10'sd0) begin
      mul_out = {s_res, 8'h00, 23'd0};

    // 7. Caso normal: empaquetamos signo (1 bit), exponente (8 bits) y fracción (23 bits)
    end else begin
      mul_out = {s_res, e_final[7:0], frac_final};
    end
  end

endmodule 