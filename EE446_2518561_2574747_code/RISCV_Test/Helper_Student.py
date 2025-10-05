# Helper_Student.py

from cocotb.binary import BinaryValue

def ToHex(value):
    try:
        ret = hex(value.integer)
    except: #If there are 'x's in the value
        ret = "0b" + str(value)
    return ret


def Log_Datapath(dut, logger):
    """
    Called before each clock edge to log datapath signals.
    Uncomment the lines you need.
    """
    logger.debug("********** DUT DATAPATH SIGNALS **********")
    # logger.debug("PC           = %s", ToHex(dut.PC.value))
    # logger.debug("Instr        = %s", ToHex(dut.Instr.value))
    # logger.debug("RegRD1       = %s", ToHex(dut.RegRD1.value))
    # logger.debug("RegRD2       = %s", ToHex(dut.RegRD2.value))
    # logger.debug("ALUSrc       = %d",   dut.ALUSrc.value.integer)
    # logger.debug("ImmSrc       = %d",   dut.ImmSrc.value.integer)
    # logger.debug("ALUControl   = %s", ToHex(dut.ALUControl.value))
    # logger.debug("ALUResult    = %s", ToHex(dut.ALUResult.value))
    # logger.debug("Zero         = %d",   dut.Zero.value.integer)
    # logger.debug("MemWrite     = %d",   dut.MemWrite.value.integer)
    # logger.debug("StoreSel     = %d",   dut.StoreSel.value.integer)
    logger.debug("ReadData     = %s", ToHex(dut.datapath.ReadData.value))
    logger.debug("LoadData     = %s", ToHex(dut.datapath.LoadData.value))
    logger.debug("RegRD1       = %s", ToHex(dut.datapath.RegRD1.value))
    logger.debug("WriteData    = %s", ToHex(dut.datapath.WriteData.value))
    logger.debug("ALUResult    = %s", ToHex(dut.datapath.ALUResult.value))
    logger.debug("rs1          = %s", ToHex(dut.datapath.Instr.value))
    logger.debug("rd_data      = %s", ToHex(dut.datapath.rd_data.value))
    logger.debug("fifo_empty   = %s", ToHex(dut.datapath.fifo_empty.value))
    # logger.debug("RegWrite     = %d",   dut.RegWrite.value.integer)
    # logger.debug("ResultSrc    = %d",   dut.ResultSrc.value.integer)
    # logger.debug("RegWSel      = %d",   dut.RegWSel.value.integer)
    # logger.debug("Jalr         = %d",   dut.Jalr.value.integer)

def Log_Controller(dut, logger):
    """
    Called before each clock edge to log controller signals.
    Uncomment the lines you need.
    """
    logger.debug("********** DUT CONTROLLER SIGNALS **********")
    logger.debug("MemWrite    = %s", ToHex(dut.controller.MemWrite.value))
    logger.debug("RegWrite    = %s", ToHex(dut.controller.RegWrite.value))
    # logger.debug("opcode       = %s", ToHex(dut.opcode.value))
    # logger.debug("funct3       = %s", ToHex(dut.funct3.value))
    # logger.debug("funct7_5     = %d",   dut.funct7_5.value.integer)
    # logger.debug("ALUSrc       = %d",   dut.ALUSrc.value.integer)
    # logger.debug("ImmSrc       = %d",   dut.ImmSrc.value.integer)
    # logger.debug("PCSrc        = %d",   dut.PCSrc.value.integer)
    # logger.debug("ResultSrc    = %d",   dut.ResultSrc.value.integer)
    # logger.debug("MemWrite     = %d",   dut.MemWrite.value.integer)
    # logger.debug("SE2Control   = %d",   dut.SE2Control.value.integer)
    # logger.debug("StoreSel     = %d",   dut.StoreSel.value.integer)
    # logger.debug("RegWrite     = %d",   dut.RegWrite.value.integer)
    # logger.debug("RegWSel      = %d",   dut.RegWSel.value.integer)
    # logger.debug("Jalr         = %d",   dut.Jalr.value.integer)
