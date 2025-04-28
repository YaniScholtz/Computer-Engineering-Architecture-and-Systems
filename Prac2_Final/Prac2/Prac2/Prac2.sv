// ===================== TOP MODULE =====================
module Prac2 (
    input clk,
    input Rx_Receive,
    output Tx_Transmit
);

    uart_ram_bridge bridge (
        .clk(clk),
        .Rx_Receive(Rx_Receive),
        .Tx_Transmit(Tx_Transmit),
        .Tx_active()
    );

endmodule

// =====================32 CHIPS and a 8x8x1 STRUCTURE =====================
module simple_ram_32chips (
    input clk,
    input we,
    input [1:0] access_mode,      // 00 = full byte, 01 = LSN, 10 = MSN
    input [7:0] addr,        
    input [7:0] din,
    output reg [7:0] dout
);
    // Each chip has 8 rows and 8 columns making 64 cells where 1 bit per cell
    reg mem [0:31][0:7][0:7];  // [chip][row][col] = 1 bit per cell

    
    wire [1:0] chip_group = addr[7:6];        
    wire [2:0] row_index  = addr[5:3];       
    wire [2:0] col_index  = addr[2:0];   
	 wire [4:0] chip_base = chip_group * 8;
	 

    integer i;
    reg [7:0] full_byte;

    
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            full_byte[i] = mem[chip_base + i][row_index][col_index];
        end
    end

  
    always @(posedge clk) begin
        if (we) begin
            case (access_mode)
                2'b00: begin // WRITE FULL BYTE
                    for (i = 0; i < 8; i = i + 1)
                        mem[chip_base + i][row_index][col_index] <= din[i];
                end
                2'b01: begin // WRITE LSN 
                    for (i = 0; i < 4; i = i + 1)
                        mem[chip_base + i][row_index][col_index] <= din[i];
                    for (i = 4; i < 8; i = i + 1)
                        mem[chip_base + i][row_index][col_index] <= full_byte[i];
                end
                2'b10: begin // WRITE MSN 
                    for (i = 0; i < 4; i = i + 1)
                        mem[chip_base + i][row_index][col_index] <= full_byte[i];
                    for (i = 4; i < 8; i = i + 1)
                        mem[chip_base + i][row_index][col_index] <= din[i - 4];
                end
            endcase
        end
        dout <= full_byte;  // Output the full byte
    end

 
    initial begin
        integer c, r, col;
        for (c = 0; c < 32; c = c + 1)
            for (r = 0; r < 8; r = r + 1)
                for (col = 0; col < 8; col = col + 1)
                    mem[c][r][col] = 1'b0;
    end
endmodule


// ===================== UART RAM BRIDGE =====================
module uart_ram_bridge (
    input wire clk,
    input wire Rx_Receive,
    output wire Tx_Transmit,
    output wire Tx_active
);

    wire [7:0] rx_byte;
    wire rx_ready;
    wire tx_done;
    reg [7:0] tx_byte;
    reg tx_start = 0;

    reg [7:0] ram_addr;
    reg [7:0] ram_din;
    wire [7:0] ram_dout;
    reg ram_we = 0;
    reg [1:0] access_mode;

    reg [2:0] state = 0;
    reg [7:0] command, address, data;

    UART_Receiver #(.CLKS_PER_BIT(87)) uart_rx (
        .Clock(clk),
        .Rx_Receive(Rx_Receive),
        .Rx_byteReceived(rx_ready),
        .Rx_holdingByte(rx_byte)
    );

    UART_Transmitter #(.CLKS_PER_BIT(87)) uart_tx (
        .Clock(clk),
        .Tx_newTransmissionData(tx_start),
        .Tx_TransmissionByte(tx_byte),
        .Tx_active(Tx_active),
        .Tx_Transmit(Tx_Transmit),
        .Tx_done(tx_done)
    );

    simple_ram_32chips ram_inst (
        .clk(clk),
        .we(ram_we),
        .access_mode(access_mode),
        .addr(ram_addr),
        .din(ram_din),
        .dout(ram_dout)
    );

    localparam IDLE     = 3'd0;
    localparam GET_CMD  = 3'd1;
    localparam GET_ADDR = 3'd2;
    localparam GET_DATA = 3'd3;
    localparam WRITE_RAM= 3'd4;
    localparam READ_RAM = 3'd5;
    localparam SEND_BYTE= 3'd6;

    always @(posedge clk) begin
        tx_start <= 0;
        ram_we <= 0;

        case (state)
            IDLE:
                if (rx_ready) begin
                    command <= rx_byte;
                    state <= GET_ADDR;
                end

            GET_ADDR:
                if (rx_ready) begin
                    address <= rx_byte;
                    if (command == 8'h11 || command == 8'h13 || command == 8'h15)
                        state <= GET_DATA;
                    else if (command == 8'h10 || command == 8'h12 || command == 8'h14)
                        state <= READ_RAM;
                    else
                        state <= IDLE;
                end

            GET_DATA:
                if (rx_ready) begin
                    data <= rx_byte;
                    state <= WRITE_RAM;
                end

            WRITE_RAM: begin
                ram_addr <= address;
                ram_din <= data;
                case (command)
                    8'h11: access_mode <= 2'b00;
                    8'h13: access_mode <= 2'b01;
                    8'h15: access_mode <= 2'b10;
                    default: access_mode <= 2'b00;
                endcase
                ram_we <= 1;
                state <= IDLE;
            end

            READ_RAM: begin
                ram_addr <= address;
                case (command)
                    8'h10: access_mode <= 2'b00;
                    8'h12: access_mode <= 2'b01;
                    8'h14: access_mode <= 2'b10;
                    default: access_mode <= 2'b00;
                endcase
                state <= SEND_BYTE;
            end

            SEND_BYTE: begin
                case (access_mode)
                    2'b00: tx_byte <= ram_dout;
                    2'b01: tx_byte <= {4'b0000, ram_dout[3:0]};
                    2'b10: tx_byte <= {4'b0000, ram_dout[7:4]};
                endcase
                tx_start <= 1;
                state <= IDLE;
            end
        endcase
    end
