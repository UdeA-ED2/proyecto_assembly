transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -sv -work work +incdir+C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo {C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo/fpu_pkg.sv}
vlog -sv -work work +incdir+C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo {C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo/fpu_unpack.sv}
vlog -sv -work work +incdir+C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo {C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo/fpu_alu.sv}
vlog -sv -work work +incdir+C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo {C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo/fpu_i2f.sv}
vlog -sv -work work +incdir+C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo {C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo/fpu_f2i.sv}
vlog -sv -work work +incdir+C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo {C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo/fpu_mul.sv}
vlog -sv -work work +incdir+C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo {C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo/fpu_div.sv}
vlog -sv -work work +incdir+C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo {C:/Users/Julia/Downloads/RiscV-SystemVerilog/ProcesadorUniciclo/fpu_add_sub.sv}

