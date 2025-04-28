import serial
import time
import random


def shift_byte(byte, shift_type):
    if shift_type == "00":
        return ((byte << 1) & 0xFF) | (byte >> 7)  # Left shift by 1
    elif shift_type == "01":
        return ((byte << 2) & 0xFF) | (byte >> 6)  # Left shift by 2
    elif shift_type == "10":
        return (byte >> 1) | ((byte & 0x01) << 7)  # Right shift by 1
    elif shift_type == "11":
        return (byte >> 2) | ((byte & 0x03) << 6)  # Right shift by 2
    else:
        return byte


# change this for different outcomes
switch_setting = "11"

ser = serial.Serial(port="COM8", baudrate=115200, timeout=5)
time.sleep(1)

# Send 50 random bytes
data_to_send = [random.randint(0, 255) for i in range(50)]
ser.write(bytes(data_to_send))

# Wait for FPGA to process the data
time.sleep(0.5)

# Receive 50 bytes
received_data = list(ser.read(50))

errors = 0

print("No. | Sent (Binary)  | Shifted (Binary)")
print("-------------------------------------------------")
for i in range(50):
    expected_byte = shift_byte(data_to_send[i], switch_setting)
    received_byte = received_data[i]

    sent_binary = format(data_to_send[i], "08b")
    expected_binary = format(expected_byte, "08b")

    status = "OK" if expected_byte == received_byte else "Error"
    if status == "Error":
        errors += 1

    print(f"{i+1:2}  | {sent_binary} | {expected_binary} {status}")


success_rate = 50 - errors
print(f"\nSuccess Rate: {success_rate}/50")

# Close Serial Port
ser.close()
