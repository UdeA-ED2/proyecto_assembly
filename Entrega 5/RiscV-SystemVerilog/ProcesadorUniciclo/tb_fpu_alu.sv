`timescale 1ns / 1ps //10 ns

module tb_fpu_alu;

    // Importa las constantes (FP32_POS_INF, FP32_QNAN, etc.) y el enum fpu_op_t
    import fpu_pkg::*;

    // =========================================================================
    // 1. SEÑALES DE CONEXIÓN CON EL DUT (Device Under Test)
    // =========================================================================
    logic [31:0] a;
    logic [31:0] b;
    fpu_op_t     fpu_control;
    logic [31:0] result;

    // Contadores para el resumen final
    int total_tests  = 0;
    int passed_tests = 0;
    int failed_tests = 0;

    // =========================================================================
    // 2. INSTANCIACIÓN DE LA FPU (DUT)
    // =========================================================================
    fpu_alu dut (
        .a           (a),
        .b           (b),
        .fpu_control (fpu_control),
        .result      (result)
    );

    // =========================================================================
    // 3. TAREA AUTOMÁTICA DE APLICACIÓN Y VERIFICACIÓN DE PRUEBAS
    // =========================================================================
    task automatic run_test(
        input fpu_op_t     op,
        input logic [31:0] op_a,
        input logic [31:0] op_b,
        input logic [31:0] expected,
        input string       desc
    );
        string op_name;
        begin
            total_tests++;

            // Traduce el código de control a texto legible para los reportes
            case (op)
                FPU_ADD: op_name = "ADD (Suma)";
                FPU_SUB: op_name = "SUB (Resta)";
                FPU_MUL: op_name = "MUL (Multiplicacion)";
                FPU_DIV: op_name = "DIV (Division)";
                FPU_F2I: op_name = "F2I (Float -> Int)";
                FPU_I2F: op_name = "I2F (Int -> Float)";
                default: op_name = "DESCONOCIDA";
            endcase

            // Aplica los estímulos a las entradas de la FPU
            fpu_control = op;
            a           = op_a;
            b           = op_b;

            // Espera 10 ns para que la lógica combinacional se estabilice
            #10;

            // Comparación exacta de 32 bits (=== detecta también estados X o Z)
            if (result === expected) begin
                passed_tests++;
                $display("[PASS] Prueba %02d | %-20s | %s -> Res: 0x%08h",
                         total_tests, op_name, desc, result);
            end else begin
                failed_tests++;
                $display("[FAIL] Prueba %02d | %s", total_tests, desc);
                $display("       Operacion : %s (fpu_control = %3b)", op_name, op);
                $display("       Operando A: 0x%08h | Operando B: 0x%08h", op_a, op_b);
                $display("       Esperado  : 0x%08h | Obtenido  : 0x%08h", expected, result);
            end
        end
    endtask

    // =========================================================================
    // 4. BATERÍA DE VECTORES DE PRUEBA (52 CASOS EN HEXADECIMAL)
    // =========================================================================
    initial begin
        $display(" INICIANDO SIMULACION DE VERIFICACION - FPU IEEE-754 SINGLE PRECISION...");

        // ---------------------------------------------------------------------
        // BLOQUE A: SUMA (FPU_ADD = 3'b000)
        // ---------------------------------------------------------------------
        run_test(FPU_ADD, 32'h4148_0000, 32'h4050_0000, 32'h417C_0000, "Pos + Pos: 12.5 + 3.25 = 15.75");
        run_test(FPU_ADD, 32'hC118_0000, 32'hC088_0000, 32'hC15C_0000, "Neg + Neg: -9.5 + -4.25 = -13.75");
        run_test(FPU_ADD, 32'hC236_0000, 32'h41A2_0000, 32'hC1CA_0000, "Neg + Pos: -45.5 + 20.25 = -25.25");
        run_test(FPU_ADD, 32'h3E00_0000, 32'h3D80_0000, 32'h3E40_0000, "Pequenos: 0.125 + 0.0625 = 0.1875");
        run_test(FPU_ADD, 32'h3727_C5AC, 32'h37A7_C5AC, 32'h37FB_A882, "5 decimales: 0.00001 + 0.00002");
        run_test(FPU_ADD, 32'h4974_2408, 32'h48F4_2408, 32'h49B7_1B06, "Gran magnitud: 1000000.5 + 500000.25");
        run_test(FPU_ADD, 32'h4248_7E6A, 32'h0000_0000, 32'h4248_7E6A, "Con cero: 50.12345 + 0.0");
        run_test(FPU_ADD, 32'h40F0_0000, 32'hC0F0_0000, 32'h0000_0000, "Resultado cero: 7.5 + (-7.5) = 0.0");
        run_test(FPU_ADD, 32'h4EFF_FFFF, 32'h42FE_0000, 32'h4EFF_FFFF, "Limite cercano: 2147483520.0 + 127.0");
        run_test(FPU_ADD, 32'h7F80_0000, 32'h42C8_0000, 32'h7F80_0000, "Infinito: +Inf + 100.0 = +Inf");
        run_test(FPU_ADD, 32'h7F80_0000, 32'hFF80_0000, 32'h7FC0_0000, "Indeterminacion NaN: +Inf + (-Inf)");

        // ---------------------------------------------------------------------
        // BLOQUE B: RESTA (FPU_SUB = 3'b001)
        // ---------------------------------------------------------------------
        run_test(FPU_SUB, 32'h4249_0000, 32'h42C9_8000, 32'hC24A_0000, "Pos - Pos (neg): 50.25 - 100.75 = -50.5");
        run_test(FPU_SUB, 32'h40A0_0000, 32'h4090_0000, 32'h3F00_0000, "Cancelacion: 5.0 - 4.5 = 0.5");
        run_test(FPU_SUB, 32'hC128_0000, 32'h4090_0000, 32'hC170_0000, "Neg - Pos: -10.5 - 4.5 = -15.0");
        run_test(FPU_SUB, 32'h42C9_0000, 32'h0000_0000, 32'h42C9_0000, "Con cero: 100.5 - 0.0 = 100.5");
        run_test(FPU_SUB, 32'h42F6_E666, 32'h42F6_E666, 32'h0000_0000, "Resultado cero: 123.45 - 123.45 = 0.0");
        run_test(FPU_SUB, 32'h7F80_0000, 32'h7F80_0000, 32'h7FC0_0000, "Indeterminacion NaN: +Inf - (+Inf)");

        // ---------------------------------------------------------------------
        // BLOQUE C: MULTIPLICACIÓN (FPU_MUL = 3'b010)
        // ---------------------------------------------------------------------
        run_test(FPU_MUL, 32'h4148_0000, 32'h4080_0000, 32'h4248_0000, "Pos * Pos: 12.5 * 4.0 = 50.0");
        run_test(FPU_MUL, 32'hC040_0000, 32'h4020_0000, 32'hC0F0_0000, "Neg * Pos: -3.0 * 2.5 = -7.5");
        run_test(FPU_MUL, 32'hBFC0_0000, 32'hBFC0_0000, 32'h4010_0000, "Neg * Neg: -1.5 * -1.5 = 2.25");
        run_test(FPU_MUL, 32'h3F00_0000, 32'h3E80_0000, 32'h3E00_0000, "Pequenos: 0.5 * 0.25 = 0.125");
        run_test(FPU_MUL, 32'h47C3_5000, 32'h469C_4000, 32'h4EEE_6B28, "Gran magnitud: 100000.0 * 20000.0 = 2e9");
        run_test(FPU_MUL, 32'h447A_0000, 32'h0000_0000, 32'h0000_0000, "Resultado cero: 1000.0 * 0.0 = 0.0");
        run_test(FPU_MUL, 32'h8000_0000, 32'h40A0_0000, 32'h8000_0000, "Signo cero: -0.0 * 5.0 = -0.0");
        run_test(FPU_MUL, 32'hFF80_0000, 32'h4000_0000, 32'hFF80_0000, "Infinito: -Inf * 2.0 = -Inf");
        run_test(FPU_MUL, 32'h0000_0000, 32'h7F80_0000, 32'h7FC0_0000, "Indeterminacion NaN: 0.0 * +Inf");

        // ---------------------------------------------------------------------
        // BLOQUE D: DIVISIÓN (FPU_DIV = 3'b011)
        // ---------------------------------------------------------------------
        run_test(FPU_DIV, 32'h42C8_0000, 32'h4100_0000, 32'h4148_0000, "Pos / Pos: 100.0 / 8.0 = 12.5");
        run_test(FPU_DIV, 32'hC0C0_0000, 32'h4000_0000, 32'hC040_0000, "Neg / Pos: -6.0 / 2.0 = -3.0");
        run_test(FPU_DIV, 32'h3F80_0000, 32'h4080_0000, 32'h3E80_0000, "Fraccion < 1: 1.0 / 4.0 = 0.25");
        run_test(FPU_DIV, 32'h0000_0000, 32'hC0A0_0000, 32'h8000_0000, "Cero / Neg: 0.0 / -5.0 = -0.0");
        run_test(FPU_DIV, 32'h4248_7E6A, 32'h0000_0000, 32'h7F80_0000, "Div por cero (+): 50.12345 / 0.0 = +Inf");
        run_test(FPU_DIV, 32'hC120_0000, 32'h0000_0000, 32'hFF80_0000, "Div por cero (-): -10.0 / 0.0 = -Inf");
        run_test(FPU_DIV, 32'h0000_0000, 32'h0000_0000, 32'h7FC0_0000, "Indeterminacion NaN: 0.0 / 0.0");
        run_test(FPU_DIV, 32'h7F80_0000, 32'hFF80_0000, 32'h7FC0_0000, "Indeterminacion NaN: +Inf / -Inf");

        // ---------------------------------------------------------------------
        // BLOQUE E: CONVERSIÓN FLOAT -> INT (FPU_F2I = 3'b100)
        // ---------------------------------------------------------------------
        run_test(FPU_F2I, 32'h414C_0000, 32'h0000_0000, 32'h0000_000C, "Truncamiento pos: 12.75 -> 12");
        run_test(FPU_F2I, 32'hC118_0000, 32'h0000_0000, 32'hFFFF_FFF7, "Truncamiento neg: -9.5 -> -9");
        run_test(FPU_F2I, 32'h3F7F_FF58, 32'h0000_0000, 32'h0000_0000, "Menor a 1: 0.99999 -> 0");
        run_test(FPU_F2I, 32'hBF40_0000, 32'h0000_0000, 32'h0000_0000, "Negativo > -1: -0.75 -> 0");
        run_test(FPU_F2I, 32'h8000_0000, 32'h0000_0000, 32'h0000_0000, "Cero negativo: -0.0 -> 0");
        run_test(FPU_F2I, 32'h4EFF_FFFF, 32'h0000_0000, 32'h7FFF_FF80, "Limite max exacto: 2147483520.0");
        run_test(FPU_F2I, 32'hCF00_0000, 32'h0000_0000, 32'h8000_0000, "Limite min exacto: -2147483648.0");
        run_test(FPU_F2I, 32'h4F32_D05E, 32'h0000_0000, 32'h7FFF_FFFF, "Saturacion > INT_MAX: 3.0e9 -> 0x7FFFFFFF");
        run_test(FPU_F2I, 32'hCF32_D05E, 32'h0000_0000, 32'h8000_0000, "Saturacion < INT_MIN: -3.0e9 -> 0x80000000");
        run_test(FPU_F2I, 32'h7F80_0000, 32'h0000_0000, 32'h7FFF_FFFF, "Saturacion +Inf -> 0x7FFFFFFF");
        run_test(FPU_F2I, 32'hFF80_0000, 32'h0000_0000, 32'h8000_0000, "Saturacion -Inf -> 0x80000000");
        run_test(FPU_F2I, 32'h7FC0_0000, 32'h0000_0000, 32'h7FFF_FFFF, "NaN -> 0x7FFFFFFF (Regla RISC-V)");

        // ---------------------------------------------------------------------
        // BLOQUE F: CONVERSIÓN INT -> FLOAT (FPU_I2F = 3'b101)
        // ---------------------------------------------------------------------
        run_test(FPU_I2F, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000, "Cero: 0 -> 0.0");
        run_test(FPU_I2F, 32'h0000_0001, 32'h0000_0000, 32'h3F80_0000, "Unidad: 1 -> 1.0");
        run_test(FPU_I2F, 32'hFFFF_FFF7, 32'h0000_0000, 32'hC110_0000, "Negativo: -9 -> -9.0");
        run_test(FPU_I2F, 32'h0000_0400, 32'h0000_0000, 32'h4480_0000, "Potencia de 2: 1024 -> 1024.0");
        run_test(FPU_I2F, 32'h7FFF_FFFF, 32'h0000_0000, 32'h4EFF_FFFF, "Limite max: 2147483647 -> 2147483520.0");
        run_test(FPU_I2F, 32'h8000_0000, 32'h0000_0000, 32'hCF00_0000, "Limite min: -2147483648 -> -2147483648.0");

        // ---------------------------------------------------------------------
        // RESUMEN FINAL DE EJECUCIÓN
        // ---------------------------------------------------------------------
        #10;
        $display("=========================================================================");
        $display(" RESUMEN FINAL DE PRUEBAS:");
        $display("   Total ejecutadas : %0d", total_tests);
        $display("   Pruebas aprobadas: %0d", passed_tests);
        $display("   Pruebas fallidas : %0d", failed_tests);
        $display("=========================================================================");

        if (failed_tests == 0)
            $display(" RESULTADO GLOBAL: TODAS LAS PRUEBAS PASARON EXITOSAMENTE.");
        else
            $display(" RESULTADO GLOBAL: SE DETECTARON ERRORES. REVISA LOS [FAIL].");

        $stop;
    end

endmodule