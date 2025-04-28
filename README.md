# Computer-Engineering-Architecture-and-Systems
This repository contains two practical projects completed for the **Computer Engineering: Architecture and Systems** course. Both projects involve **UART communication** between a PC and an FPGA board.

## Practical Projects

### Final_prac1: FPGA Byte Shifter

**Goal:**  
Send random bytes from the PC to the FPGA, perform bit shift operations (left or right shifts), and receive the shifted data back to verify correctness.

**Files:**
- **FInal_prac1.sv**: FPGA Verilog module to receive bytes, shift them, and send them back over UART.
- **Version2.py**: Python script to send 50 random bytes to the FPGA, receive shifted bytes, and compare them against expected results.

**How It Works:**
- The Python script generates 50 random bytes.
- Each byte is shifted according to a switch setting (`00`, `01`, `10`, or `11`).
- The FPGA processes the shifts and sends the data back.
- The Python script verifies and displays the success rate.

### Prac2_Final: UART-Based RAM Controller

**Goal:**  
Implement a system where the PC can read and write full bytes, high nibbles, and low nibbles into RAM stored on the FPGA through UART communication.

**Files:**
- **Prac2.sv**: FPGA Verilog module implementing a simple RAM with UART command interface.
- **prac2.py**: Python interface to send read and write commands from the PC to the FPGA.

**How It Works:**
- The user enters commands via the terminal, such as:
  - `WRITE FULL WORD 10 0xAA`
  - `READ LOW NIBBLE 20`
- The Python script formats these commands and sends them over UART.
- The FPGA RAM responds based on the command.
- Read data is printed to the terminal in decimal and binary formats.

## Requirements
- FPGA board with UART interface (e.g., USB-UART bridge)
- Python 3.x
- Python **pyserial** package

**Install the required Python package:**
```bash
pip install pyserial

## Acknowledgements
This project was developed as part of the **Computer Engineering: Architecture and Systems** course practicals at the University or Pretoria.




