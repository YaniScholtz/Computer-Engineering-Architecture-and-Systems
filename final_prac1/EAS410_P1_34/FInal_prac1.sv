module FInal_prac1 //Top level module for the project. This integrates the receiver and transmitter parts of the UART.
  #(parameter CLKS_PER_BIT = 87)  // Number of clock cycles per bit. 10Mhz/115200 = 87. 
  (
   input        Clock,
   input        Rx_Receive, // data received form the pc via UART
   input        sw1, 
   input        sw0,
   output       Tx_Transmit // data transmitted to the pc via UART
   );
	
	reg [7:0]   receive_Buffer [0:49];  //Stores the 50 received bytes
  reg [5:0]   receive_Buffer_Index = 0; // Keeps track of the received byte index
   wire        RX_CompleteByte; // This wire indicates that a complete byte has been received for storing
  wire [7:0]  Rx_HoldByte; // Holds the received byte

  reg [5:0]   Transmit_index = 0; // Tracks which index is being transmitted 


 
 
  reg         Tx_ReadyforTransmission = 0; // Indicates data is ready for transmission 
  reg [7:0]   Tx_HoldByte = 0; // Holds the byte to be transmitted
  wire        Tx_Active;
  wire        Tx_Done;

  
  
  typedef enum logic [1:0] {IDLE = 2'b00, RECEIVE = 2'b01, TRANSMIT = 2'b10} state_t; //State machine states
  state_t r_State = IDLE; //starting in the IDLE state

  
  reg [15:0] Delay_COunter = 0; //Adds delay between transmission to make the transmission for reliable and no timing issues
  reg wait_Complete_transmission = 0; // ensures transmission is completed before sending the next byte

 
  UART_Receiver #(.CLKS_PER_BIT(CLKS_PER_BIT)) UART_RX_INST (
    .Clock(Clock),
    .Rx_Receive(Rx_Receive),
    .Rx_byteReceived(RX_CompleteByte),
    .Rx_holdingByte(Rx_HoldByte)
  );

 
  UART_Transmitter #(.CLKS_PER_BIT(CLKS_PER_BIT)) UART_TX_INST (
    .Clock(Clock),
    .Tx_newTransmissionData(Tx_ReadyforTransmission),
    .Tx_TransmissionByte(Tx_HoldByte),
    .Tx_active(Tx_Active),
    .Tx_Transmit(Tx_Transmit),
    .Tx_done(Tx_Done)
  );

  
  always_ff @(posedge Clock) begin
    case (r_State)

      IDLE: begin
        receive_Buffer_Index <= 0; //resetting buffer
        Transmit_index <= 0;
        Tx_ReadyforTransmission <= 0;
        wait_Complete_transmission <= 0;
        Delay_COunter <= 0;

        if (RX_CompleteByte) begin //if byte has been received
          receive_Buffer[0] <= Rx_HoldByte;  // Store the first byte in the buffer
          receive_Buffer_Index <= 1; //increasing the index to the next position in the buffer
          r_State <= RECEIVE; // go to the next state machine 
        end
      end

      RECEIVE: begin
        Tx_ReadyforTransmission <= 0; //This is to ensure that transmitting does not happen during the storing of bytes
        
        if (RX_CompleteByte) begin // if byte is received then 
          if (receive_Buffer_Index < 50) begin  // Prevent buffer overflow
            receive_Buffer[receive_Buffer_Index] <= Rx_HoldByte;
            receive_Buffer_Index <= receive_Buffer_Index + 1;
          end
        end

        if (receive_Buffer_Index >= 50) begin
          Transmit_index <= 0; // Initisalising this as a 0 so that the tranmission happens from the beginning
          Delay_COunter <= 0;
          r_State <= TRANSMIT; // Go to state transmit 
        end
      end


      TRANSMIT: begin
        if (Transmit_index < 50) begin  // Only process if there are bytes left to send
          if (wait_Complete_transmission) begin
            // Wait for transmission to complete
            if (Tx_Done) begin //goes high when the current byte is being transmitted
              wait_Complete_transmission <= 0; //means the transmission if complete 
              Tx_ReadyforTransmission <= 0; // set to 0 so that the UART does not send the same byte
              Transmit_index <= Transmit_index + 1; // keeps track of which byte is being sent 
              
             
              Delay_COunter <= CLKS_PER_BIT * 2; // Adding a delay for proper data processing. Waiting for two full bits before sending the next byte
            end
          end
          else if (Delay_COunter > 0) begin
            Delay_COunter <= Delay_COunter - 1; // Here the delay is happening
          end
          else if (!Tx_Active && !Tx_ReadyforTransmission) begin //if transmission is idle and there is not byte to be transmitted, then transmission is done
    
            case ({sw1, sw0}) //operation for bit shifting
               2'b00: begin // Shift left by 1
        Tx_HoldByte[7] <= receive_Buffer[Transmit_index][6]; 
        Tx_HoldByte[6] <= receive_Buffer[Transmit_index][5];
        Tx_HoldByte[5] <= receive_Buffer[Transmit_index][4];
        Tx_HoldByte[4] <= receive_Buffer[Transmit_index][3];
        Tx_HoldByte[3] <= receive_Buffer[Transmit_index][2];
        Tx_HoldByte[2] <= receive_Buffer[Transmit_index][1];
        Tx_HoldByte[1] <= receive_Buffer[Transmit_index][0];
        Tx_HoldByte[0] <= receive_Buffer[Transmit_index][7]; 
    end

    2'b01: begin // Shift left by 2
        Tx_HoldByte[7] <= receive_Buffer[Transmit_index][5];
        Tx_HoldByte[6] <= receive_Buffer[Transmit_index][4];
        Tx_HoldByte[5] <= receive_Buffer[Transmit_index][3];
        Tx_HoldByte[4] <= receive_Buffer[Transmit_index][2];
        Tx_HoldByte[3] <= receive_Buffer[Transmit_index][1];
        Tx_HoldByte[2] <= receive_Buffer[Transmit_index][0];
        Tx_HoldByte[1] <= receive_Buffer[Transmit_index][7]; 
        Tx_HoldByte[0] <= receive_Buffer[Transmit_index][6]; 
		  end

    2'b10: begin // Shift right by 1
        Tx_HoldByte[7] <= receive_Buffer[Transmit_index][0]; 
        Tx_HoldByte[6] <= receive_Buffer[Transmit_index][7];
        Tx_HoldByte[5] <= receive_Buffer[Transmit_index][6];
        Tx_HoldByte[4] <= receive_Buffer[Transmit_index][5];
        Tx_HoldByte[3] <= receive_Buffer[Transmit_index][4];
        Tx_HoldByte[2] <= receive_Buffer[Transmit_index][3];
        Tx_HoldByte[1] <= receive_Buffer[Transmit_index][2];
        Tx_HoldByte[0] <= receive_Buffer[Transmit_index][1];
    end

    2'b11: begin // Shift right by 2
        Tx_HoldByte[7] <= receive_Buffer[Transmit_index][1];
        Tx_HoldByte[6] <= receive_Buffer[Transmit_index][0];
        Tx_HoldByte[5] <= receive_Buffer[Transmit_index][7];
        Tx_HoldByte[4] <= receive_Buffer[Transmit_index][6];
        Tx_HoldByte[3] <= receive_Buffer[Transmit_index][5];
        Tx_HoldByte[2] <= receive_Buffer[Transmit_index][4];
        Tx_HoldByte[1] <= receive_Buffer[Transmit_index][3];
        Tx_HoldByte[0] <= receive_Buffer[Transmit_index][2];
    end
              default: Tx_HoldByte <= receive_Buffer[Transmit_index];
            endcase
            
            Tx_ReadyforTransmission <= 1; //starts sending the bytes
            wait_Complete_transmission <= 1;
          end
        end
        else begin
          r_State <= IDLE;
        end
      end
    endcase
  end
