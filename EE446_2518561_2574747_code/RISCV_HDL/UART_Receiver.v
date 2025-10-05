module UART_Receiver (
    input  wire       clk,
    input  wire       rx,
    output reg  [7:0] rx_byte,
    output reg        rx_valid
);

localparam integer BAUD_CLK_CYCLES  = 10416;


// Receiver state machine
parameter IDLE      = 2'b00;
parameter START = 2'b01;
parameter DATA = 2'b10;
parameter STOP  = 2'b11;

reg [1:0] state; // current state


reg [14:0] baud_counter;   // bit-period counter
reg [2:0]  data_index;     // which data bit (0..7)
reg [7:0]  rx_buffer;      // assemble bits here


always @(posedge clk) begin
    case (state)
        IDLE: begin
            rx_valid <= 1'b0;  // default: no new data
            if (rx == 1'b0) begin
                // schedule to sample in middle of start bit
                baud_counter <= BAUD_CLK_CYCLES/2;
                state    <= START;
            end
        end
 
        START: begin
            if (baud_counter == BAUD_CLK_CYCLES-1) begin
                // one full bit-time after midpoint → start bit done
                baud_counter <= 0;
                data_index  <= 0;
                state    <= DATA;
            end 
            else begin
                baud_counter <= baud_counter + 1;
            end
        end
 
        DATA: begin
            if (baud_counter == BAUD_CLK_CYCLES-1) begin
                // sample next data bit
                baud_counter          <= 0;
                rx_buffer[data_index] <= rx;
                if (data_index == 7)
                    state <= STOP;     // all 8 bits collected
                else
                    data_index <= data_index + 1;
            end 
            else begin
                baud_counter <= baud_counter + 1;
            end
        end
 
        STOP: begin
            if (baud_counter == BAUD_CLK_CYCLES-1) begin
                // on stop bit completion, latch the byte
                rx_byte  <= rx_buffer;
                rx_valid <= 1'b1;    // pulse valid
                state    <= IDLE;    // back to waiting
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
