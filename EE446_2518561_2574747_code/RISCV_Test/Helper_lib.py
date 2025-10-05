def read_file_to_list(filename):
    """
    Reads a text file and returns a list where each element is a line in the file.

    :param filename: The name of the file to read.
    :return: A list of strings, where each string is a line from the file.
    """
    with open(filename, 'r') as file:
        lines = file.readlines()
        # Stripping newline characters from each line
        lines = [line.strip() for line in lines]
    return lines


def reverse_hex_string_endiannes(hex_string):  
    reversed_string = bytes.fromhex(hex_string)
    reversed_string = reversed_string[::-1]
    reversed_string = reversed_string.hex()        
    return  reversed_string

def rotate_right(value, shift, n_bits=32):
    """
    Rotate `value` to the right by `shift` bits.

    :param value: The integer value to rotate.
    :param shift: The number of bits to rotate by.
    :param n_bits: The bit-width of the integer (default 32 for standard integer).
    :return: The value after rotating to the right.
    """
    shift %= n_bits  # Ensure the shift is within the range of 0 to n_bits-1
    return (value >> shift) | (value << (n_bits - shift)) & ((1 << n_bits) - 1)


def shift_helper(value, shift,shift_type, n_bits=32):
    shift %= n_bits  # Ensure the shift is within the range of 0 to n_bits-1
    match shift_type:
        case 0:
            return (value  << shift)% 0x100000000      #LSL
        case 1:
            return (value  >> shift) % 0x100000000     #LSR
        case 2:
            if((value & 0x80000000)!=0):
                    filler = (0xFFFFFFFF >> (n_bits-shift))<<((n_bits-shift))    #ASR
                    return ((value  >> shift)|filler) % 0x100000000
            else:
                return (value  >> shift) % 0x100000000
        case 3:
            return rotate_right(value,shift,n_bits)   #RR


class ByteAddressableMemory:
    def __init__(self, size):
        self.size = size
        self.memory = bytearray(size)  # Initialize memory as a bytearray of the given size

    def read(self, address):
        if address < 0 or address + 4 > self.size:
            raise ValueError("Invalid memory address or length")
        return_val = bytes(self.memory[address : address + 4])
        return_val = return_val[::-1]
        return return_val

    def write(self, address, data):
        if address < 0 or address + 4> self.size:
            raise ValueError("Invalid memory address or data length")
        data_bytes = data.to_bytes(4, byteorder='little')
        self.memory[address : address + 4] = data_bytes   


class Instruction:
    """
    Parses a 32-bit RISC-V instruction encoded as an 8-hex-character string.
    """
    def __init__(self, instruction):
        # Convert the hex instruction to a 32-bit binary_instruction string
        self.binary_instruction = format(int(instruction, 16), '032b')
        # Since python indexing is reversed to extract fields (31-index) for msb and (32-index) for lsb
        # For single bits do (31-index)
        self.opcode   = int(self.binary_instruction[25:32], 2)
        self.rd       = int(self.binary_instruction[20:25], 2)
        self.funct3   = int(self.binary_instruction[17:20], 2)
        self.rs1      = int(self.binary_instruction[12:17], 2)
        self.rs2      = int(self.binary_instruction[7:12], 2)
        self.funct7   = int(self.binary_instruction[0:7], 2)
        self.funct7_5 = int(self.binary_instruction[1], 2)

        # I-type (bits 31 down to 20, total 12 bits)
        imm_I = int(self.binary_instruction[0:12], 2)           # top 12 bits
        if self.binary_instruction[0] == '1':
            imm_I -= (1 << 12)                      # sign-extend from 12 bits
        self.imm_I = imm_I

        # S-type immediate (bits 0-6 + 20-24), sign-extend 12 bits
        imm_S = int(self.binary_instruction[0:7] + self.binary_instruction[20:25], 2)
        if self.binary_instruction[0] == '1':
            imm_S -= (1 << 12)
        self.imm_S = imm_S

        # B-type immediate (bits 0,24,1-7,20-24 <<1), sign-extend 13 bits
        imm_B = (
            (int(self.binary_instruction[0],2) << 12) |
            (int(self.binary_instruction[24],2) << 11) |
            (int(self.binary_instruction[1:7],2) << 5) |
            (int(self.binary_instruction[20:24],2) << 1)
        )
        if self.binary_instruction[0] == '1':
            imm_B -= (1 << 13)
        self.imm_B = imm_B

        # U-type immediate (bits 0-19 <<12)
        self.imm_U = int(self.binary_instruction[0:20], 2) << 12

        # J-type immediate (bits 0,12-19,11,1-11 <<1), sign-extend 21 bits
        imm_J = (
            (int(self.binary_instruction[0],2) << 20) |
            (int(self.binary_instruction[12:20],2) << 12) |
            (int(self.binary_instruction[11],2) << 11) |
            (int(self.binary_instruction[1:11],2) << 1)
        )
        if self.binary_instruction[0] == '1':
            imm_J -= (1 << 21)
        self.imm_J = imm_J

    def log(self, logger):
        logger.debug("****** RISC-V Instruction Fields ******")
        logger.debug("Binary Instruction:   %s", self.binary_instruction)
        if (self.opcode == 0x33):
            logger.debug("Instruction Type: R")
            logger.debug("opcode:   0x%x", self.opcode)
            logger.debug("rd:       %d", self.rd)
            logger.debug("funct3:   0x%x", self.funct3)
            logger.debug("funct7:   0x%x", self.funct7)
            logger.debug("rs1:      %d", self.rs1)
            logger.debug("rs2:      %d", self.rs2)
        elif (self.opcode==0x13 or self.opcode==0x67 or self.opcode==0x03):
            logger.debug("Instruction Type: I")
            logger.debug("opcode:   0x%x", self.opcode)
            logger.debug("rd:       %d", self.rd)
            logger.debug("funct3:   0x%x", self.funct3) 
            logger.debug("funct7:   0x%x", self.funct7) 
            logger.debug("rs1:      %d", self.rs1) 
            logger.debug("imm_I:    %d",   self.imm_I)      
        elif (self.opcode == 0x23):
            logger.debug("Instruction Type: S")
            logger.debug("opcode:   0x%x", self.opcode)
            logger.debug("funct3:   0x%x", self.funct3)
            logger.debug("rs1:      %d", self.rs1)
            logger.debug("rs2:      %d", self.rs2)
            logger.debug("imm_S:    %d",   self.imm_S)
        elif (self.opcode == 0x63):
            logger.debug("Instruction Type: B")
            logger.debug("opcode:   0x%x", self.opcode)
            logger.debug("funct3:   0x%x", self.funct3)
            logger.debug("rs1:      %d", self.rs1)
            logger.debug("rs2:      %d", self.rs2)
            logger.debug("imm_B:    %d",   self.imm_B)
        elif (self.opcode==0x37 or self.opcode==0x17):
            logger.debug("Instruction Type: U")
            logger.debug("opcode:   0x%x", self.opcode)
            logger.debug("rd:       %d", self.rd)
            logger.debug("imm_U:    %d",   self.imm_U)
        elif (self.opcode==0x6f):
            logger.debug("Instruction Type: J")
            logger.debug("opcode:   0x%x", self.opcode)
            logger.debug("rd:       %d", self.rd) 
            logger.debug("imm_J:    %d",   self.imm_J)  
        else:
            logger.debug("Wrong Instruction Type")  

