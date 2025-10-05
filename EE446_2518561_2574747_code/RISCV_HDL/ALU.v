module ALU #(parameter WIDTH=8)
    (
	  input [3:0] control,
	  input CI,
	  input [WIDTH-1:0] DATA_A,
	  input [WIDTH-1:0] DATA_B,
      output reg [WIDTH-1:0] OUT,
	  output reg CO,
	  output reg OVF,
	  output N, Z
    );


localparam AND=4'b0000,
		  EXOR=4'b0001,
		  SubtractionAB=4'b0010,
		  SubtractionBA=4'b0011,
		  Addition=4'b0100,
		  Addition_Carry=4'b0101,
		  SubtractionAB_Carry=4'b0110,
		  SubtractionBA_Carry=4'b0111,
          SIGNED_LESS_THAN    = 4'b1000,
          UNSIGNED_LESS_THAN  = 4'b1001,
		  ASR = 4'b1010,
		  LSR = 4'b1011,
		  ORR = 4'b1100,
		  Move=4'b1101,
		  LSL = 4'b1110,
		  Move_Not=4'b1111;
		  

// Assign the zero and negative flasg here since it is very simple
assign N = OUT[WIDTH-1];
assign Z = ~(|OUT);

	 
always@(*) begin
	case(control)
		AND:begin
			OUT = DATA_A & DATA_B;
			CO = 1'b0;
			OVF = 1'b0;
		end
		EXOR:begin
			OUT = DATA_A ^ DATA_B;
			CO = 1'b0;
			OVF = 1'b0;
		end
		SubtractionAB:begin
			{CO,OUT} =  DATA_A +  $unsigned(~DATA_B) +  1'b1;
			OVF = (DATA_A[WIDTH-1] & ~DATA_B[WIDTH-1] & ~OUT[WIDTH-1]) | (~DATA_A[WIDTH-1] & DATA_B[WIDTH-1] & OUT[WIDTH-1]);
		end
		SubtractionBA:begin
			{CO,OUT} =  DATA_B +  $unsigned(~DATA_A) +  1'b1;
			OVF = (DATA_B[WIDTH-1] & ~DATA_A[WIDTH-1] & ~OUT[WIDTH-1]) | (~DATA_B[WIDTH-1] & DATA_A[WIDTH-1] & OUT[WIDTH-1]);
		end
		Addition:begin
			{CO,OUT} = DATA_A + DATA_B;
			OVF = (DATA_A[WIDTH-1] & DATA_B[WIDTH-1] & ~OUT[WIDTH-1]) | (~DATA_A[WIDTH-1] & ~DATA_B[WIDTH-1] & OUT[WIDTH-1]);
		end
		Addition_Carry:begin
			{CO,OUT} = DATA_A + DATA_B + CI;
			OVF = (DATA_A[WIDTH-1] & DATA_B[WIDTH-1] & ~OUT[WIDTH-1]) | (~DATA_A[WIDTH-1] & ~DATA_B[WIDTH-1] & OUT[WIDTH-1]);
		end
		SubtractionAB_Carry:begin
			{CO,OUT} =  DATA_A +  $unsigned(~DATA_B) + CI;
			OVF = (DATA_A[WIDTH-1] & ~DATA_B[WIDTH-1] & ~OUT[WIDTH-1]) | (~DATA_A[WIDTH-1] & DATA_B[WIDTH-1] & OUT[WIDTH-1]);
		end
		SubtractionBA_Carry:begin
			{CO,OUT} =  DATA_B +  $unsigned(~DATA_A) + CI;
			OVF = (DATA_B[WIDTH-1] & ~DATA_A[WIDTH-1] & ~OUT[WIDTH-1]) | (~DATA_B[WIDTH-1] & DATA_A[WIDTH-1] & OUT[WIDTH-1]);
		end

		SIGNED_LESS_THAN: begin
			OUT = {{(WIDTH-1){1'b0}}, ($signed(DATA_A) < $signed(DATA_B))}; // 1 if A < B, else 0
			CO = 1'b0;
			OVF = 1'b0;
		end
		UNSIGNED_LESS_THAN: begin
			OUT = {{(WIDTH-1){1'b0}}, ($unsigned(DATA_A) < $unsigned(DATA_B))}; // 1 if A < B (unsigned), else 0
			CO = 1'b0;
			OVF = 1'b0;
		end

		ASR: begin
			// Arithmetic shift right: signed shift, preserves sign bit
			OUT = $signed($signed(DATA_A) >>> DATA_B[4:0]);
			CO = 1'b0;
			OVF = 1'b0;
		end

		LSR: begin
			// Logical shift right: shifts in 0s
			OUT = $signed($signed(DATA_A) >> DATA_B[4:0]);
			CO = 1'b0;
			OVF = 1'b0;
		end

		LSL: begin
			OUT = $signed($signed(DATA_A) << DATA_B[4:0]);
			CO = 1'b0;
			OVF = 1'b0;
		end

		ORR:begin
			OUT = DATA_A | DATA_B;
			CO = 1'b0;
			OVF = 1'b0;
		end

		Move:begin
			OUT = DATA_B;
			CO = 1'b0;
			OVF = 1'b0;
		end

		Move_Not:begin
			OUT = ~DATA_B;
			CO = 1'b0;
			OVF = 1'b0;
		end

		default:begin
		OUT = {WIDTH{1'b0}};
		CO = 1'b0;
		OVF = 1'b0;
		end
	endcase
end
	 
endmodule	 