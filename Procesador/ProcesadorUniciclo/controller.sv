//Unidad de control completa

module controller(input  logic [6:0] op,
                  input  logic [2:0] funct3,
                  input  logic       funct7b5,
                  input  logic       Zero,
						input  logic       lt,//foco que nos dice si es menor que
                  output logic [1:0] ResultSrc,
                  output logic       MemWrite,
                  output logic [1:0] PCSrc, 
                  output logic       ALUSrc, RegWrite, Jump,
                  output logic [1:0] ImmSrc,
                  output logic [2:0] ALUControl);

  logic [1:0] ALUOp;
  logic       Branch;
 
//maindec sera la unidad central de bajo nivel de la 
  maindec md(op, ResultSrc, MemWrite, Branch,
             ALUSrc, RegWrite, Jump, ImmSrc, ALUOp);
//parte de abajo de la unidad de control de bajo nivel 
 aludec  ad(op[5], funct3, funct7b5, ALUOp, ALUControl);

 
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
