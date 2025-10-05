module concat_block (
  input  wire [1:0]  ctrl,       // 2-bit control
  input  wire [31:0] readData,   // ReadData[31:0]
  input  wire [31:0] writeData,  // WriteData[31:0]
  output reg  [31:0] outData     // concatenated result
);

always @(*) begin
  case (ctrl)
    2'b01: // case 1: upper 16 bits from readData, lower 16 bits from writeData
      outData = { readData[31:16], writeData[15:0] };

    2'b10: // case 2: upper 24 bits from readData, lower  8 bits from writeData
      outData = { readData[31:8],  writeData[7:0]  };

    default: // case 0 (and 3): "nothing" → drive zero 
      outData = writeData;
  endcase
end

endmodule

