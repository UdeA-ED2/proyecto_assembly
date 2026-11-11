/*
 * This module is the TOP of the ARM single-cycle processor
 */ 
module top(input logic clk, nreset,
			  input logic [9:0] switches,
			  output logic [9:0] leds);
	
	
	// Internal signals
	/*PCNext (32 bits): Dirección generada por el procesador para leer la siguiente instrucción desde la memoria.   
	  Instr (32 bits): Código máquina leído desde la memoria y enviado al procesador para su decodificación.   
	  DataAdr (ALUResult, 32 bits): Dirección calculada por la ALU para operaciones de lectura (lw) o escritura (sw).   
	  WriteData (32 bits): Dato que el procesador quiere escribir en la memoria o en los LEDs.   
	  ReadData (32 bits): Dato leído desde la memoria RAM o desde los Switches de la placa.   
	  MemWrite (1 bit): Señal de habilitación de escritura en memoria/periférico.   
	*/
	logic MemWrite, nSyncReset, syncReset;
	logic [31:0] PCNext, Instr, ReadData;
	logic [31:0] WriteData, DataAdr;	
	
	assign syncReset = ~nSyncReset;
	
	// Instantiate Memory
	mem mem(clk, syncReset, MemWrite, PCNext, DataAdr, WriteData, Instr, ReadData, switches, leds);
	
	// Instantiate processor
	//arm arm (clk, syncReset, PCNext, Instr, MemWrite, DataAdr, WriteData, ReadData);
	//riscvsingle rvsingle(clk, reset, PC, Instr, MemWrite, DataAdr, WriteData, ReadData);
	riscvsingle rvsingle(clk, syncReset, PCNext, Instr, MemWrite, DataAdr, WriteData, ReadData);
	
	// Create a synchronous reset, required by memory
	flopr #(1) resetReg(clk, ~nreset, 1'b1, nSyncReset);

endmodule