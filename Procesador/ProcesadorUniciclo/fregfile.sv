//modulo de registros de flotantes 

module fregfile (	// Inicio de la declaración del módulo fregfile
  input  logic        clk, // Entrada de 1 bit: reloj principal del sistema (sincroniza escrituras)
  input  logic        we3,	// Entrada de 1 bit: Write Enable (habilitación de escritura, vendrá de FRegWrite)
  input  logic [4:0]  a1, a2, 	// Entradas de 5 bits: direcciones de lectura rs1 (Instr[19:15]) y rs2 (Instr[24:20])
  input  logic [4:0]  a3,	// Entrada de 5 bits: dirección de escritura rd (Instr[11:7])
  input  logic [31:0] wd3,	// Entrada de 32 bits: dato IEEE-754 que se va a guardar en f[rd]
  output logic [31:0] rd1, rd2	// Salidas de 32 bits: datos IEEE-754 leídos desde f[rs1] y f[rs2]
);

  logic [31:0] rf[31:0];	// Declara la matriz de memoria interna: 32 registros (índices 0 a 31), cada uno de 32 bits

  always_ff @(posedge clk) begin	// Bloque secuencial: se activa únicamente en el flanco de subida del reloj
    if (we3)							// Verifica si la señal de permiso de escritura está activa en 1
      rf[a3] <= wd3;					// Escritura no bloqueante: guarda el dato wd3 en el registro apuntado por a3 (incluyendo f0)
  end                                                   

  assign rd1 = rf[a1];			// Lectura combinacional puerto 1: entrega al instante el contenido del registro f[a1]
  assign rd2 = rf[a2];	    // Lectura combinacional puerto 2: entrega al instante el contenido del registro f[a2]

endmodule 