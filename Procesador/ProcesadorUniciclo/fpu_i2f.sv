//Convierte un entero con signo de 32 bits (int32 en Complemento a 2)
//          a punto flotante IEEE-754 de 32 bits (float32) sin redondeo.

module fpu_i2f (
  input  logic [31:0] int_in,   // Entrada: número entero con signo de 32 bits
  output logic [31:0] float_out // Salida: número equivalente en formato IEEE-754
);

  import fpu_pkg::*; // Importamos las constantes globales (como FP32_POS_ZERO)

  // --------------------------------------------------------------------------
  // Declaración de señales internas (cables combinacionales)
  logic        sign;      // Bit de signo del resultado (0 = positivo, 1 = negativo)
  logic [31:0] abs_val;   // Magnitud sin signo (valor absoluto) de int_in
  logic [4:0]  msb_pos;   // Posición (0 a 31) del bit '1' más significativo de abs_val
  logic [4:0]  shift_amt; // Cantidad de bits que debemos desplazar abs_val a la izquierda
  logic [31:0] norm_mant; // Magnitud ya desplazada con su primer '1' en el bit [31]
  logic [7:0]  exp;       // Exponente sesgado de 8 bits (127 + msb_pos)
  logic [22:0] frac;      // Fracción final de 23 bits (sin el bit implícito)

  // --------------------------------------------------------------------------
  // BLOQUE 1: Extracción de signo y conversión a magnitud (valor absoluto)
  assign sign = int_in[31]; // En Complemento a 2, el bit [31] indica si es negativo

  // Si sign es 1, invertimos todos los bits y sumamos 1 para obtener el valor positivo.
  // Si sign es 0, el número ya es positivo y pasa tal cual.
  
  // Para -2147483648 (32'h8000_0000), ~int_in + 1 da 32'h8000_0000 (2^31 sin signo),
  // lo cual funciona exacto porque abs_val se interpreta como magnitud sin signo.
  assign abs_val = sign ? (~int_in + 32'd1) : int_in;

  // --------------------------------------------------------------------------
  // BLOQUE 2: Detector del primer '1' (Codificador de prioridad combinacional) 
  //ejecuta el for de izquiera a derecha y guarla la ultima posicion que encuentra 
  always_comb begin
    msb_pos = 5'd0; // Valor inicial por defecto para evitar latches
    // Recorremos los 32 bits desde el menos significativo (0) hasta el más significativo (31).
    // Como el ciclo avanza hacia la izquierda, el último '1' que encuentre será el más alto.
    for (int i = 0; i < 32; i++) begin
      if (abs_val[i]) begin // Si el bit en la posición 'i' vale 1...
        msb_pos = i[4:0];   // ...guardamos la posicion como 5'd(x) posicion de 0 a 31 en binario de 5 bits
      end
    end
  end

  // --------------------------------------------------------------------------
  //Normalización (alineación)
  // Calculamos cuánto falta para llevar el bit msb_pos hasta la posición 31 eje: 9 msb_pos=28
  assign shift_amt = 5'd31 - msb_pos;

  // Desplazamos abs_val a la izquierda: ahora norm_mant[31] siempre vale 1 (bit implícito)
  assign norm_mant = abs_val << shift_amt;

  // El exponente sesgado es 127 más la potencia de 2 donde estaba el primer '1' msb_pos son 5 bits y le concatenamos 3bits de 0 a la izquierda para sumarlo con los 8bits del sesgo
  assign exp       = 8'd127 + {3'd0, msb_pos};

  // Tomamos los 23 bits inmediatamente a la derecha del bit implícito [31].
  // Los bits bajos [7:0] se descartan automáticamente (truncamiento sin redondeo).
  assign frac      = norm_mant[30:8];

  // --------------------------------------------------------------------------
  // Ensamblaje final y filtro del caso especial Cero
  // Si la entrada entera era 0, entregamos poszero +0.0 exacto (32'h0000_0000).
  // De lo contrario, empaquetamos {Signo (1 bit), Exponente (8 bits), Fracción (23 bits)}.
  assign float_out = (int_in == 32'd0) ? FP32_POS_ZERO : {sign, exp, frac};

endmodule 