import logging
import cocotb
from Helper_lib import read_file_to_list,Instruction, shift_helper, ByteAddressableMemory, reverse_hex_string_endiannes
from Helper_Student import Log_Datapath,Log_Controller
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Edge, Timer
from cocotb.binary import BinaryValue


class TB:
    def __init__(self, Instruction_list, dut, dut_PC, dut_regfile):
        self.dut = dut
        self.dut_PC = dut_PC
        self.dut_regfile = dut_regfile
        self.Instruction_list = Instruction_list
        #Configure the logger
        self.logger = logging.getLogger("Performance Model")
        self.logger.setLevel(logging.DEBUG)
        #Initial values are all 0 as in a FPGA
        self.PC = 0
        self.Z_flag = 0
        self.Register_File =[]
        for i in range(32):
            self.Register_File.append(0)
        #Memory is a special class helper lib to simulate HDL counterpart    
        self.memory = ByteAddressableMemory(1024)

        self.clock_cycle_count = 0        
          
    #Calls user populated log functions    
    def log_dut(self):
        Log_Datapath(self.dut,self.logger)
        Log_Controller(self.dut,self.logger)

    #Compares and logs the PC and register file of Python module and HDL design
    def compare_result(self):
        self.logger.debug("************* Performance Model / DUT Data  **************")
        self.logger.debug("PC:0x%x \t PC:0x%x",self.PC,self.dut_PC.value.integer)
        for i in range(32):
            self.logger.debug("Register%d: 0x%x \t 0x%x",i,self.Register_File[i], self.dut_regfile.Reg_Out[i].value.integer)
        assert self.PC == self.dut_PC.value
        for i in range(32):
           assert self.Register_File[i] == self.dut_regfile.Reg_Out[i].value
        
    #Function to write into the register file (cannot write register 0 since it is hardwired to 0)
    def write_to_register_file(self,register_no, data):
        if(data <0):
            data = data +(1 << 32) 
        if(register_no == 0):
            pass
        else:
            self.Register_File[register_no] = data

    #A model of the verilog code to confirm operation, data is In_data
    def performance_model (self):
        self.logger.debug("**************** Clock cycle: %d **********************",self.clock_cycle_count)
        self.clock_cycle_count = self.clock_cycle_count + 1
        #Read current instructions, extract and log the fields
        self.logger.debug("**************** Instruction No: %d **********************",int((self.PC)/4))
        current_instruction = self.Instruction_list[int((self.PC)/4)]
        current_instruction = current_instruction.replace(" ", "")
        #We need to reverse the order of bytes since little endian makes the string reversed in Python
        current_instruction = reverse_hex_string_endiannes(current_instruction)

        # parse into fields
        instruction_fields = Instruction(current_instruction)
        self.logger.debug("PC:0x%x \t PC:0x%x",self.PC,self.dut_PC.value.integer)
        instruction_fields.log(self.logger)

        # basic decoded fields
        opcode   = instruction_fields.opcode
        rd       = instruction_fields.rd
        funct3   = instruction_fields.funct3
        rs1      = instruction_fields.rs1
        rs2      = instruction_fields.rs2
        funct7   = instruction_fields.funct7
        funct7_5 = instruction_fields.funct7_5
        imm_I    = instruction_fields.imm_I
        imm_S    = instruction_fields.imm_S
        imm_B    = instruction_fields.imm_B
        imm_U    = instruction_fields.imm_U
        imm_J    = instruction_fields.imm_J

        # register-file values
        rs1_value = self.Register_File[rs1]
        rs2_value = self.Register_File[rs2]

        # default next PC
        next_pc = (self.PC + 4) & 0xFFFFFFFF

        signed_rs1_value = rs1_value - (1<<32) if (rs1_value & 0x80000000) else rs1_value
        signed_rs2_value = rs2_value - (1<<32) if (rs2_value & 0x80000000) else rs2_value

        unsigned_imm_I = imm_I + (1<<32) if (imm_I & 0x80000000) else imm_I
        unsigned_imm_S = imm_S + (1<<32) if (imm_S & 0x80000000) else imm_S
        unsigned_imm_B = imm_B + (1<<32) if (imm_B & 0x80000000) else imm_B
        unsigned_imm_J = imm_J + (1<<32) if (imm_J & 0x80000000) else imm_J
        unsigned_imm_U = imm_U + (1<<32) if (imm_U & 0x80000000) else imm_U




        # R-TYPE (0x33)
        if opcode == 0x33:
            if   funct3 == 0x0 and funct7_5 == 0:      result = rs1_value + rs2_value           # ADD
            elif funct3 == 0x0 and funct7_5 == 1:      result = rs1_value - rs2_value           # SUB
            elif funct3 == 0x1:                        result = shift_helper(rs1_value, rs2_value & 31, 0)  # SLL
            elif funct3 == 0x2:                        result = 1 if signed_rs1_value < signed_rs2_value else 0          # SLT
            elif funct3 == 0x3:                        result = 1 if (rs1_value & 0xFFFFFFFF) < (rs2_value & 0xFFFFFFFF) else 0  # SLTU
            elif funct3 == 0x4:                        result = rs1_value ^ rs2_value           # XOR
            elif funct3 == 0x5 and funct7_5 == 0:      result = shift_helper(rs1_value, rs2_value & 31, 1)  # SRL
            elif funct3 == 0x5 and funct7_5 == 1:      result = shift_helper(rs1_value, rs2_value & 31, 2)  # SRA
            elif funct3 == 0x6:                        result = rs1_value | rs2_value           # OR
            elif funct3 == 0x7:                        result = rs1_value & rs2_value           # AND
            else:
                self.logger.error(f"Unknown R-type funct3={funct3:x} f7_5={funct7_5}")
                assert False
            self.write_to_register_file(rd, result)


        # I-TYPE ALU (0x13)
        elif opcode == 0x13:
            if   funct3 == 0x0: result = signed_rs1_value + imm_I         # ADDI
            elif funct3 == 0x2: result = 1 if signed_rs1_value < imm_I else 0      # SLTI
            elif funct3 == 0x3: result = 1 if (rs1_value & 0xFFFFFFFF) < (unsigned_imm_I & 0xFFFFFFFF) else 0  # SLTIU
            elif funct3 == 0x4: result = rs1_value ^ unsigned_imm_I         # XORI
            elif funct3 == 0x6: result = rs1_value | unsigned_imm_I         # ORI
            elif funct3 == 0x7: result = rs1_value & unsigned_imm_I         # ANDI
            elif funct3 == 0x1:                        # SLLI
                result = shift_helper(rs1_value, imm_I & 0x1F, 0)
            elif funct3 == 0x5 and funct7_5 == 0:      # SRLI
                result = shift_helper(rs1_value, imm_I & 0x1F, 1)
            elif funct3 == 0x5 and funct7_5 == 1:      # SRAI
                result = shift_helper(rs1_value, imm_I & 0x1F, 2)
            else:
                self.logger.error(f"Unknown I-type funct3={funct3:x} f7_5={funct7_5}")
                assert False
            self.write_to_register_file(rd, result)


        # LOAD (0x03)
        elif opcode == 0x03:
            addr = signed_rs1_value + imm_I
            if addr == 0x00000404:
                result = 0xFFFFFFFF
            elif funct3 == 0x0:   # LB
                byte = self.memory.memory[addr]
                result  = (byte if byte < 0x80 else byte - 0x100)
            elif funct3 == 0x1:   # LH
                half = (self.memory.memory[addr+1]<<8) | self.memory.memory[addr]
                result  = (half if half < 0x8000 else half - 0x10000)
            elif funct3 == 0x2:   # LW
                result = int.from_bytes(self.memory.read(addr))
            elif funct3 == 0x4:   # LBU
                result = self.memory.memory[addr]
            elif funct3 == 0x5:   # LHU
                result = (self.memory.memory[addr+1]<<8) | self.memory.memory[addr]
            else:
                self.logger.error(f"Unknown LOAD funct3={funct3:x}")
                assert False
            self.write_to_register_file(rd, result)


         # STORE (0x23)
        elif opcode == 0x23:
            addr = signed_rs1_value + imm_S
            if addr == 0x00000400:
                pass
            elif funct3 == 0x0:  # SB
                # write single byte into the underlying bytearray
                self.memory.memory[addr] = rs2_value & 0xFF
            elif funct3 == 0x1:  # SH
                half = rs2_value & 0xFFFF
                self.memory.memory[addr]   = half & 0xFF
                self.memory.memory[addr+1] = (half >> 8) & 0xFF
            elif funct3 == 0x2:  # SW
                # write a full 32-bit word (4 bytes little-endian)
                self.memory.write(addr, rs2_value)
            else:
                self.logger.error(f"Unknown STORE funct3={funct3:x}")
                assert False


        # BRANCH (0x63)
        elif opcode == 0x63:
            take = False
            if   funct3 == 0x0: take = (rs1_value == rs2_value)  # BEQ
            elif funct3 == 0x1: take = (rs1_value != rs2_value)  # BNE
            elif funct3 == 0x4: take = (signed_rs1_value < signed_rs2_value)   # BLT
            elif funct3 == 0x5: take = (signed_rs1_value >= signed_rs2_value)  # BGE
            elif funct3 == 0x6: take = ((rs1_value&0xFFFFFFFF) < (rs2_value&0xFFFFFFFF))   # BLTU
            elif funct3 == 0x7: take = ((rs1_value&0xFFFFFFFF) >= (rs2_value&0xFFFFFFFF))  # BGEU
            else:
                self.logger.error(f"Unknown BRANCH funct3={funct3:x}")
                assert False
            if take:
                next_pc = self.PC + imm_B


        # JAL (0x6f)
        elif opcode == 0x6f:
            next_pc = self.PC + imm_J
            self.write_to_register_file(rd, self.PC + 4)


        # JALR (0x67)
        elif opcode == 0x67:
            next_pc = rs1_value + imm_I
            self.write_to_register_file(rd, self.PC + 4)


        # LUI  (0x37)
        elif opcode == 0x37:
            self.write_to_register_file(rd, imm_U)


        # AUIPC (0x17)
        elif opcode == 0x17:
            self.write_to_register_file(rd, self.PC + imm_U)


        else:
            self.logger.error(f"Unknown opcode {opcode:02x} @ PC=0x{self.PC:08x}")
            assert False

        self.PC = next_pc



    async def run_test(self):
        self.performance_model()
        #Wait 1 us the very first time bc. initially all signals are "X"
        await Timer(1, units="us")
        self.log_dut()
        await RisingEdge(self.dut.clk)
        await FallingEdge(self.dut.clk)
        self.compare_result()
        #while(int(self.Instruction_list[int((self.PC)/4)].replace(" ", ""),16)!=0):
        while True:
            if (self.clock_cycle_count == 120):
                break
            self.performance_model()
            #Log datapath and controller before clock edge, this calls user filled functions
            self.log_dut()
            await RisingEdge(self.dut.clk)
            await FallingEdge(self.dut.clk)
            self.logger.debug("************* AFTER CLOCK EDGE  **************")
            self.compare_result()

                
                   
@cocotb.test()
async def RISCV_Computer_Test(dut):
    #Generate the clock
    await cocotb.start(Clock(dut.clk, 10, 'us').start(start_high=False))
    #Reset onces before continuing with the tests
    dut.reset.value=1
    await RisingEdge(dut.clk)
    dut.reset.value=0
    await FallingEdge(dut.clk)
    instruction_lines = read_file_to_list('Instructions.hex')
    #Give PC signal handle and Register File MODULE handle
    tb = TB(instruction_lines, dut, dut.PC, dut.datapath.rf)
    await tb.run_test()