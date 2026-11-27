
module maindec(input  logic [6:0] op,                     // Entrada de 7 bits: opcode de la instrucción (Instr[6:0])
               output logic [1:0] ResultSrc,              // Salida de 2 bits: selecciona fuente base para escritura en x[rd] (ALU, Mem, PC+4)
               output logic       MemWrite,               // Salida de 1 bit: 1 habilita escritura en memoria de datos (solo sw)
               output logic       Branch, ALUSrc,         // Salidas de 1 bit: Branch=1 para saltos condicionales; ALUSrc=1 elige inmediato en ALU entera
               output logic       RegWrite, Jump,         // Salidas de 1 bit: RegWrite=1 escribe en x[rd] (enteros); Jump=1 para jal/jalr
               output logic [1:0] ImmSrc,                 // Salida de 2 bits: indica el formato de extensión de signo (I, S, B, J)
               output logic [1:0] ALUOp);                 // Salida de 2 bits: código intermedio enviado al decodificador de la ALU entera (aludec)

  logic [10:0] controls;                                  // Bus interno de 11 bits que agrupa todas las señales de control para asignarlo en una línea

  assign {RegWrite, ImmSrc, ALUSrc, MemWrite,             // Desempaqueta los 5 bits superiores del bus 'controls' hacia las primeras 4 salidas
          ResultSrc, Branch, ALUOp, Jump} = controls;     // Desempaqueta los 6 bits inferiores del bus 'controls' hacia las salidas restantes

  always_comb                                             // Bloque combinacional que evalúa el opcode de la instrucción actual
    case(op)                                              // Selecciona el vector de control de 11 bits según el opcode
    // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUOp_Jump  <-- Guía visual del orden exacto de los 11 bits
      7'b0000011: controls = 11'b1_00_1_0_01_0_00_0;      // lw: escribe en x[rd] (1), Imm tipo I (00), usa Imm (1), lee Mem (ResultSrc=01)
      7'b0100011: controls = 11'b0_01_1_1_00_0_00_0;      // sw: no escribe reg (0), Imm tipo S (01), usa Imm (1), escribe Mem (MemWrite=1)
      7'b0110011: controls = 11'b1_xx_0_0_00_0_10_0;      // R-type entero: escribe x[rd] (1), usa rs2 (ALUSrc=0), resultado ALU (00), ALUOp=10
      7'b1100011: controls = 11'b0_10_0_0_00_1_01_0;      // B-type (beq/bne/blt/bge): no escribe reg (0), Imm tipo B (10), Branch=1, ALUOp=01
      7'b0010011: controls = 11'b1_00_1_0_00_0_10_0;      // I-type ALU (addi, etc.): escribe x[rd] (1), Imm tipo I (00), ALUSrc=1, ALUOp=10
      7'b1101111: controls = 11'b1_11_0_0_10_0_00_1;      // jal: guarda PC+4 en x[rd] (RegWrite=1, ResultSrc=10), Imm tipo J (11), Jump=1
      7'b1100111: controls = 11'b1_00_1_0_10_0_00_1;      // jalr: guarda PC+4 en x[rd] (RegWrite=1, ResultSrc=10), Imm tipo I (00), ALUSrc=1, Jump=1
      7'b1010011: controls = 11'b0_xx_0_0_00_0_00_0;      // RV32F (punto flotante): apaga MemWrite, Branch, Jump y RegWrite entero para evitar estados X
      default:    controls = 11'bx_xx_x_x_xx_x_xx_x;      // Instrucción no implementada: asigna 'don't care' (x) para optimización lógica
    endcase                                               // Fin del bloque case(op)
endmodule                                                 // Fin del módulo maindec