endmodule

// ===================== UART RECEIVER =====================
module UART_Receiver #(parameter CLKS_PER_BIT = 87)(
    input Clock,
    input Rx_Receive,
    output Rx_byteReceived,
    output [7:0] Rx_holdingByte
);
    parameter IDLE = 3'b000;
    parameter StartBit = 3'b001;
    parameter DataBits = 3'b010;
    parameter StopBit = 3'b011;
    parameter Reset = 3'b100;

    reg [2:0] StateMachine = IDLE;
    reg [7:0] ClockCounter = 0;
    reg [2:0] bitIndex = 0;
    reg [7:0] Rx_Bytestore = 0;
    reg Rx_ValidByteReceived = 0;
    reg r_Rx_Data_R = 1'b1;
    reg r_Rx_Data = 1'b1;

    always @(posedge Clock) begin
        r_Rx_Data_R <= Rx_Receive;
        r_Rx_Data <= r_Rx_Data_R;
    end

    always @(posedge Clock) begin
        case (StateMachine)
            IDLE: begin //Waiting for the start bit 
                Rx_ValidByteReceived <= 0;
                ClockCounter <= 0;
                bitIndex <= 0;
                if (r_Rx_Data == 0)
                    StateMachine <= StartBit;
            end

            StartBit: begin
                if (ClockCounter == (CLKS_PER_BIT - 1) / 2) begin
                    if (r_Rx_Data == 0) begin
                        ClockCounter <= 0;
                        StateMachine <= DataBits;
                    end else begin
                        StateMachine <= IDLE;
                    end
                end else begin
                    ClockCounter <= ClockCounter + 1;
                end
            end

            DataBits: begin
                if (ClockCounter < CLKS_PER_BIT - 1) begin
                    ClockCounter <= ClockCounter + 1;
                end else begin
                    ClockCounter <= 0;
                    Rx_Bytestore[bitIndex] <= r_Rx_Data;
                    if (bitIndex < 7)
                        bitIndex <= bitIndex + 1;
                    else begin
                        bitIndex <= 0;
                        StateMachine <= StopBit;
                    end
                end
            end

            StopBit: begin
                if (ClockCounter < CLKS_PER_BIT - 1) begin
                    ClockCounter <= ClockCounter + 1;
                end else begin
                    Rx_ValidByteReceived <= 1;
                    StateMachine <= Reset;
                end
            end

            Reset: begin
                StateMachine <= IDLE;
                Rx_ValidByteReceived <= 0;
            end
        endcase
    end

    assign Rx_byteReceived = Rx_ValidByteReceived;
    assign Rx_holdingByte = Rx_Bytestore;
endmodule

// ===================== UART TRANSMITTER =====================
module UART_Transmitter #(parameter CLKS_PER_BIT = 87)(
    input Clock,
    input Tx_newTransmissionData,
    input [7:0] Tx_TransmissionByte,
    output Tx_active,
    output Tx_Transmit,
    output Tx_done
);
    parameter IDLE = 3'b000;
    parameter Tx_StartBit = 3'b001;
    parameter Tx_Data = 3'b010;
    parameter Tx_StopBit = 3'b011;
    parameter Reset = 3'b100;

    reg [2:0] StateMachine = IDLE;
    reg [7:0] ClockCounter = 0;
    reg [2:0] bitIndex = 0;
    reg [7:0] Tx_byteStore = 0;
    reg Tx_byteTransmitted = 0;
    reg Tx_regActive = 0;
    reg Tx_serialLine = 1;

    always @(posedge Clock) begin
        case (StateMachine)
            IDLE: begin
                Tx_serialLine <= 1;
                Tx_byteTransmitted <= 0;
                ClockCounter <= 0;
                if (Tx_newTransmissionData) begin
                    Tx_regActive <= 1;
                    Tx_byteStore <= Tx_TransmissionByte;
                    StateMachine <= Tx_StartBit;
                end
            end

            Tx_StartBit: begin
                Tx_serialLine <= 0;
                if (ClockCounter < CLKS_PER_BIT - 1)
                    ClockCounter <= ClockCounter + 1;
                else begin
                    ClockCounter <= 0;
                    StateMachine <= Tx_Data;
                end
            end

            Tx_Data: begin
                Tx_serialLine <= Tx_byteStore[bitIndex];
                if (ClockCounter < CLKS_PER_BIT - 1)
                    ClockCounter <= ClockCounter + 1;
                else begin
                    ClockCounter <= 0;
                    if (bitIndex < 7)
                        bitIndex <= bitIndex + 1;
                    else begin
                        bitIndex <= 0;
                        StateMachine <= Tx_StopBit;
                    end
                end
            end

            Tx_StopBit: begin
                Tx_serialLine <= 1;
                if (ClockCounter < CLKS_PER_BIT - 1)
                    ClockCounter <= ClockCounter + 1;
                else begin
                    Tx_byteTransmitted <= 1;
                    ClockCounter <= 0;
                    StateMachine <= Reset;
                end
            end

            Reset: begin
                Tx_regActive <= 0;
                Tx_byteTransmitted <= 0;
                StateMachine <= IDLE;
            end

            default: StateMachine <= IDLE;
        endcase
    end

    assign Tx_active = Tx_regActive;
    assign Tx_Transmit = Tx_serialLine;
    assign Tx_done = Tx_byteTransmitted;
endmodule



