module RISCV_Computer (
  input  wire        clk,
  input  wire        clk_100MHz,
  input  wire        reset,

  // allows choosing a debug read port from RF
  input  wire [4:0]  Debug_Source_select,

  output wire [31:0] PC,
  output wire [31:0] Debug_out,
  output wire tx,
  output wire rx
);


wire        Zero;
wire        ALU_LessThan;
wire [31:0] Instr;

// instruction fields
wire [6:0]  opcode   = Instr[6:0];
wire [2:0]  funct3   = Instr[14:12];
wire        funct7_5 = Instr[30];

// control signals
wire [2:0]  SE2Control;
wire [1:0]  StoreSel;
wire        PCSrc;
wire        ResultSrc;
wire        MemWrite;
wire [3:0]  ALUControl;
wire        ALUSrc;
wire [2:0]  ImmSrc;
wire        RegWrite;
wire [1:0]  RegWSel;
wire        Jalr;

// CONTROLLER
RISCV_Controller controller (
// controller inputs
.Zero         (Zero),
.rd_en        (rd_en),
.send_req     (send_req),
.ALUResult    (ALUResult),
.opcode       (opcode),
.funct3       (funct3),
.funct7_5     (funct7_5),
.ALU_LessThan (ALU_LessThan),
// controller outputs
.SE2Control   (SE2Control),
.StoreSel     (StoreSel),
.PCSrc        (PCSrc),
.ResultSrc    (ResultSrc),
.MemWrite     (MemWrite),
.ALUControl   (ALUControl),
.ALUSrc       (ALUSrc),
.ImmSrc       (ImmSrc),
.RegWrite     (RegWrite),
.RegWSel      (RegWSel),
.Jalr         (Jalr)
);

wire rd_en ;
wire send_req ;
wire [31:0] ALUResult ;

// DATAPATH
RISCV_Datapath datapath (
// datapath inputs
.clk                   (clk),
.clk_100MHz            (clk_100MHz),
.rd_en                 (rd_en),
.rx                    (rx),
.send_req              (send_req),
.tx                    (tx),
.ALUResult             (ALUResult), 
.reset                 (reset),
.PCSrc                 (PCSrc),
.ResultSrc             (ResultSrc),
.Jalr                  (Jalr),
.RegWSel               (RegWSel),
.RegWrite              (RegWrite),
.MemWrite              (MemWrite),
.StoreSel              (StoreSel),
.SE2Control            (SE2Control),
.ALUSrc                (ALUSrc),
.ALUControl            (ALUControl),
.ImmSrc                (ImmSrc),
.Debug_Source_select   (Debug_Source_select),
// datapath outputs
.Instr                 (Instr),
.Zero                  (Zero),
.PC                    (PC),
.ALU_LessThan          (ALU_LessThan),
.Debug_out             (Debug_out)
);

endmodule