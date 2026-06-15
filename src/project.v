`default_nettype none

// tt_um_rsa_simple — TinyTapeout top module
//
// Pinout:
// ui_in[0] : start (pulse high for 1 cycle to begin encryption)
// ui_in[7:1] : message[6:0] (low 7 bits of 15-bit message)
// uio_in[7:0] : message[14:7] (next 8 bits of 15-bit message)
//
// uo_out[7:0] : encrypted[7:0] (low byte of ciphertext, valid when done=1)
// uio_out[6:0] : encrypted[14:8] (bits [14:8] of ciphertext)
// uio_out[7] : done (pulses high for 1 cycle when result is ready)

module tt_um_rsa_simple (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
        input  wire       ena,
        input  wire       clk,
        input  wire       rst_n
);

    wire rst = ~rst_n;

    wire        start   = ui_in[0];
    wire [15:0] message = {1'b0, uio_in[7:0], ui_in[7:1]};

    wire [15:0] encrypted;
    wire        done;

    rsa_simple core (
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .message  (message),
        .encrypted(encrypted),
        .done     (done)
    );

    assign uo_out  = encrypted[7:0];
    assign uio_out = {done, encrypted[14:8]};
    assign uio_oe  = 8'hFF;

    wire _unused = &{ena, encrypted[15], 1'b0};

endmodule

`default_nettype wire
