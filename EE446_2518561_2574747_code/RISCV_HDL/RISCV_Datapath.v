module RISCV_Datapath (
    input  wire        clk,
    input  wire        clk_100MHz,
    input  wire        reset,
    input  wire        rd_en,
    input  wire        rx,
    input  wire        send_req,
    output wire        tx,

    // control signals from the controller
    input  wire         PCSrc,        // choose between PC+4 or branch target
    input  wire         ResultSrc,    // choose between ALU result or loaded data
    input  wire         Jalr,         // when high, select JALR target for PC
    input  wire [1:0]   RegWSel,      // write-back source select
    input  wire         RegWrite,     // enable register-file write
    input  wire         MemWrite,     // enable data-memory write
    input  wire [1:0]   StoreSel,     // store size select: 00=word,01=half,10=byte
    input  wire [2:0]   SE2Control,   // load extension control (sign/zero-extend)
    input  wire         ALUSrc,       // ALU B-input source: 0=register,1=immediate
    input  wire [3:0]   ALUControl,   // ALU control
    input  wire [2:0]   ImmSrc,       // immediate type select: I,S,B,J,U
    input  wire [4:0]   Debug_Source_select, // debug port select for register file

    // outputs 
    output wire [31:0]  Instr,        // fetched instruction
    output wire         Zero,         // ALU zero flag
    output wire [31:0]  PC,           // current PC
    output wire         ALU_LessThan, // ALU 'less than' result (LSB of ALUResult)
    output wire [31:0]  Debug_out,     // debug output from register file
    output wire [31:0]  ALUResult
);


//--------------------------------------------------------------------------
// wires
//--------------------------------------------------------------------------

wire [31:0] PC_plus4;     // PC + 4
wire [31:0] PC_target;    // branch/jump target address
wire [31:0] PCSrc_Result; // output of PCSrc MUX
wire [31:0] PC_next;      // next PC value

wire [31:0] Result;

wire [31:0] ImmExt;         // sign- or zero-extended immediate
wire [31:0] RegRD1, RegRD2; // register file read data
wire [31:0] ALU_SrcB;       // ALU second operand (RegRD2 or ImmExt)

wire [31:0] WriteBackData; // final WD for regfile

wire CO, OVF, N;   // ALU Flags

wire [31:0] ReadData;      // data-memory read output
wire [31:0] WriteData;     // data to write into memory (after byte/half packing)
wire [31:0] LoadData;      // loaded data after extension

assign ALU_LessThan = ALUResult[0];  // ALU Less than result


//--------------------------------------------------------------------------
// Choosing Next PC Value
//--------------------------------------------------------------------------

// Program counter
Register_rsten #(32) PC_reg (
.clk(clk),
.reset(reset),
.we(1'b1),    
.DATA(PC_next),
.OUT (PC)
);

// compute PC + 4
Adder #(32) pc_adder (
.DATA_A(PC),
.DATA_B(32'd4),
.OUT   (PC_plus4)
);

// compute branch/jump target = PC + immediate
Adder #(32) branch_adder (
.DATA_A(PC),
.DATA_B(ImmExt),
.OUT   (PC_target)
);

// choose between PC+4 and branch/jump target
Mux_2to1 #(32) PCSrc_Mux (
.select      (PCSrc),
.input_0     (PC_plus4),
.input_1     (PC_target),
.output_value (PCSrc_Result)
);

// Selecting the next PC value considering JALR instruction
Mux_2to1 #(32) Jalr_Mux (
.select      (Jalr),
.input_0     (PCSrc_Result),
.input_1     ({Result[31:1], 1'b0}),
.output_value(PC_next)
);


//--------------------------------------------------------------------------
// Instruction fetch
//--------------------------------------------------------------------------
Instruction_memory #(.BYTE_SIZE(4), .ADDR_WIDTH(32)) imem (
.ADDR(PC),
.RD  (Instr)
);


//--------------------------------------------------------------------------
// Register file
//--------------------------------------------------------------------------

Register_file #(.WIDTH(32)) rf (
.clk               (clk),
.write_enable      (RegWrite),
.reset             (reset),
.Source_select_0   (Instr[19:15]),    // rs1
.Source_select_1   (Instr[24:20]),    // rs2
.Debug_Source_select(Debug_Source_select),     // optional debug port
.Destination_select(Instr[11:7]),     // rd
.DATA              (WriteBackData),    // WB data
.out_0             (RegRD1),           // rs1 data
.out_1             (RegRD2),           // rs2 data
.Debug_out         (Debug_out)          // debug output
);


