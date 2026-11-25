module fpu_add_sub (
  // Entradas provenientes del desempaquetador de A (fpu_unpack)
  input  logic        s_a,         // Signo de A (0 = +, 1 = -)
  input  logic [7:0]  e_a,         // Exponente sesgado de A (0 a 255)
  input  logic [23:0] m_a,         // Mantisa de 24 bits de A (con bit implícito)
  input  logic        a_zero,      // Bandera: 1 si A es +-0.0
  input  logic        a_inf,       // Bandera: 1 si A es +-Infinito
  input  logic        a_nan,       // Bandera: 1 si A es NaN

  // Entradas provenientes del desempaquetador de B (fpu_unpack)
  input  logic        s_b,         // Signo de B (0 = +, 1 = -)
  input  logic [7:0]  e_b,         // Exponente sesgado de B (0 a 255)
  input  logic [23:0] m_b,         // Mantisa de 24 bits de B (con bit implícito)
  input  logic        b_zero,      // Bandera: 1 si B es +-0.0
  input  logic        b_inf,       // Bandera: 1 si B es +-Infinito
  input  logic        b_nan,       // Bandera: 1 si B es NaN

  // Control de operación: 0 = Suma (A + B), 1 = Resta (A - B)
  input  logic        is_sub,

  // Salida de 32 bits en formato IEEE-754
  output logic [31:0] add_sub_out  // Resultado final de A + B o A - B
);

  import fpu_pkg::*; // Importamos FP32_POS_ZERO, FP32_NEG_ZERO y FP32_QNAN

  // --------------------------------------------------------------------------
  // Declaración de señales internas (cables combinacionales)
  // --------------------------------------------------------------------------
  logic               s_b_eff;      // Signo efectivo de B (invertido si is_sub == 1)
  logic               s_big, s_small; // Signos del operando mayor y menor en magnitud
  logic        [7:0]  e_big, e_small; // Exponentes del operando mayor y menor
  logic        [23:0] m_big, m_small; // Mantisas de 24 bits del operando mayor y menor
  logic        [7:0]  exp_diff;     // Diferencia de exponentes (e_big - e_small)
  logic        [26:0] m_big_ext;    // Mantisa mayor extendida con 3 bits extra [26:0]
  logic        [26:0] m_small_ext;  // Mantisa menor extendida y alineada a la derecha
  logic               eff_sub;      // 1 si debemos restar magnitudes, 0 si debemos sumarlas
  logic        [27:0] mant_sum;     // Resultado de sumar o restar mantisas (28 bits por acarreo)
  logic        [4:0]  msb_pos;      // Posición (0 a 26) del primer '1' tras una resta
  logic        [4:0]  lzc;          // Cantidad de ceros a la izquierda (26 - msb_pos)
  logic        [26:0] mant_norm;    // Mantisa ya normalizada con su '1' implícito en el bit [26]
  logic signed [9:0]  e_final;      // Exponente final ajustado (10 bits con signo)
  logic        [22:0] frac_final;   // Fracción final de 23 bits lista para empaquetar

  // --------------------------------------------------------------------------
  // BLOQUE 1: Unificación de Resta en Suma (A - B = A + (-B))
  // --------------------------------------------------------------------------
  // Si is_sub es 1, invertimos el signo de B; si es 0, lo dejamos igual
  assign s_b_eff = s_b ^ is_sub;

  // --------------------------------------------------------------------------
  // BLOQUE 2: Comparación de magnitud y ordenamiento (Grande vs Pequeño)
  // --------------------------------------------------------------------------
  // Comparamos la concatenación {exponente, mantisa} de A y B sin signo.
  // El mayor va a "big" (cuyo signo dominará el resultado) y el menor va a "small".
  always_comb begin
    if ({e_a, m_a} >= {e_b, m_b}) begin
      s_big   = s_a;     e_big   = e_a;     m_big   = m_a;
      s_small = s_b_eff; e_small = e_b;     m_small = m_b;
    end else begin
      s_big   = s_b_eff; e_big   = e_b;     m_big   = m_b;
      s_small = s_a;     e_small = e_a;     m_small = m_a;
    end
  end

  // --------------------------------------------------------------------------
  // BLOQUE 3: Alineación de exponentes (desplazamiento a la derecha del menor)
  // --------------------------------------------------------------------------
  // Calculamos cuántas posiciones debemos desplazar el número pequeño
  assign exp_diff = e_big - e_small;

  // Extendemos ambas mantisas con 3 ceros a la derecha (24 + 3 = 27 bits) para
  // evitar pérdida de préstamos durante la resta antes del truncamiento final.
  assign m_big_ext = {m_big, 3'b000};

  // Si la diferencia de exponentes es >= 27, el número pequeño es demasiado chico
  // frente al grande y se vuelve 0; de lo contrario, lo desplazamos a la derecha.
  assign m_small_ext = (exp_diff >= 8'd27) ? 27'd0 : ({m_small, 3'b000} >> exp_diff);

  // --------------------------------------------------------------------------
  // BLOQUE 4: Suma o Resta efectiva de las mantisas alineadas
  // --------------------------------------------------------------------------
  // Si los signos efectivos son distintos, restamos; si son iguales, sumamos
  assign eff_sub = (s_big != s_small);

  always_comb begin
    if (eff_sub) begin
      mant_sum = {1'b0, m_big_ext} - {1'b0, m_small_ext}; // Resta (sin signo negativo posible)
    end else begin
      mant_sum = {1'b0, m_big_ext} + {1'b0, m_small_ext}; // Suma (bit [27] captura acarreo)
    end
  end

  // --------------------------------------------------------------------------
  // BLOQUE 5: Detector del primer '1' (para re-normalizar tras una resta)
  // --------------------------------------------------------------------------
  always_comb begin
    msb_pos = 5'd0; // Valor por defecto
    // Recorremos los 27 bits bajos de mant_sum buscando el '1' más significativo
    for (int i = 0; i < 27; i++) begin
      if (mant_sum[i]) begin
        msb_pos = i[4:0];
      end
    end
    // Calculamos cuántos lugares falta desplazar a la izquierda para llegar al bit [26]
    lzc = 5'd26 - msb_pos;
  end

  // --------------------------------------------------------------------------
  // BLOQUE 6: Normalización del resultado (acarreo o cancelación)
  // --------------------------------------------------------------------------
  always_comb begin //aqui se revisa si el mas significativo da 1 es porque el ultimo resultado dio 10xxxx
    if (mant_sum[27] == 1'b1) begin
      // Caso A (Acarreo en suma): el resultado es >= 2.0 (forma 1x.xxxx...).
      // Desplazamos 1 bit a la derecha y sumamos 1 al exponente mayor.
      mant_norm  = mant_sum[27:1]; //corrimiento a la derecha de 1 bit
      e_final    = $signed({2'b00, e_big}) + 10'sd1;
      frac_final = mant_norm[25:3]; // Tomamos 23 bits y cortamos los 3 extra (truncamiento)
    end else begin
      // Caso B (Sin acarreo o con cancelación en resta):
      // Desplazamos a la izquierda "lzc" veces para que el primer '1' llegue al bit [26]
      // y restamos "lzc" al exponente mayor.
      mant_norm  = mant_sum[26:0] << lzc;
      e_final    = $signed({2'b00, e_big}) - $signed({5'd0, lzc});
      frac_final = mant_norm[25:3]; // Tomamos 23 bits y cortamos los 3 extra (truncamiento)
    end
  end

  // --------------------------------------------------------------------------
  // BLOQUE 7: Selección final con prioridad de casos especiales y límites
  // --------------------------------------------------------------------------
  always_comb begin
    // 1. Si cualquiera de los operandos es NaN -> devuelve NaN
    if (a_nan || b_nan) begin
      add_sub_out = FP32_QNAN;

    // 2. Si ambos son Infinito:
    //    - Signos opuestos (+Inf + -Inf o +Inf - +Inf) -> indeterminación -> NaN
    //    - Mismo signo (+Inf + +Inf) -> devuelve ese mismo Infinito
    end else if (a_inf && b_inf) begin
      if (s_a != s_b_eff) begin
        add_sub_out = FP32_QNAN;
      end else begin
        add_sub_out = {s_a, 8'hFF, 23'd0};
      end

    // 3. Si solo A es Infinito -> devuelve +-Infinito con el signo de A
    end else if (a_inf) begin
      add_sub_out = {s_a, 8'hFF, 23'd0};

    // 4. Si solo B es Infinito -> devuelve +-Infinito con el signo efectivo de B
    end else if (b_inf) begin
      add_sub_out = {s_b_eff, 8'hFF, 23'd0};

    // 5. Si ambos son Cero -> devuelve -0.0 solo si ambos signos efectivos son negativos
    end else if (a_zero && b_zero) begin
      add_sub_out = (s_a && s_b_eff) ? FP32_NEG_ZERO : FP32_POS_ZERO;

    // 6. Si solo A es Cero -> devuelve B con su signo efectivo
    end else if (a_zero) begin
      add_sub_out = {s_b_eff, e_b, m_b[22:0]};

    // 7. Si solo B es Cero -> devuelve A tal cual
    end else if (b_zero) begin
      add_sub_out = {s_a, e_a, m_a[22:0]};

    // 8. Cancelación total (ej. 5.0 - 5.0 = 0.0 exacto) -> devuelve +0.0
    end else if (mant_sum == 28'd0) begin
      add_sub_out = FP32_POS_ZERO;

    // 9. Overflow: si el exponente final llegó a 255 o más -> satura a +-Infinito
    end else if (e_final >= 10'sd255) begin
      add_sub_out = {s_big, 8'hFF, 23'd0};

    // 10. Underflow: si el exponente final bajó a 0 o menos -> se vuelve +-0.0
    end else if (e_final <= 10'sd0) begin
      add_sub_out = {s_big, 8'h00, 23'd0};

    // 11. Caso normal: empaquetamos signo del mayor, exponente y fracción
    end else begin
      add_sub_out = {s_big, e_final[7:0], frac_final};
    end
  end

endmodule // Fin del módulo fpu_add_sub