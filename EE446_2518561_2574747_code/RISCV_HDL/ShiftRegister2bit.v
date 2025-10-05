module ShiftRegister2bit (
    input clk,
    input reset,
    input data_in,            // 1-bit input
    output reg [1:0] out      // 2-bit output
);

initial begin
    out <= 2'b00;
end

always @(posedge clk) begin
    if (reset)
        out <= 2'b00;
    else
        out <= {out[0], data_in};  // Shift left: MSB ← out[0], LSB ← new bit
end

endmodule
