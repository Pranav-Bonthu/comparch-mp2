`timescale 1ns / 1ps

module mp2_tb;

    logic clk = 1'b0;
    logic RGB_R, RGB_G, RGB_B;

    always #41.667 clk = ~clk;

    top dut (
        .clk   (clk),
        .RGB_R (RGB_R),
        .RGB_G (RGB_G),
        .RGB_B (RGB_B)
    );

    initial begin
        #10_000;
        for (int deg = 0; deg <= 360; deg += 60) begin
            $display("%3d deg: R %4d G %4d B %4d", deg,
                     dut.r_pwm_value, dut.g_pwm_value, dut.b_pwm_value);
            #(1_000_000_000 / 6);
        end
    end

    initial begin
        $dumpfile("mp2_tb.fst");
        $dumpvars(0, dut.r_pwm_value, dut.g_pwm_value, dut.b_pwm_value);
        $dumpvars(0, RGB_R, RGB_G, RGB_B);
        $dumpvars(0, dut.r_pwm_out, dut.g_pwm_out, dut.b_pwm_out);
        $dumpvars(0, dut.u_fade_r.current_state, dut.u_fade_g.current_state,
                     dut.u_fade_b.current_state);

        #1_100_000_000;
        $display("Simulation finished at %.3f s", $realtime / 1e9);
        $finish;
    end

endmodule
