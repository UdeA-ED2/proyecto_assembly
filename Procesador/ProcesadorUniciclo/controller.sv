//Unidad de control completa

module controller(input  logic [6:0] op,             // Campo opcode (Instr[6:0])
                  input  logic [2:0] funct3,         // Campo funct3 (Instr[14:12])
                  input  logic [4:0] rs2,            // <Campo rs2 (Instr[24:20]) para fpudec
                  input  logic [6:0] funct7,         // <Campo funct7 completo (Instr[31:25], reemplazando a funct7b5)
                  input  logic       Zero,           // Bandera Zero de la ALU entera
                  input  logic       lt,             // Bandera Less Than de la ALU entera (Entrega 4)
                  output logic [2:0] ResultSrc,      // <mux modificado Ampliado de 2 a 3 bits (000 a 100)
                  output logic       MemWrite,       // 1 = escribe en memoria de datos o LEDs
                  output logic [1:0] PCSrc,          // Selector de PCNext (00=PC+4, 01=PCTarget, 10=ALUResult)
                  output logic       ALUSrc,         // 0 = SrcB entero es registro; 1 = es inmediato
                  output logic       RegWrite,       // 1 = escribe en banco entero x[rd] (enteros + fcvt.w.s + fmv.x.w)
                  output logic       Jump,           // 1 = instrucción jal o jalr
                  output logic [1:0] ImmSrc,         // Tipo de extensión de inmediato
                  output logic [2:0] ALUControl,     // Selector de operación de la ALU entera
                  output logic [2:0] FPUControl,     // < Selector de operación de fpu_alu (3 bits)
                  output logic       FRegWrite,      // < escribe en banco flotante f[rd]
                  output logic       FPUSrcASel,     // < entrada 'a' de FPU es fRD1; 1 = es SrcA (x[rs1])
                  output logic       FResultSrc);    // < guarda FPUResult en f[rd]; 1 = copia SrcA (fmv.w.x)

  logic [1:0] ALUOp;
  logic       Branch;
  
  //NUEVAS SEÑALES INTERNAS PARA FLOAT
  logic [1:0] BaseResultSrc;                         // Recibe los 2 bits originales de ResultSrc desde maindec
  logic       IntRegWrite;                           // Recibe el RegWrite original de enteros desde maindec
  logic       FPRegWrite;                            // Vale 1 cuando fcvt.w.s o fmv.x.w deben escribir en x[rd]
  logic       FPToIntMove;                           // 0 = fcvt.w.s (usa FPUResult); 1 = fmv.x.w (usa fRD1)
  logic       IsFloat;                               // Vale 1 cuando opcode == 7'b1010011 (instrucción flotante)

  // Detecta si la instrucción actual pertenece a la extensión de punto flotante RV32F
  assign IsFloat = (op == 7'b1010011);
  
 
//maindec sera la unidad central de bajo nivel de la 
maindec md(op, BaseResultSrc, MemWrite, Branch,
             ALUSrc, IntRegWrite, Jump, ImmSrc, ALUOp);
//parte de abajo de la unidad de control de bajo nivel 
 aludec  ad(op[5], funct3, funct7[5], ALUOp, ALUControl);
 
 //<Decodificador de instrucciones de punto flotante
  fpudec  fd(IsFloat, funct7, rs2, funct3,
             FPUControl, FRegWrite, FPRegWrite,
             FPUSrcASel, FResultSrc, FPToIntMove);
				 
 // <Se escribe en el banco entero x[rd] si lo pide una instrucción entera
 //     (IntRegWrite) O si lo pide una instrucción flotante hacia entero (FPRegWrite)
  assign RegWrite = IntRegWrite | FPRegWrite;

  // <Construcción de ResultSrc de 3 bits para el multiplexor 5-a-1 de x[rd]
  // 3'b000: ALUResult | 3'b001: ReadData | 3'b010: PCPlus4 | 3'b011: FPUResult | 3'b100: fRD1
  always_comb begin
    if (FPRegWrite)                                  // Si es fcvt.w.s o fmv.x.w...
      ResultSrc = FPToIntMove ? 3'b100 : 3'b011;     // ...100 copia fRD1 directo (fmv.x.w); 011 toma FPUResult (fcvt.w.s)
    else                                             // Si es una instrucción entera normal...
      ResultSrc = {1'b0, BaseResultSrc};             // ...conserva exactamente 000, 001 o 010 de maindec
  end

				 

 //-------------------------
 //Evaluacion de salto 
 
  logic TakeBranch;
  logic cond;
  logic isjalr;
  
  //assigna el op de jalr para saber que direccion sale
  assign isjalr = (op==7'b1100111);

  // Si funct3 empieza por '1' (como el 100 de blt), mira el foquito 'Lt'. Si no, mira 'Zero'.
  assign cond = funct3[2] ? lt : Zero; 
  
  // funct3 termina en '0' para blt. Esta línea ajusta la condición correctamente.
  assign TakeBranch = cond ^ funct3[0]; 

  //aqui escoge que direccion le entregara al pc
  always_comb begin
  if(isjalr)
			PCSrc = 2'b10; //salta a la salida de la ALU
   else if((Branch & TakeBranch) | Jump)
			PCSrc = 2'b01; //Branches tomados o jal saltan a PCTarget
	else 
			PCSrc = 2'b00; //normal pc+4
	end
 
endmodule
