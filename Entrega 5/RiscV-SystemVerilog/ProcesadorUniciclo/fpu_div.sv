
module fpu_div (
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
  output logic [31:0] div_out  // Resultado final de A / B
);

  import fpu_pkg::*; // Importamos la constante FP32_QNAN (32'h7FC0_0000)

  // --------------------------------------------------------------------------
  // Declaración de señales internas (cables combinacionales)
  logic               s_res;      // Signo del cociente (1 bit)
  logic signed [9:0]  e_prelim;   // Exponente preliminar con signo (10 bits para evitar desborde)
  logic signed [9:0]  e_final;    // Exponente ya ajustado tras normalizar (10 bits con signo)
  logic        [46:0] dividend;   // Dividendo escalado (m_a desplazado 23 bits a la izquierda)
  logic        [46:0] quot_mant;  // Cociente entero de la división de mantisas
  logic        [22:0] frac_final; // Fracción final de 23 bits lista para empaquetar

  // --------------------------------------------------------------------------
  // BLOQUE 1: Cálculo de signo, exponente preliminar y división de mantisas
  // Ley de signos: signos iguales -> 0 (+), signos distintos -> 1 (-)
  assign s_res = s_a ^ s_b;

  // Restamos los exponentes (extendidos a 10 bits con signo) y volvemos a sumar el sesgo 127
  assign e_prelim = $signed({2'b00, e_a}) - $signed({2'b00, e_b}) + 10'sd127;

  // Escalamos m_a multiplicándolo por 2^23 (agregando 23 ceros a la derecha) para conservar
  // los 23 bits de precisión fraccionaria después de la división entera
  assign dividend = {m_a, 23'd0};

  // Dividimos el dividendo escalado entre m_b (protegido contra m_b == 0 para no generar 'X')
  assign quot_mant = (m_b == 24'd0) ? 47'd0 : (dividend / {23'd0, m_b});

  // --------------------------------------------------------------------------
  // BLOQUE 2: Normalización del cociente (sin redondeo / truncamiento)
  always_comb begin
    if (quot_mant[23] == 1'b1) begin
      // Caso A: m_a >= m_b, por lo que el cociente está entre 1.0 y 1.999... (forma 1.xxxx).
      // El bit [23] ya es el '1' implícito: el exponente no cambia y tomamos [22:0].
      e_final    = e_prelim;
      frac_final = quot_mant[22:0];
    end else begin
      // Caso B: m_a < m_b, por lo que el cociente está entre 0.5 y 0.999... (forma 0.1xxx).
      // Corremos el punto 1 lugar a la derecha: restamos 1 al exponente y desplazamos
      // los bits 1 lugar hacia la izquierda, rellenando con un 0 al final.
      e_final    = e_prelim - 10'sd1;
      frac_final = {quot_mant[21:0], 1'b0};
    end
  end

  // --------------------------------------------------------------------------
  // BLOQUE 3: Selección final con prioridad de casos especiales y límites
  always_comb begin
    // 1. Si cualquiera de los operandos es NaN, el resultado siempre es NaN
    if (a_nan || b_nan) begin
      div_out = FP32_QNAN;

    // 2. Indeterminaciones 0 / 0 o Infinito / Infinito -> devuelven NaN
    end else if ((a_zero && b_zero) || (a_inf && b_inf)) begin
      div_out = FP32_QNAN;

    // 3. División entre cero (x / 0, con x != 0 y x != NaN) -> devuelve +-Infinito
    end else if (b_zero) begin
      div_out = {s_res, 8'hFF, 23'd0};

    // 4. Infinito dividido entre un número finito -> devuelve +-Infinito
    end else if (a_inf) begin
      div_out = {s_res, 8'hFF, 23'd0};

    // 5. Cero dividido entre un número distinto de cero -> devuelve +-0.0
    end else if (a_zero) begin
      div_out = {s_res, 8'h00, 23'd0};

    // 6. Overflow: si el exponente final llegó a 255 o más -> satura a +-Infinito
    end else if (e_final >= 10'sd255) begin
      div_out = {s_res, 8'hFF, 23'd0};

    // 7. Underflow: si el exponente final bajó a 0 o menos -> se vuelve +-0.0
    end else if (e_final <= 10'sd0) begin
      div_out = {s_res, 8'h00, 23'd0};

    // 8. Caso normal: empaquetamos signo (1 bit), exponente (8 bits) y fracción (23 bits)
    end else begin
      div_out = {s_res, e_final[7:0], frac_final};
    end
  end

endmodule