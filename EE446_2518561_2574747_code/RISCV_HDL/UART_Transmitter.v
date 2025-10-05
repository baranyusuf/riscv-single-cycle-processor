module UART_Transmitter (
    input  wire       clk,
    input  wire       send_req,
    input  wire [7:0] tx_byte,
    input wire [1:0]  data_clk,
    output reg        tx,
    output reg        busy
);

// Number of clock cycles per bit period:
localparam integer BAUD_CLK_CYCLES  = 10416;

// Transmitter state machine states
parameter IDLE      = 2'b00;
parameter START = 2'b01;
parameter DATA = 2'b10;
parameter STOP  = 2'b11;

reg [1:0] state; // current state

reg [14:0] baud_counter; // counts clock ticks for one baud period
reg [2:0]  data_index;   // which data bit (0..7) is being sent
reg [7:0]  tx_buffer;    // holds tx_byte while shifting out


wire send_req_new = (data_clk == 2'b10) & send_req;


// Synchronous state machine
always @(posedge clk) begin

    case (state)
        IDLE: begin
            tx   <= 1'b1;         // keep line high
            busy <= 1'b0;         // not transmitting
            if (send_req_new) begin
                // start a new frame
                busy      <= 1'b1;
                tx_buffer <= tx_byte; 
                baud_counter  <= 0;
                state     <= START;
            end
        end

        START: begin
            tx <= 1'b0;  // start bit is logic 0
            // wait for one full baud period
            if (baud_counter == BAUD_CLK_CYCLES-1) begin
                baud_counter <= 0;
                data_index  <= 0;
                state    <= DATA;
            end 
            else begin
                baud_counter <= baud_counter + 1;
            end
        end

        DATA: begin
            // output LSB of tx_buffer
            tx <= tx_buffer[0];
            if (baud_counter == BAUD_CLK_CYCLES-1) begin
                baud_counter  <= 0;
                tx_buffer <= tx_buffer >> 1; // shift next bit into position
                if (data_index == 7)
                    state <= STOP;      // all 8 bits done
                else
                    data_index <= data_index + 1; // move to next bit
            end 
            else begin
                baud_counter <= baud_counter + 1;
            end
        end

        STOP: begin
            tx <= 1'b1;  // stop bit is logic 1
            if (baud_counter == BAUD_CLK_CYCLES-1) begin
                // one stop-bit period elapsed
                state    <= IDLE;
                busy     <= 1'b0;
                baud_counter <= 0;
            end 
            else begin
                baud_counter <= baud_counter + 1;
            end
        end

        default: state <= IDLE;
    endcase
end

endmodule
