// Fade

module fade #(
    parameter INC_DEC_INTERVAL = 10000,     // CLK frequency is 12MHz, so 10,000 cycles is 1/1200 s
    parameter INC_DEC_MAX = 200,            // Transition after 200 increments / decrements, which is 60 deg (1/6 s)
    parameter HOLD_MAX = 2 * INC_DEC_MAX,   // Hold state
    parameter PWM_INTERVAL = 1200,          // CLK frequency is 12MHz, so 1,200 cycles is 100us
    parameter INC_DEC_VAL = PWM_INTERVAL / INC_DEC_MAX,
    parameter INIT_STATE = 2'd0,            // State at 0 deg
    parameter INIT_COUNT = 0,               // Steps at 0 deg
    parameter INIT_PWM = 0                  // pwm_value at 0 deg
)(
    input logic clk,
    output logic [$clog2(PWM_INTERVAL) - 1:0] pwm_value
);

    // Define state variable values
    localparam PWM_INC   = 2'd0;
    localparam HOLD_HIGH = 2'd1;
    localparam PWM_DEC   = 2'd2;
    localparam HOLD_LOW  = 2'd3;

    // Declare state variables
    logic [1:0] current_state = INIT_STATE;
    logic [1:0] next_state;

    // Declare variables for timing state transitions
    logic [$clog2(INC_DEC_INTERVAL) - 1:0] count = 0;
    logic [$clog2(HOLD_MAX) - 1:0] inc_dec_count = INIT_COUNT;
    logic [$clog2(HOLD_MAX) - 1:0] state_max;
    logic time_to_inc_dec = 1'b0;
    logic time_to_transition = 1'b0;

    initial begin
        pwm_value = INIT_PWM;
    end

    // Register the next state of the FSM
    always_ff @(posedge time_to_transition)
        current_state <= next_state;

    // Compute the next state of the FSM
    always_comb begin
        next_state = 2'bx;
        case (current_state)
            PWM_INC:
                next_state = HOLD_HIGH;
            HOLD_HIGH:
                next_state = PWM_DEC;
            PWM_DEC:
                next_state = HOLD_LOW;
            HOLD_LOW:
                next_state = PWM_INC;
        endcase
    end

    // Number of increments / decrements the current state lasts
    always_comb begin
        case (current_state)
            PWM_INC, PWM_DEC:
                state_max = INC_DEC_MAX;
            default:
                state_max = HOLD_MAX;
        endcase
    end

    // Implement counter for incrementing / decrementing PWM value
    always_ff @(posedge clk) begin
        if (count == INC_DEC_INTERVAL - 1) begin
            count <= 0;
            time_to_inc_dec <= 1'b1;
        end
        else begin
            count <= count + 1;
            time_to_inc_dec <= 1'b0;
        end
    end

    // Increment / Decrement / Hold value as appropriate given current state
    always_ff @(posedge time_to_inc_dec) begin
        case (current_state)
            PWM_INC:
                pwm_value <= pwm_value + INC_DEC_VAL;
            PWM_DEC:
                pwm_value <= pwm_value - INC_DEC_VAL;
            default:
                pwm_value <= pwm_value;
        endcase
    end

    // Implement counter for timing state transitions
    always_ff @(posedge time_to_inc_dec) begin
        if (inc_dec_count == state_max - 1) begin
            inc_dec_count <= 0;
            time_to_transition <= 1'b1;
        end
        else begin
            inc_dec_count <= inc_dec_count + 1;
            time_to_transition <= 1'b0;
        end
    end

endmodule


// PWM generator to fade LED

module pwm #(
    parameter PWM_INTERVAL = 1200       // CLK frequency is 12MHz, so 1,200 cycles is 100us
)(
    input logic clk,
    input logic [$clog2(PWM_INTERVAL) - 1:0] pwm_value,
    output logic pwm_out
);

    // Declare PWM generator counter variable
    logic [$clog2(PWM_INTERVAL) - 1:0] pwm_count = 0;

    // Implement counter for timing transition in PWM output signal
    always_ff @(posedge clk) begin
        if (pwm_count == PWM_INTERVAL - 1) begin
            pwm_count <= 0;
        end
        else begin
            pwm_count <= pwm_count + 1;
        end
    end

    // Generate PWM output signal
    assign pwm_out = (pwm_count > pwm_value) ? 1'b0 : 1'b1;

endmodule


module top #(
    parameter PWM_INTERVAL = 1200       // CLK frequency is 12MHz, so 1,200 cycles is 100us
)(
    input logic     clk,
    output logic    RGB_R,
    output logic    RGB_G,
    output logic    RGB_B
);

    localparam INC_DEC_MAX = 200;

    logic [$clog2(PWM_INTERVAL) - 1:0] r_pwm_value, g_pwm_value, b_pwm_value;
    logic r_pwm_out, g_pwm_out, b_pwm_out;

    // Red
    fade #(
        .PWM_INTERVAL   (PWM_INTERVAL),
        .INC_DEC_MAX    (INC_DEC_MAX),
        .INIT_STATE     (2'd1),             // HOLD_HIGH
        .INIT_COUNT     (INC_DEC_MAX),      // halfway through the hold
        .INIT_PWM       (PWM_INTERVAL)      // full on
    ) u_fade_r (
        .clk            (clk),
        .pwm_value      (r_pwm_value)
    );

    pwm #(
        .PWM_INTERVAL   (PWM_INTERVAL)
    ) u_pwm_r (
        .clk            (clk),
        .pwm_value      (r_pwm_value),
        .pwm_out        (r_pwm_out)
    );

    // Green
    fade #(
        .PWM_INTERVAL   (PWM_INTERVAL),
        .INC_DEC_MAX    (INC_DEC_MAX),
        .INIT_STATE     (2'd0),             // PWM_INC
        .INIT_COUNT     (0),
        .INIT_PWM       (0)                 // off
    ) u_fade_g (
        .clk            (clk),
        .pwm_value      (g_pwm_value)
    );

    pwm #(
        .PWM_INTERVAL   (PWM_INTERVAL)
    ) u_pwm_g (
        .clk            (clk),
        .pwm_value      (g_pwm_value),
        .pwm_out        (g_pwm_out)
    );

    // Blue
    fade #(
        .PWM_INTERVAL   (PWM_INTERVAL),
        .INC_DEC_MAX    (INC_DEC_MAX),
        .INIT_STATE     (2'd3),             // HOLD_LOW
        .INIT_COUNT     (0),
        .INIT_PWM       (0)                 // off
    ) u_fade_b (
        .clk            (clk),
        .pwm_value      (b_pwm_value)
    );

    pwm #(
        .PWM_INTERVAL   (PWM_INTERVAL)
    ) u_pwm_b (
        .clk            (clk),
        .pwm_value      (b_pwm_value),
        .pwm_out        (b_pwm_out)
    );

    // LEDs are active low
    assign RGB_R = ~r_pwm_out;
    assign RGB_G = ~g_pwm_out;
    assign RGB_B = ~b_pwm_out;

endmodule