endmodule


// UART Receiver Module
module UART_Receiver
  #(parameter CLKS_PER_BIT = 87)
  (
   input        Clock,
   input        Rx_Receive,
   output       Rx_byteReceived,
   output [7:0] Rx_holdingByte
   );

	
	//STate machine of UART receiver
  parameter IDLE         = 3'b000; //Waits for start bit
  parameter StartBit = 3'b001; // Confirms start bit and making sure it is stable
  parameter DataBits = 3'b010; // Reads 8 data bits one by one
  parameter StopBit  = 3'b011; // Checks if stop bit is high
  parameter Reset      = 3'b100; // prepares for next character 
   
  reg [2:0]     StateMachine = IDLE; //Current state
  reg [7:0]     ClockCounter = 0; //counts the clock cycles per bit
  reg [2:0]     bitIndex = 0; // tracks the received data bit
  reg [7:0]     Rx_Bytestore = 0; // stores the received byte
  reg           Rx_ValidByteReceived = 0; // flag to show that the byte is fully received
  reg           r_Rx_Data_R = 1'b1; // synchronising input
  reg           r_Rx_Data = 1'b1;
   
  always @(posedge Clock) begin
    r_Rx_Data_R <= Rx_Receive;
    r_Rx_Data   <= r_Rx_Data_R;
  end

  always @(posedge Clock) begin
    case (StateMachine)
      IDLE:
        begin
          Rx_ValidByteReceived <= 1'b0; //clearing the data valid input
          ClockCounter <= 0;
          bitIndex   <= 0;
          if (r_Rx_Data == 1'b0) //when a start bit is detected then go to the next state 
            StateMachine <= StartBit;
        end
         
      StartBit:
        begin
          if (ClockCounter == (CLKS_PER_BIT-1)/2) // this is to sample the start bit at its midpoint to ensure accurate UART reception 
			 begin
            if (r_Rx_Data == 1'b0) begin // checking that after half a bit time that the start bit is still low which shows a valid start bit
              ClockCounter <= 0; //reset the clock 
              StateMachine     <= DataBits;// move to the byte receiving 
            end
            else
              StateMachine <= IDLE; //if the r_Rx_Data is not low at the midpoint then it is not a valid start bit and go back to idle 
          end
          else begin
            ClockCounter <= ClockCounter + 1; // increment clock until start bit is reached 
          end
        end
         
      DataBits:
        begin
          if (ClockCounter < CLKS_PER_BIT-1) begin
            ClockCounter <= ClockCounter + 1; // increase until clk bits are reached so that receiving can happen
          end
          else begin
            ClockCounter          <= 0; //reset it back 
            Rx_Bytestore[bitIndex] <= r_Rx_Data; //store the received bit 
            if (bitIndex < 7) begin
              bitIndex <= bitIndex + 1; //increase the index bit 
            end
            else begin
              bitIndex <= 0; 
              StateMachine   <= StopBit;
            end
          end
        end
     
      StopBit:
        begin
          if (ClockCounter < CLKS_PER_BIT-1) begin
            ClockCounter <= ClockCounter + 1;
          end
          else begin
            Rx_ValidByteReceived <= 1'b1; //set that the data byte has been received in full and can go to the stop bit 
            StateMachine <= Reset;
          end
        end
     
      Reset:
        begin
          StateMachine <= IDLE;
          Rx_ValidByteReceived   <= 1'b0; //sets the flag that says a full data byte has been received to 0 
        end
         
    endcase
  end

  assign Rx_byteReceived   = Rx_ValidByteReceived; //reflects the Rx_ValidByteReceived values 
  assign Rx_holdingByte = Rx_Bytestore;
   
endmodule


// UART Transmitter Module
module UART_Transmitter
  #(parameter CLKS_PER_BIT = 87)
  (
   input        Clock,
   input        Tx_newTransmissionData,
   input [7:0]  Tx_TransmissionByte,
   output       Tx_active,
   output       Tx_Transmit,
   output       Tx_done
   );

	//State machine 
  parameter IDLE        = 3'b000;
  parameter Tx_StartBit    = 3'b001;
  parameter Tx_Data     = 3'b010;
   reg [2:0]     StateMachine = IDLE;// starting state
  reg [7:0]     ClockCounter = 0;
  reg [2:0]     bitIndex = 0; //tracks which bit is being sent
  reg [7:0]     Tx_byteStore = 0; // stores the byte being transmitted 
  reg           Tx_byteTransmitted = 0; // indicates when the entire byte has been transmitted
  parameter Tx_StopBit     = 3'b011;
  parameter Reset     = 3'b100;

 
  reg           Tx_regActive = 0; // indicates an ongoing transmission 
  reg           Tx_serialLine = 1; // controls the tx line 

  always @(posedge Clock) begin
    case (StateMachine)
      IDLE:
        begin
          Tx_serialLine <= 1; //when the uart transmission is high, then the start bit is not being sent yet
          Tx_byteTransmitted   <= 0; // no data has been transmitted yet
          ClockCounter <= 0;
          if (Tx_newTransmissionData) begin // check if new data is available for transmission
            Tx_regActive <= 1; //transmission is in progress
            Tx_byteStore   <= Tx_TransmissionByte; // store the data
            StateMachine   <= Tx_StartBit; // go to next state
          end
        end

      Tx_StartBit:
        begin
          Tx_serialLine <= 0; //this sends the start bit 
          if (ClockCounter < CLKS_PER_BIT-1) begin
            ClockCounter <= ClockCounter + 1;
          end
          else begin
            ClockCounter <= 0;
            StateMachine     <= Tx_Data;
          end
        end

      Tx_Data:
        begin
          Tx_serialLine <= Tx_byteStore[bitIndex]; //assigns current data bit to the tx output
          if (ClockCounter < CLKS_PER_BIT-1) begin
            ClockCounter <= ClockCounter + 1;
          end
          else begin
            ClockCounter <= 0;
            if (bitIndex < 7) begin
              bitIndex <= bitIndex + 1;
            end
            else begin
              bitIndex <= 0;
              StateMachine   <= Tx_StopBit;
            end
          end
        end

      Tx_StopBit:
        begin
          Tx_serialLine <= 1; // sends the stop bit
          if (ClockCounter < CLKS_PER_BIT-1) begin
            ClockCounter <= ClockCounter + 1;
          end
          else begin
            Tx_byteTransmitted   <= 1; // shows byte transmission is complete 
            ClockCounter <= 0;
            StateMachine   <= Reset;
          end
        end

      Reset:
        begin
          Tx_regActive <= 0;
          Tx_byteTransmitted   <= 0;
          StateMachine   <= IDLE;
        end

      default:
        StateMachine <= IDLE;

    endcase
  end

  assign Tx_active = Tx_regActive;
  assign Tx_Transmit = Tx_serialLine;
  assign Tx_done   = Tx_byteTransmitted;
  
endmodule