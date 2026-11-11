module datapath(input  logic        clk, reset,
                input  logic [1:0]  ResultSrc, 
                input  logic        PCSrc, ALUSrc,
                input  logic        RegWrite,
                input  logic [1:0]  ImmSrc,
                input  logic [2:0]  ALUControl,
                output logic        Zero,lt,
                output logic [31:0] PCNext,
                input  logic [31:0] Instr,
                output logic [31:0] ALUResult, WriteData,
                input  logic [31:0] ReadData);

  logic [31:0] PC, PCPlus4, PCTarget;
  logic [31:0] ImmExt;
  logic [31:0] SrcA, SrcB;
  logic [31:0] Result;

  // next PC logic/ PC actual
  flopr #(32) pcreg(clk, reset, PCNext, PC); 
  adder       pcadd4(PC, 32'd4, PCPlus4); //pcadd4: Calcula la dirección de la siguiente instrucción secuencial ($PC + 4$).  
  adder       pcaddbranch(PC, ImmExt, PCTarget); //pcaddbranch: Calcula la dirección destino de saltos ($PCTarget = PC + ImmExt$). 
  mux2 #(32)  pcmux(PCPlus4, PCTarget, PCSrc, PCNext); //calcula siguiente direccion de memoria escogiendo si sumando la extencion o solo sumando +4
 
  // register file logic
  regfile     rf(clk, RegWrite, Instr[19:15], Instr[24:20], 
                 Instr[11:7], Result, SrcA, WriteData);
  //unidad que extiende el signo
  extend      ext(Instr[31:7], ImmSrc, ImmExt);

  // ALU logic
  mux2 #(32)  srcbmux(WriteData, ImmExt, ALUSrc, SrcB); //unidad que entra a la Alu como SrcB
  alu         alu(SrcA, SrcB, ALUControl, ALUResult, Zero,lt); //Instancia de la Alu 
  mux3 #(32)  resultmux(ALUResult, ReadData, PCPlus4, ResultSrc, Result); 
endmodule