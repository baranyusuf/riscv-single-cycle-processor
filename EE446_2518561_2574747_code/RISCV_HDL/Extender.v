module Extender (
    output reg [31:0] Extended_data,
    input [31:0] instr,   // full instruction word input
    input [2:0] select    // ImmSrc signal
);

always @(*) begin
    case (select)
        3'b000: // I-Type
            Extended_data = {{20{instr[31]}}, instr[31:20]};

        3'b001: // S-Type
            Extended_data = {{20{instr[31]}}, instr[31:25], instr[11:7]};

        3'b010: // B-Type
            Extended_data = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

        3'b011: // J-Type
            Extended_data = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

        3'b100: // U-Type
            Extended_data = {instr[31:12], 12'b0};

        default: // Invalid select
            Extended_data = 32'd0;
    endcase
end

endmodule
