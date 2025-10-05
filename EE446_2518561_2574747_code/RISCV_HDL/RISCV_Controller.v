module RISCV_Controller (
  input  wire        Zero,        // ALU zero flag 
  input  wire [6:0]  opcode,      
  input  wire [2:0]  funct3,
  input  wire        funct7_5,    // instr[30]
  input  wire        ALU_LessThan, 
  input  wire [31:0] ALUResult,
  output reg         send_req,
  output reg         rd_en,

  output reg   [2:0] SE2Control,  // load sign/zero-extend
  output reg   [1:0] StoreSel,    // store size
  output reg         PCSrc,       // next-PC
  output reg         ResultSrc,   // 0=ALU out, 1=MemData
  output reg         MemWrite,    // 1=store
  output reg   [3:0] ALUControl,  // to ALU
  output reg         ALUSrc,      // 0=reg file, 1=imm
  output reg   [2:0] ImmSrc,      // immediate type
  output reg         RegWrite,    // write register file
  output reg   [1:0] RegWSel,     // 0=ALU/ld,1=PC+4,2=(JAL/JALR)
  output reg         Jalr         // 1=JALR (used to pick PCtarget=rs1+imm)
);




  //--------------------------------------------------------------------------
  // ALUControl encoding 
  localparam ALU_AND  = 4'b0000,
             ALU_XOR  = 4'b0001,
             ALU_SUB  = 4'b0010,
             ALU_SLL  = 4'b1110, 
             ALU_SLT  = 4'b1000,
             ALU_SLTU = 4'b1001,
             ALU_ADD  = 4'b0100,
             ALU_SRL  = 4'b1011,
             ALU_SRA  = 4'b1010,
             ALU_OR   = 4'b1100;

  //--------------------------------------------------------------------------
  // main combinational decoder
  always @(*) begin
    // -- default all control signals to "safe" values
    SE2Control = 3'd0;
    StoreSel   = 2'd0;
    PCSrc      = 1'b0;
    ResultSrc  = 1'b0;
	  rd_en      = 1'b0;
    send_req   = 1'b0;	
    MemWrite   = 1'b0;
    ALUControl = ALU_ADD;
    ALUSrc     = 1'b0;
    ImmSrc     = 3'd0;
    RegWrite   = 1'b0;
    RegWSel    = 2'd0;
    Jalr       = 1'b0;

    case(opcode)

      //------------------------------------------------------------
      // R-type:  opcode = 7'b0110011
      7'b0110011: begin  
        ALUSrc     = 1'b0;
        ImmSrc     = 3'd0;    
        RegWrite   = 1'b1;
        RegWSel    = 2'd0;    
        MemWrite   = 1'b0;
        PCSrc      = 1'b0;
        ResultSrc  = 1'b0;

        // ALU func determined by funct3 + funct7_5
        case(funct3)
          3'b000: ALUControl = funct7_5 ? ALU_SUB : ALU_ADD;
          3'b111: ALUControl = ALU_AND;
          3'b110: ALUControl = ALU_OR;
          3'b100: ALUControl = ALU_XOR;
          3'b001: ALUControl = ALU_SLL;
          3'b101: ALUControl = funct7_5 ? ALU_SRA : ALU_SRL;
          3'b010: ALUControl = ALU_SLT;
          3'b011: ALUControl = ALU_SLTU;
          default: ALUControl = ALU_ADD;
        endcase
      end

      //------------------------------------------------------------
      // I-type ALU immediates:  opcode = 7'b0010011
      7'b0010011: begin
        ALUSrc     = 1'b1;
        ImmSrc     = 3'd0;    
        RegWrite   = 1'b1;
        RegWSel    = 2'd0;
        MemWrite   = 1'b0;
        PCSrc      = 1'b0;
        ResultSrc  = 1'b0;

        case(funct3)
          3'b000: ALUControl = ALU_ADD;   // ADDI
          3'b111: ALUControl = ALU_AND;   // ANDI
          3'b110: ALUControl = ALU_OR;    // ORI
          3'b100: ALUControl = ALU_XOR;   // XORI
          3'b001: ALUControl = ALU_SLL;   // SLLI
          3'b101: ALUControl = funct7_5 ? ALU_SRA : ALU_SRL; // SRAI / SRLI
          3'b010: ALUControl = ALU_SLT;   // SLTI
          3'b011: ALUControl = ALU_SLTU;  // SLTIU
          default: ALUControl = ALU_ADD;
        endcase
      end

      //------------------------------------------------------------
      // Load: opcode = 7'b0000011
      7'b0000011: begin
        ALUSrc     = 1'b1;        
        ImmSrc     = 3'd0;       // I-type
        RegWrite   = 1'b1;
        MemWrite   = 1'b0;
        PCSrc      = 1'b0;
        ResultSrc  = 1'b1;       // take ReadData

        // select sign/zero‐extend of loaded byte/halfword
        case(funct3)
          3'b010:begin 
            SE2Control = 3'd0; // LW => none
            if(ALUResult == 32'h00000404) begin
              rd_en      = 1'b1;
              RegWSel    = 2'd3;
            end
            end
          3'b001: SE2Control = 3'd2; // LH => 16-bit sign‐ext
          3'b101: SE2Control = 3'd1; // LHU => 16-bit zero‐ext
          3'b000: SE2Control = 3'd4; // LB => 8-bit sign‐ext
          3'b100: SE2Control = 3'd3; // LBU=> 8-bit zero‐ext
          default: SE2Control = 3'd0;
        endcase
      end

      //------------------------------------------------------------
      // Store: opcode = 7'b0100011
      7'b0100011: begin
        ALUSrc     = 1'b1;
        ImmSrc     = 3'd1;       // S-type
        RegWrite   = 1'b0;
        MemWrite   = 1'b1;
        PCSrc      = 1'b0;

        // select store size
        case(funct3)
          3'b010: StoreSel = 2'd0; // SW
          3'b001: StoreSel = 2'd1; // SH
          3'b000:begin
            StoreSel = 2'd2; // SB
            if(ALUResult == 32'h00000400)begin			
              send_req = 1'b1;
              MemWrite = 1'b0;
            end
		      end
          default: StoreSel = 2'd0;
        endcase
      end

      //------------------------------------------------------------
      // Branch: opcode = 7'b1100011
      7'b1100011: begin
        ALUSrc     = 1'b0;
        ImmSrc     = 3'd2;       // B-type
        RegWrite   = 1'b0;
        MemWrite   = 1'b0;

        case(funct3)
          3'b000:begin 
		  PCSrc = Zero;         // BEQ
		  ALUControl = ALU_SUB;
		  end
          3'b001:begin
		  PCSrc = ~Zero;        // BNE
		  ALUControl = ALU_SUB;
		  end
          3'b100:begin 
		  ALUControl = ALU_SLT; // BLT 
          PCSrc      = ALU_LessThan ;
		  end
          3'b101:begin
		  ALUControl = ALU_SLT; // BGE
          PCSrc      = ~ALU_LessThan;
		  end
          3'b110:begin
		  ALUControl = ALU_SLTU; // BLTU
          PCSrc      = ALU_LessThan;
		  end
          3'b111:begin
		  ALUControl = ALU_SLTU; // BGEU
          PCSrc      = ~ALU_LessThan;
		  end
          default:begin
		  PCSrc = 1'b0;
		  ALUControl = ALU_SLT;
		  end
        endcase
      end

      //------------------------------------------------------------
      // JAL: opcode = 7'b1101111
      7'b1101111: begin
        ALUSrc     = 1'b0;
        ImmSrc     = 3'd3;       // J-type
        RegWrite   = 1'b1;
        RegWSel    = 2'd1;       // rd ← PC+4
        MemWrite   = 1'b0;
        PCSrc      = 1'b1;       // jump
        ResultSrc  = 1'b0;
        Jalr       = 1'b0;       // not JALR
      end

      //------------------------------------------------------------
      // JALR: opcode = 7'b1100111
      7'b1100111: begin
        ALUSrc     = 1'b1;       // rs1 + imm
        ImmSrc     = 3'd0;       // I-type
		    ALUControl = ALU_ADD;
        RegWrite   = 1'b1;
        RegWSel    = 2'd1;       // PC+4
        MemWrite   = 1'b0;
        Jalr       = 1'b1;       // select rs1+imm
      end

      //------------------------------------------------------------
      // U-type LUI:  opcode = 7'b0110111
      7'b0110111: begin
        ALUSrc     = 1'b1;
        ImmSrc     = 3'd4;       // U-type
        RegWrite   = 1'b1;
        RegWSel    = 2'd0;       
        PCSrc      = 1'b0;
        MemWrite   = 1'b0;
        ALUControl = 4'b1101;   
      end

      //------------------------------------------------------------
      // U-type AUIPC: opcode = 7'b0010111
      7'b0010111: begin
        ALUSrc     = 1'b1;
        ImmSrc     = 3'd4;       // U-type
        RegWrite   = 1'b1;
        RegWSel    = 2'd2;     
        PCSrc      = 1'b0;
        MemWrite   = 1'b0;
      end

      //------------------------------------------------------------
      default: begin
        // default
      end

    endcase
  end

endmodule