module riscvsingle(input  logic        clk, reset,      // Recibe la señal de reloj y el reset síncrono del sistema
                   output logic [31:0] PCNext,          // Envía la dirección de la siguiente instrucción hacia la memoria de instrucciones
                   input  logic [31:0] Instr,           // Recibe la instrucción de 32 bits leída desde la memoria
                   output logic        MemWrite,        // Envía la señal de habilitación de escritura para memoria de datos o periféricos
                   output logic [31:0] ALUResult,       // Envía el resultado de la ALU entera o la dirección de acceso a memoria
                   output logic [31:0] WriteData,       // Envía el dato entero que se va a escribir en memoria o LEDs
                   input  logic [31:0] ReadData);       // Recibe el dato leído desde la memoria de datos o Switches
 
  logic ALUSrc, RegWrite, Jump, Zero, lt;
  logic [2:0] ResultSrc;
  logic [1:0] ImmSrc,PCSrc;
  logic [2:0] ALUControl;
  
  //controles de fpu
  logic [2:0] FPUControl;	// Cable interno de 3 bits que indica la operación a la FPU
  logic       FRegWrite;	// Cable interno de 1 bit que habilita escritura en el banco flotante f[rd]
  logic       FPUSrcASel;	// Cable interno de 1 bit que elige el origen del operando A de la FPU
  logic       FResultSrc;		// Cable interno de 1 bit que elige el dato a guardar en f[rd]  

  controller c(Instr[6:0], Instr[14:12], Instr[24:20], Instr[31:25], // Envía opcode, funct3, rs2 y funct7 a la unidad de control
               Zero, lt,                                // Envía las banderas Zero y lt calculadas por la ALU entera
               ResultSrc, MemWrite, PCSrc,              // Recibe selección de resultado entero, escritura en memoria y salto de PC
               ALUSrc, RegWrite, Jump,                  // Recibe selección de operando B entero, escritura en x[rd] y salto
               ImmSrc, ALUControl,                      // Recibe formato de inmediato y código de operación de la ALU entera
               FPUControl, FRegWrite, FPUSrcASel, FResultSrc);
  
  datapath dp(clk, reset, ResultSrc, PCSrc,             // Conecta reloj, reset, selección de resultado entero y salto de PC
              ALUSrc, RegWrite,                         // Conecta selección de operando B entero y escritura en x[rd]
              ImmSrc, ALUControl,                       // Conecta formato de inmediato y operación de la ALU entera
              FPUControl, FRegWrite, FPUSrcASel, FResultSrc, // Conecta las señales de control de punto flotante
              Zero, lt, PCNext, Instr,                  // Entrega banderas Zero/lt y PCNext; recibe la instrucción actual
              ALUResult, WriteData, ReadData);	// Entrega dirección/resultado y dato a escribir; recibe dato leído
endmodule
