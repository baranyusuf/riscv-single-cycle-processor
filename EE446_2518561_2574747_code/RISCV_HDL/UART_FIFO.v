module UART_FIFO (
  input  wire           clk,
  input  wire  [1:0]    data_clk,
  input  wire           reset,                 // posedge synchronous
  // --- from UART receiver ------------------------
  input  wire           rx_valid,              // pulses when new byte ready
  input  wire [7:0]     rx_byte,               // received byte
  output wire           fifo_full,             // high when count == DEPTH
  // --- to RISC-V CPU via LW ----------------------
  input  wire           rd_en,           // load strobe (one cycle)
  output reg [31:0]     rd_data,             // combinational read result
  output wire           fifo_empty             // high when count == 0
);

// internal storage and pointers/count
reg [7:0]  fifo_memory   [0:15];
reg [3:0]  write_index, read_index;
reg [4:0]  count;

initial begin
  count <= 0;
end



// status flags
assign fifo_full  = (count == 16);
assign fifo_empty = (count == 0);



integer i;

always @(posedge clk) begin

  if (reset) begin
    // clear pointers & count
    write_index <= 0;
    read_index <= 0;
    count  <= 0;
    // zero out the entire buffer
    for (i = 0; i < 16; i = i + 1)
      fifo_memory[i] <= 0;
  end 
  
  else begin
    // --- auto-enqueue from UART receiver ---
    if (rx_valid && !fifo_full) begin
      fifo_memory[write_index] <= rx_byte;
      write_index      <= write_index + 1;
    end
	
	
	if ((data_clk == 2'b10) && (rd_en == 1'b1) && (!fifo_empty) ) begin
	
		read_index = read_index +1;
	
	end
		
    // --- update count ------------------------
    case ({rx_valid && !fifo_full, (data_clk == 2'b10) && (rd_en == 1'b1) && (!fifo_empty)}) 
      2'b01: count <= count - 1;   // read only
	  2'b10: count <= count + 1;   // write only
      default: count <= count;     // both or neither
    endcase
  end

end

// combinational read output: first byte or 0xFFFFFFFF when empty
always @(*) begin
  case(fifo_empty)
    1'b0: rd_data = {24'd0, fifo_memory[read_index]};
    1'b1: rd_data = 32'hFFFFFFFF;
    default: rd_data = 32'hFFFFFFFF;
  endcase
end


endmodule

