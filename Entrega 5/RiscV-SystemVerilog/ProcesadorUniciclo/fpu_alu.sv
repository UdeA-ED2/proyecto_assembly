//Modulo principal que integra todo, alu en general

module fpu_alu (
  input  logic [31:0] a,           // Operando A de 32 bits (float32, o int32 en operación I2F)
  input  logic [31:0] b,           // Operando B de 32 bits (float32)
  input  logic [2:0]  fpu_control, // Selector de operación de 3 bits (000 a 101)
  output logic [31:0] result       // Resultado final de 32 bits (float32, o int32 en operación F2I)
);

  import fpu_pkg::*; // Importamos las constantes y códigos de operación definidos en fpu_pkg.sv

  // --------------------------------------------------------------------------
  // SECCIÓN 1: Cables internos para recibir los datos desempaquetados de A y B
  logic        s_a, s_b;           // Signos de A y B
  logic [7:0]  e_a, e_b;           // Exponentes sesgados de A y B
  logic [22:0] f_a, f_b;           // Fracciones de 23 bits de A y B
  logic [23:0] m_a, m_b;           // Mantisas completas de 24 bits (con bit implícito) de A y B
  logic        a_zero, a_sub, a_inf, a_nan; // Banderas especiales del operando A
  logic        b_zero, b_sub, b_inf, b_nan; // Banderas especiales del operando B

  // --------------------------------------------------------------------------
  // SECCIÓN 2: Instanciación del Módulo 1 (Desempaquetadores para A y B)

  // Instancia 1: analiza el bus de entrada "a"
  fpu_unpack u_unpack_a (
    .in      (a),      // Conectamos la entrada 'a' de la ALU al puerto 'in' del desempaquetador
    .sign    (s_a),    // Guardamos el signo extraído en el cable s_a
    .exp     (e_a),    // Guardamos el exponente extraído en el cable e_a
    .frac    (f_a),    // Guardamos la fracción extraída en el cable f_a
    .mant    (m_a),    // Guardamos la mantisa de 24 bits en el cable m_a
    .is_zero (a_zero), // Guardamos bandera de cero en a_zero
    .is_sub  (a_sub),  // Guardamos bandera de subnormal en a_sub
    .is_inf  (a_inf),  // Guardamos bandera de infinito en a_inf
    .is_nan  (a_nan)   // Guardamos bandera de NaN en a_nan
  );

  // Instancia 2: analiza el bus de entrada "b" simultáneamente
  fpu_unpack u_unpack_b (
    .in      (b),      // Conectamos la entrada 'b' de la ALU al puerto 'in' del desempaquetador
    .sign    (s_b),    // Guardamos el signo extraído en el cable s_b
    .exp     (e_b),    // Guardamos el exponente extraído en el cable e_b
    .frac    (f_b),    // Guardamos la fracción extraída en el cable f_b
    .mant    (m_b),    // Guardamos la mantisa de 24 bits en el cable m_b
    .is_zero (b_zero), // Guardamos bandera de cero en b_zero
    .is_sub  (b_sub),  // Guardamos bandera de subnormal en b_sub
    .is_inf  (b_inf),  // Guardamos bandera de infinito en b_inf
    .is_nan  (b_nan)   // Guardamos bandera de NaN en b_nan
  );

  // --------------------------------------------------------------------------
  // SECCIÓN 3: Cables internos para conectar las futuras unidades funcionales
  logic [31:0] res_add_sub; // Resultado proveniente del módulo Sumador/Restador
  logic [31:0] res_mul;     // Resultado proveniente del módulo Multiplicador
  logic [31:0] res_div;     // Resultado proveniente del módulo Divisor
  logic [31:0] res_f2i;     // Resultado proveniente del módulo Float to Int
  logic [31:0] res_i2f;     // Resultado proveniente del módulo Int to Float
  
  
