module SE2 (
  input  wire [31:0] din,    
  input  wire [2:0]  ctrl,   // control select
  output reg  [31:0] dout    // extended output
);

  always @(*) begin
    case (ctrl)
      3'b000: // 0 → pass through (nothing)
        dout = din;

      3'b001: // 1 → 16-bit zero-extend
        dout = {16'b0, din[15:0]};

      3'b010: // 2 → 16-bit sign-extend
        dout = {{16{din[15]}}, din[15:0]};

      3'b011: // 3 → 8-bit zero-extend
        dout = {24'b0, din[7:0]};

      3'b100: // 4 → 8-bit sign-extend
        dout = {{24{din[7]}}, din[7:0]};

      default: // any other code → pass through
        dout = din;
    endcase
  end

endmodule
