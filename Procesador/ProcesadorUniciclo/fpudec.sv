//Decodificador de las 8 instrucciones RISC-V RV32F (opcode 7'b1010011).
//          Genera las señales de control para fpu_alu y los muxes del datapath.

module fpudec (	// Inicio de la declaración del módulo decodificador de punto flotante
  input  logic        IsFloat,		// Entrada de 1 bit: vale 1 cuando opcode == 7'b1010011 (instrucción RV32F)
  input  logic [6:0]  funct7,		   // Entrada de 7 bits (Instr[31:25]): identifica qué operación flotante se ejecuta
  input  logic [4:0]  rs2,			   // Entrada de 5 bits (Instr[24:20]): segundo operando o subcódigo (00000 en fcvt/fmv)
  input  logic [2:0]  funct3,		   // Entrada de 3 bits (Instr[14:12]): modo de redondeo (rm) o 3'b000 fijo en fmv
  output logic [2:0]  FPUControl,   // Salida de 3 bits: código de operación enviado al puerto fpu_control de fpu_alu
  output logic        FRegWrite,		// Salida de 1 bit: 1 habilita escritura en el banco flotante fregfile (f[rd])
  output logic        FPRegWrite,	// Salida de 1 bit: 1 habilita escritura en el banco entero regfile (x[rd]) desde FPU
  output logic        FPUSrcASel,	// Salida de 1 bit: selecciona entrada 'a' de fpu_alu (0 = f[rs1], 1 = x[rs1])
  output logic        FResultSrc,	// Salida de 1 bit: selecciona qué se guarda en f[rd] (0 = FPUResult, 1 = x[rs1] directo)
  output logic        FPToIntMove	// Salida de 1 bit: selecciona qué se guarda en x[rd] (0 = FPUResult, 1 = f[rs1] directo)
);                                      

  import fpu_pkg::*;			// Importa el paquete de la Entrega 5 (constantes FPU_ADD, FPU_SUB, FPU_MUL, etc.)

  always_comb begin			// Bloque puramente combinacional reacciona de inmediato ante cambios en la instrucción
    FPUControl  = FPU_ADD;		// Valor por defecto seguro para FPUControl (3'b000) para evitar latches
    FRegWrite   = 1'b0;			// Por defecto NO escribe en el banco de registros flotantes (f[rd])
    FPRegWrite  = 1'b0;			// Por defecto NO escribe en el banco de registros enteros (x[rd])
    FPUSrcASel  = 1'b0;			// Por defecto el puerto 'a' de fpu_alu recibe fRD1 (desde el banco flotante)
    FResultSrc  = 1'b0;			// Por defecto el dato a guardar en f[rd] proviene de la salida de fpu_alu
    FPToIntMove = 1'b0;			// Por defecto si se escribe en x[rd], el dato proviene de fpu_alu (caso fcvt.w.s)

    if (IsFloat) begin		// Solo decodifica si el opcode confirmó que es una instrucción de punto flotante
      case (funct7)			// Evalúa los 7 bits superiores de la instrucción para distinguir la operación

        // 1. fadd.s: f[rd] = f[rs1] + f[rs2]
        7'b0000000: begin // Código funct7 correspondiente a suma flotante de precisión simple (.s)
          FPUControl = FPU_ADD; // Ordena a fpu_alu realizar suma (3'b000)
          FRegWrite  = 1'b1; // Habilita escritura del resultado flotante en f[rd]
        end                                               

        // 2. fsub.s: f[rd] = f[rs1] - f[rs2]
        7'b0000100: begin // Código funct7 correspondiente a resta flotante de precisión simple (.s)
          FPUControl = FPU_SUB; // Ordena a fpu_alu realizar resta (3'b001)
          FRegWrite  = 1'b1; // Habilita escritura del resultado flotante en f[rd]
        end

        // 3. fmul.s: f[rd] = f[rs1] * f[rs2]
        7'b0001000: begin		// Código funct7 correspondiente a multiplicación flotante de precisión simple (.s)
          FPUControl = FPU_MUL;		// Ordena a fpu_alu realizar multiplicación (3'b010)
          FRegWrite  = 1'b1;		// Habilita escritura del resultado flotante en f[rd]
        end                                             

        // 4. fdiv.s: f[rd] = f[rs1] / f[rs2]
        7'b0001100: begin	// Código funct7 correspondiente a división flotante de precisión simple (.s)
          FPUControl = FPU_DIV;	// Ordena a fpu_alu realizar división (3'b011)
          FRegWrite  = 1'b1;	// Habilita escritura del resultado flotante en f[rd]
        end                                           

        // 5. fcvt.w.s: x[rd] = (int32) f[rs1] (rs2 == 00000 -> entero con signo)
        7'b1100000: begin		// Código funct7 para convertir de float32 a entero (fcvt.w.s / fcvt.wu.s)
          if (rs2 == 5'b00000) begin	// Verifica rs2 == 00000 (entero con signo .w; si fuera 00001 sería sin signo .wu)
            FPUControl  = FPU_F2I;	// Ordena a fpu_alu convertir flotante a entero con signo (3'b100)
            FPRegWrite  = 1'b1;	// Habilita escritura en el banco de registros ENTEROS x[rd]
            FPToIntMove = 1'b0; // Indica que el entero hacia x[rd] viene procesado desde fpu_alu (no bypass)
          end// Fin de verificación rs2 == 00000
        end                                              

        // 6. fcvt.s.w: f[rd] = (float) x[rs1] (rs2 == 00000 -> entero con signo)
        7'b1101000: begin		// Código funct7 para convertir de entero a float32 (fcvt.s.w / fcvt.s.wu)
          if (rs2 == 5'b00000) begin		// Verifica rs2 == 00000 (origen entero con signo .w)
            FPUControl = FPU_I2F;		// Ordena a fpu_alu convertir entero a flotante (3'b101)
            FRegWrite  = 1'b1;		// Habilita escritura en el banco de registros FLOTANTES f[rd]
            FPUSrcASel = 1'b1;		// Conmuta mux de entrada 'a' de fpu_alu para leer desde el banco entero x[rs1]
          end		// Fin de verificación rs2 == 00000
        end                                               

        // 7. fmv.x.w: x[rd] = f[rs1] (copia de 32 bits sin conversión)
        7'b1110000: begin		// Código funct7 para mover bits crudos de flotante a entero (fmv.x.w)
          if (rs2 == 5'b00000 && funct3 == 3'b000) begin  // Exige rs2 == 00000 y funct3 == 000 (distingue fmv.x.w de fclass.s que usa funct3=001)
            FPRegWrite  = 1'b1;		// Habilita escritura en el banco de registros ENTEROS x[rd]
            FPToIntMove = 1'b1;		// Activa ruta directa (bypass): copia fRD1 hacia x[rd] sin pasar por fpu_alu
          end		// Fin de verificación de campos fijos de fmv.x.w
        end                                              

        // 8. fmv.w.x: f[rd] = x[rs1] (copia de 32 bits sin conversión)
        7'b1111000: begin		// Código funct7 para mover bits crudos de entero a flotante (fmv.w.x)
          if (rs2 == 5'b00000 && funct3 == 3'b000) begin  // Exige rs2 == 00000 y funct3 == 000 según estándar RISC-V RV32F
            FRegWrite  = 1'b1;		// Habilita escritura en el banco de registros FLOTANTES f[rd]
            FResultSrc = 1'b1;		// Activa ruta directa (bypass): copia SrcA (x[rs1]) hacia f[rd] sin pasar por fpu_alu
          end		// Fin de verificación de campos fijos de fmv.w.x
        end		

        default: begin // Cualquier otro funct7 no soportado en esta entrega
          // Mantiene todas las señales de escritura en 0 (valores por defecto seguros)
        end		// Fin de la rama default

      endcase		// Fin de la evaluación de case funct7
    end		// Fin del bloque if (IsFloat)
  end		// Fin del bloque combinacional always_comb

endmodule                                              