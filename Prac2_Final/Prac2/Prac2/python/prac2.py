import serial

PORT = "COM8"
BAUDRATE = 115200

COMMANDS = {
    "READ FULL WORD": 0x10,
    "WRITE FULL WORD": 0x11,
    "READ LOW NIBBLE": 0x12,
    "WRITE LOW NIBBLE": 0x13,
    "READ HIGH NIBBLE": 0x14,
    "WRITE HIGH NIBBLE": 0x15,
}


def to_byte(val_str):
    if val_str.startswith("0X"):
        return int(val_str, 16) & 0xFF
    return int(val_str) & 0xFF


def send_command(ser, cmd, addr, data=None):
    ser.write(bytes([cmd]))
    ser.write(bytes([addr]))
    if data is not None:
        ser.write(bytes([data]))


def read_byte(ser):
    return ser.read(1)


def format_bin(val, is_nibble=False):
    if is_nibble:
        return f"{val & 0xF:04b}"
    return f"{val:08b}"[:4] + "_" + f"{val:08b}"[4:]


def main():
    ser = serial.Serial(PORT, BAUDRATE, timeout=1)

    while True:
        user_input = input().strip().upper()
        if user_input == "EXIT":
            break

        parts = user_input.split()
        if len(parts) < 3:
            continue

        if parts[1] == "FULL" and len(parts) > 3 and parts[2] == "WORD":
            cmd_str = " ".join(parts[:3])
            addr_index = 3
        elif parts[1] in ["LOW", "HIGH"] and len(parts) > 3 and parts[2] == "NIBBLE":
            cmd_str = " ".join(parts[:3])
            addr_index = 3
        else:
            cmd_str = " ".join(parts[:2])
            addr_index = 2

        if cmd_str not in COMMANDS:
            continue

        addr = to_byte(parts[addr_index])
        data = (
            to_byte(parts[addr_index + 1])
            if "WRITE" in cmd_str and len(parts) > addr_index + 1
            else None
        )

        send_command(ser, COMMANDS[cmd_str], addr, data)

        if "READ" in cmd_str:
            response = read_byte(ser)
            if response:
                val = response[0]
                is_nibble = "NIBBLE" in cmd_str
                print(f" DATA = {val} / {format_bin(val, is_nibble)}")

    ser.close()


if __name__ == "__main__":
    main()
