// modexp.v — Modular exponentiation: result = base^exponent mod modulus
// Uses square-and-multiply with a shift-and-add multiplier.
// 16-bit datapath — fits in a TT 1x1 tile.

`default_nettype none

module modexp (
        input  wire         clk,
        input  wire         rst,
        input  wire         start,
    input  wire [15:0]  base,
    input  wire [15:0]  exponent,
    input  wire [15:0]  modulus,
    output reg  [15:0]  result,
        output reg          done
);

    reg [15:0] mul_a, mul_b, mul_m;
    reg        mul_start;
    wire [15:0] mul_result;
    wire        mul_done;

    modmul mul_inst (
        .clk    (clk),
        .rst    (rst),
        .start  (mul_start),
        .a      (mul_a),
        .b      (mul_b),
        .m      (mul_m),
        .result (mul_result),
        .done   (mul_done)
    );

    localparam S_IDLE     = 3'd0,
               S_INIT     = 3'd1,
               S_CHECK    = 3'd2,
               S_WAIT_RES = 3'd4,
               S_WAIT_SQ  = 3'd6,
               S_DONE     = 3'd7;

    reg [2:0]  state;
    reg [15:0] res, b;
    reg [15:0] exp;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
                    state     <= S_IDLE; res <= 0; b <= 0; exp <= 0;
                    result    <= 0; done <= 0; mul_start <= 0;
                    mul_a     <= 0; mul_b <= 0; mul_m <= 0;
        end else begin
                    mul_start <= 1'b0;
            case (state)
                            S_IDLE: begin
                                                done <= 1'b0;
                                if (start) state <= S_INIT;
                            end
                            S_INIT: begin
                                                res <= 16'd1; b <= base; exp <= exponent;
                                                state <= S_CHECK;
                            end
                            S_CHECK: begin
                                if (exp == 16'd0) begin
                                                        result <= res; state <= S_DONE;
                                end else if (exp[0]) begin
                                                        mul_a <= res; mul_b <= b; mul_m <= modulus;
                                                        mul_start <= 1'b1; state <= S_WAIT_RES;
                                end else begin
                                                        mul_a <= b; mul_b <= b; mul_m <= modulus;
                                                        mul_start <= 1'b1; state <= S_WAIT_SQ;
                                end
                            end
                            S_WAIT_RES: begin
                                if (mul_done) begin
                                                        res   <= mul_result;
                                                        mul_a <= b; mul_b <= b; mul_m <= modulus;
                                                        mul_start <= 1'b1; state <= S_WAIT_SQ;
                                end
                            end
                            S_WAIT_SQ: begin
                                if (mul_done) begin
                                                        b <= mul_result; exp <= exp >> 1; state <= S_CHECK;
                                end
                            end
                            S_DONE: begin
                                                done <= 1'b1; state <= S_IDLE;
                            end
                            default: state <= S_IDLE;
            endcase
        end
    end
endmodule

// modmul: (a * b) % m — shift-and-add, 16 cycles, no large multiplier.
module modmul (
        input  wire         clk,
        input  wire         rst,
        input  wire         start,
    input  wire [15:0]  a,
    input  wire [15:0]  b,
    input  wire [15:0]  m,
    output reg  [15:0]  result,
        output reg          done
);
    reg [15:0] acc, base, bb;
    reg [4:0]  cnt;
    reg        active;

    wire [16:0] base_dbl  = {1'b0, base} + {1'b0, base};
    wire [15:0] base_next = (base_dbl >= {1'b0, m}) ? base_dbl[15:0] - m : base_dbl[15:0];
    wire [16:0] acc_add   = {1'b0, acc}  + {1'b0, base};
    wire [15:0] acc_next  = (acc_add  >= {1'b0, m}) ? acc_add[15:0]  - m : acc_add[15:0];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
                    active <= 0; done <= 0; result <= 0;
                    acc <= 0; base <= 0; bb <= 0; cnt <= 0;
        end else begin
                    done <= 1'b0;
            if (start) begin
                            acc    <= 16'd0;
                            base   <= a % m;
                            bb     <= b;
                            cnt    <= 5'd0;
                            active <= 1'b1;
            end else if (active) begin
                if (cnt == 5'd16) begin
                                    result <= acc; done <= 1'b1; active <= 1'b0;
                end else begin
                    if (bb[0]) acc <= acc_next;
                                    base <= base_next; bb <= bb >> 1; cnt <= cnt + 5'd1;
                end
            end
        end
    end
endmodule

`default_nettype wire
