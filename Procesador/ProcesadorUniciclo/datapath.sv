module datapath(input  logic        clk, reset,      // Reloj y reset síncrono
                input  logic [2:0]  ResultSrc,       // <MODIFICADO: Ampliado a 3 bits (5 fuentes para x[rd])
                input  logic [1:0]  PCSrc,           // Selector de PCNext 
                input  logic        ALUSrc,          // Selector de SrcB entero
                input  logic        RegWrite,        // Habilitación de escritura en banco entero x[rd]
                input  logic [1:0]  ImmSrc,          // Selector de formato de inmediato 
                input  logic [2:0]  ALUControl,      // Operación de ALU entera 
                input  logic [2:0]  FPUControl,      // <Operación de fpu_alu (FPU_ADD .. FPU_I2F)
                input  logic        FRegWrite,       // <Habilitación de escritura en banco flotante f[rd]
                input  logic        FPUSrcASel,      // <0 = puerto 'a' FPU usa fRD1; 1 = usa SrcA
                input  logic        FResultSrc,      // <0 = f[rd] guarda FPUResult; 1 = guarda SrcA
                output logic        Zero, lt,        // Banderas Zero y Less Than
                output logic [31:0] PCNext,          // Siguiente dirección de instrucción 
                input  logic [31:0] Instr,           // Instrucción actual de 32 bits 
                output logic [31:0] ALUResult,       // Resultado ALU entera / dirección memoria
                output logic [31:0] WriteData,       // Dato a escribir en memoria o LEDs
                input  logic [31:0] ReadData);       // Dato leído desde memoria o Switches
	
  //---SEÑALES INTERNAS DE PUNTO FLOTANTE---			 
  logic [31:0] PC, PCPlus4, PCTarget;
  logic [31:0] ImmExt;
  logic [31:0] SrcA, SrcB;
  logic [31:0] Result;
  
  //---SEÑALES INTERNAS DE PUNTO FLOTANTE---
  logic [31:0] fRD1, fRD2;                           // Datos de 32 bits leídos desde f[rs1] y f[rs2]
  logic [31:0] FPUSrcA;                              // Operando que entra al puerto 'a' de fpu_alu
  logic [31:0] FPUResult;                            // Resultado de 32 bits calculado por fpu_alu
  logic [31:0] FResult;                              // Dato final que se escribe en el banco flotante f[rd]
  
  

  // next PC logic/ PC actual
  flopr #(32) pcreg(clk, reset, PCNext, PC); 
  adder       pcadd4(PC, 32'd4, PCPlus4); //pcadd4: Calcula la dirección de la siguiente instrucción secuencial ($PC + 4$).  
  adder       pcaddbranch(PC, ImmExt, PCTarget); //pcaddbranch: Calcula la dirección destino de saltos ($PCTarget = PC + ImmExt$). 
  mux3 #(32)  pcmux(PCPlus4, PCTarget,ALUResult, PCSrc, PCNext); //calcula siguiente direccion de memoria escogiendo si sumando la extencion o solo sumando +4
 
  // register file logic
  regfile     rf(clk, RegWrite, Instr[19:15], Instr[24:20], 
                 Instr[11:7], Result, SrcA, WriteData);
  //unidad que extiende el signo
  extend      ext(Instr[31:7], ImmSrc, ImmExt);

  // ALU logic
  mux2 #(32)  srcbmux(WriteData, ImmExt, ALUSrc, SrcB); //unidad que entra a la Alu como SrcB
  alu         alu(SrcA, SrcB, ALUControl, ALUResult, Zero,lt); //Instancia de la Alu 
  //mux3 #(32)  resultmux(ALUResult, ReadData, PCPlus4, ResultSrc, Result); se cambia por un always
 
 
 // ----------------------------------------
  //Banco de 32 registros flotantes (f0 - f31): lee f[rs1] y f[rs2], escribe FResult en f[rd]
  fregfile    frf(clk, FRegWrite, Instr[19:15], Instr[24:20],
                  Instr[11:7], FResult, fRD1, fRD2);

  //Mux de entrada A de la FPU:
  //    - Si FPUSrcASel == 0: pasa fRD1 (f[rs1]) usado por fadd.s, fsub.s, fmul.s, fdiv.s, fcvt.w.s
  //    - Si FPUSrcASel == 1: pasa SrcA (x[rs1]) usado por fcvt.s.w (entero a flotante)
  mux2 #(32)  fpusrcamux(fRD1, SrcA, FPUSrcASel, FPUSrcA);

  //Instancia de tu ALU de Punto Flotante de 32 bits
  //    Puerto 'a' recibe FPUSrcA, puerto 'b' recibe siempre fRD2 (f[rs2])
  fpu_alu     fpu(.a(FPUSrcA), .b(fRD2), .fpu_control(FPUControl), .result(FPUResult));

  // Mux de resultado hacia el banco flotante f[rd]:
  //    - Si FResultSrc == 0: guarda FPUResult -> usado por fadd.s, fsub.s, fmul.s, fdiv.s, fcvt.s.w
  //    - Si FResultSrc == 1: guarda SrcA directo -> usado por fmv.w.x (copia cruda x[rs1] -> f[rd])
  mux2 #(32)  fresultmux(FPUResult, SrcA, FResultSrc, FResult);

  // 5. Mux 5-a-1 de resultado hacia el banco entero x[rd] (reemplaza al mux3 anterior):
  always_comb begin
    case (ResultSrc)
      3'b000:  Result = ALUResult;                   // Operaciones enteras R-type e I-type (original)
      3'b001:  Result = ReadData;                    // Carga desde memoria lw (original)
      3'b010:  Result = PCPlus4;                     // Dirección de retorno en jal y jalr (original)
      3'b011:  Result = FPUResult;                   // <Conversión float -> int (fcvt.w.s)
      3'b100:  Result = fRD1;                        // <NUEVO: Copia cruda float -> int (fmv.x.w)
      default: Result = ALUResult;                   // Valor seguro por defecto
    endcase
  end

endmodule