//-----------------------------------------------------------------------------------------------
// Conexiones temporales a cero mientras construimos cada módulo paso a paso:

  // 1. Unidad de Suma y Resta (20% de la nota)
  // Nota: fpu_control[0] vale 0 en FPU_ADD (3'b000) y 1 en FPU_SUB (3'b001)
  fpu_add_sub u_add_sub (
    .s_a         (s_a),
    .e_a         (e_a),
    .m_a         (m_a),
    .a_zero      (a_zero),
    .a_inf       (a_inf),
    .a_nan       (a_nan),
    .s_b         (s_b),
    .e_b         (e_b),
    .m_b         (m_b),
    .b_zero      (b_zero),
    .b_inf       (b_inf),
    .b_nan       (b_nan),
    .is_sub      (fpu_control[0]),
    .add_sub_out (res_add_sub)
  );
  
  // Instancia del Multiplicador Float 
  fpu_mul u_mul (
    .s_a     (s_a),     // Signo de A
    .e_a     (e_a),     // Exponente de A
    .m_a     (m_a),     // Mantisa de 24 bits de A
    .a_zero  (a_zero),  // Bandera cero de A
    .a_inf   (a_inf),   // Bandera infinito de A
    .a_nan   (a_nan),   // Bandera NaN de A
    .s_b     (s_b),     // Signo de B
    .e_b     (e_b),     // Exponente de B
    .m_b     (m_b),     // Mantisa de 24 bits de B
    .b_zero  (b_zero),  // Bandera cero de B
    .b_inf   (b_inf),   // Bandera infinito de B
    .b_nan   (b_nan),   // Bandera NaN de B
    .mul_out (res_mul)  // Sale el producto hacia el multiplexor de la ALU
  );
  
  // Instancia real del Archivo 7: Divisor Float (10% de la nota)
  fpu_div u_div (
    .s_a     (s_a),     // Signo de A
    .e_a     (e_a),     // Exponente de A
    .m_a     (m_a),     // Mantisa de 24 bits de A
    .a_zero  (a_zero),  // Bandera cero de A
    .a_inf   (a_inf),   // Bandera infinito de A
    .a_nan   (a_nan),   // Bandera NaN de A
    .s_b     (s_b),     // Signo de B
    .e_b     (e_b),     // Exponente de B
    .m_b     (m_b),     // Mantisa de 24 bits de B
    .b_zero  (b_zero),  // Bandera cero de B
    .b_inf   (b_inf),   // Bandera infinito de B
    .b_nan   (b_nan),   // Bandera NaN de B
    .div_out (res_div)  // Sale el cociente hacia el multiplexor de la ALU
  );
  
  // Instancia de Conversión Float a Entero int
  fpu_f2i u_f2i (
    .sign    (s_a),     // Signo de A (extraído por u_unpack_a)
    .exp     (e_a),     // Exponente de A (extraído por u_unpack_a)
    .frac    (f_a),     // Fracción de A (extraída por u_unpack_a)
    .mant    (m_a),     // Mantisa de 24 bits de A (extraída por u_unpack_a)
    .is_inf  (a_inf),   // Bandera de infinito de A
    .is_nan  (a_nan),   // Bandera de NaN de A
    .int_out (res_f2i)  // Sale el entero convertido hacia el multiplexor de la ALU
  );
  

  // Instancia del entero int a float
  fpu_i2f u_i2f (
    .int_in    (a),       // Entra el operando entero 'a' de la ALU
    .float_out (res_i2f)  // Sale el flotante convertido hacia el multiplexor de la ALU
  );
//----------------------------------------------------------------------------------------------------


  // --------------------------------------------------------------------------
  // SECCIÓN 4: Multiplexor de salida (elige qué operación sale por "result")
  always_comb begin              // Bloque puramente combinacional (se actualiza al instante)
    case (fpu_control)           // Evalúa los 3 bits de la señal de control
      FPU_ADD: result = res_add_sub; // Si es 000, saca el resultado de suma/resta
      FPU_SUB: result = res_add_sub; // Si es 001, saca el resultado de suma/resta
      FPU_MUL: result = res_mul;     // Si es 010, saca el resultado de multiplicación
      FPU_DIV: result = res_div;     // Si es 011, saca el resultado de división
      FPU_F2I: result = res_f2i;     // Si es 100, saca el resultado de float a int
      FPU_I2F: result = res_i2f;     // Si es 101, saca el resultado de int a float
      default: result = FP32_QNAN;   // Para códigos no usados (110, 111), devuelve NaN por seguridad
    endcase                          
  end                                

endmodule