//--------------------------------------------------------------------------
// Immediate extender
//--------------------------------------------------------------------------
Extender imm_ext (
.instr         (Instr),
.select        (ImmSrc),
.Extended_data (ImmExt)
);


//--------------------------------------------------------------------------
// ALU
//--------------------------------------------------------------------------

// select ALU B input: register or immediate
Mux_2to1 #(32) alu_src_mux (
.select   (ALUSrc),
.input_0  (RegRD2),
.input_1  (ImmExt),
.output_value(ALU_SrcB)
);

// perform ALU operation
ALU #(32) alu_unit (
.control(ALUControl),
.CI     (1'b0),
.DATA_A (RegRD1),
.DATA_B (ALU_SrcB),
.OUT    (ALUResult),
.CO     (CO),      // unused
.OVF    (OVF),      // unused
.N      (N),      // unused
.Z      (Zero)
);


//--------------------------------------------------------------------------
// Data memory (with byte/half‐word writes via concat_block)
//--------------------------------------------------------------------------

// read or write memory at ALUResult address
Memory #(.BYTE_SIZE(4), .ADDR_WIDTH(32)) dmem_read (
.clk  (clk),
.WE   (MemWrite),
.ADDR (ALUResult),
.WD   (WriteData),
.RD   (ReadData)
);

// if writing, pack byte/half/word via concat_block
concat_block store_pack (
.ctrl      (StoreSel),
.readData  (ReadData),
.writeData (RegRD2),
.outData   (WriteData)
);

// sign‐/zero‐extend the loaded data
SE2 load_ext (
.din  (ReadData),
.ctrl (SE2Control),
.dout (LoadData)
);


//--------------------------------------------------------------------------
// Write‐back
//--------------------------------------------------------------------------

// select ALUResult, LoadData, or PC+4
Mux_4to1 #(32) wb_mux (
.select    (RegWSel),
.input_0   (Result),  // R-type
.input_1   (PC_plus4),   // load
.input_2   (PC_target),   // jal
.input_3   (rd_data),      
.output_value(WriteBackData)
);

// choose between ALUResult and LoadData for final Result
Mux_2to1 #(32) Result_mux (
.select      (ResultSrc),
.input_0     (ALUResult),
.input_1     (LoadData),
.output_value (Result)
);

wire [7:0] rx_byte_sig;
wire [31:0] rd_data;
wire rx_valid_sig;
wire fifo_full;
wire fifo_empty;
wire busy;

wire [1:0] data_clk;
wire rd_en_FIFO;
wire send_req_TX;
wire [7:0] tx_byte_TX;


ShiftRegister2bit cpu_clk_register (
  .clk(clk_100MHz),
  .reset(reset),
  .data_in(clk),
  .out(data_clk)
);


Register_reset #(.WIDTH(1)) rd_en_register (
  .clk(clk),
  .reset(reset),
  .DATA(rd_en),
  .OUT(rd_en_FIFO)
);


Register_reset #(.WIDTH(9)) transmitter_register (
  .clk(clk),
  .reset(reset),
  .DATA({RegRD2[7:0], send_req}),
  .OUT({tx_byte_TX, send_req_TX})
);


// UART Receiver instantiation
UART_Receiver receiver_inst (
  .clk      (clk_100MHz),
  .rx       (rx),
  .rx_byte  (rx_byte_sig),
  .rx_valid (rx_valid_sig)
);


// FIFO instantiation
UART_FIFO fifo_inst (
  .clk        (clk_100MHz),
  .data_clk   (data_clk),
  .reset      (reset),
  .rx_valid   (rx_valid_sig),
  .rx_byte    (rx_byte_sig),
  .fifo_full  (fifo_full),
  .rd_en      (rd_en_FIFO),
  .rd_data    (rd_data),
  .fifo_empty (fifo_empty)
);


// UART Transmitter instantiation
UART_Transmitter transmitter_inst (
  .clk      (clk_100MHz),
  .send_req (send_req_TX),
  .tx_byte  (tx_byte_TX),
  .data_clk (data_clk),
  .tx       (tx),
  .busy     (busy)
);


endmodule