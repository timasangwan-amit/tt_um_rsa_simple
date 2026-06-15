// rsa_simple.v — RSA encrypt wrapper (textbook RSA, not for real security use)
// Hardcoded public key: e=193, n=4439
// Computes: ciphertext = message^193 mod 4439

`default_nettype none

module rsa_simple (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [15:0] message,
    output wire [31:0] encrypted,
    output wire        done
);

    parameter [15:0] e = 16'd193;
    parameter [31:0] n = 32'd4439;

    modexp enc (
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .base     (message),
        .exponent (e),
        .modulus  (n),
        .result   (encrypted),
        .done     (done)
    );

endmodule

`default_nettype wire
