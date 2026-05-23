#!/usr/bin/env python3
import sys
import time
import argparse

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("Error: pySerial is required. Run: pip install pyserial")
    sys.exit(1)

# Protocol v3 Constants
RK_START_BYTE = 0x55
RK_CMD_GET_CONF = 0x01
RK_CMD_CONF_DATA = 0x02

def rk_crc16(data: bytes) -> int:
    crc = 0xFFFF
    for byte in data:
        crc ^= (byte << 8)
        for _ in range(8):
            if crc & 0x8000:
                crc = (crc << 1) ^ 0x1021
            else:
                crc = crc << 1
            crc &= 0xFFFF
    return crc

def build_get_conf_packet() -> bytes:
    # START(0x55) + LENGTH_LO(0x06) + LENGTH_HI(0x00) + CMD(0x01) + CRC_LO + CRC_HI
    payload = bytes([RK_CMD_GET_CONF])
    crc = rk_crc16(payload)
    return bytes([RK_START_BYTE, 0x06, 0x00, RK_CMD_GET_CONF, crc & 0xFF, (crc >> 8) & 0xFF])

def list_ports():
    print("\n--- Available Serial Ports ---")
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return
    for p in ports:
        print(f"Port: {p.device}")
        print(f"  Description: {p.description}")
        print(f"  HWID: {p.hwid}")
        print("-" * 30)

def parse_conf_data(pkt: bytes):
    if len(pkt) < 12:
        print("Error: CONF_DATA packet too short.")
        return

    proto_ver = pkt[4]
    orientation = pkt[5]
    widget_count = pkt[6]
    
    idx = 7
    # Read name
    name_len = pkt[idx]
    idx += 1
    name = pkt[idx:idx+name_len].decode('utf-8', errors='ignore')
    idx += name_len
    
    # Read description
    desc_len = pkt[idx]
    idx += 1
    desc = pkt[idx:idx+desc_len].decode('utf-8', errors='ignore')
    idx += desc_len
    
    # Read theme
    theme_len = pkt[idx]
    idx += 1
    theme = pkt[idx:idx+theme_len].decode('utf-8', errors='ignore')
    idx += theme_len
    
    print("\n--- Decoded RadioKit Config ---")
    print(f"Protocol Version: {proto_ver}")
    print(f"Orientation:      {'Portrait' if orientation == 1 else 'Landscape'}")
    print(f"Widget Count:     {widget_count}")
    print(f"Device Name:      '{name}'")
    print(f"Description:      '{desc}'")
    print(f"Theme/Skin:       '{theme}'")
    print("-" * 31)

def run_debug(port: str, baud: int, reset: bool):
    print(f"\nInitializing debugging on {port} @ {baud} baud...")
    try:
        # Open port. If reset is disabled, we set DTR/RTS carefully.
        # Open with DTR=False, RTS=False initially to prevent resetting if --no-reset is specified
        s = serial.Serial()
        s.port = port
        s.baudrate = baud
        s.timeout = 2.0
        
        if not reset:
            # Open without resetting (DTR=True, RTS=False for native CDC readiness without pulse)
            s.dtr = True
            s.rts = False
            s.open()
            print("Opened port (DTR=True, RTS=False - Auto-reset bypassed).")
        else:
            s.open()
            print("Opened port. Resetting board via DTR/RTS pulse...")
            s.dtr = False
            s.rts = True
            time.sleep(0.1)
            s.dtr = True
            s.rts = False
            print("Waiting 3.5s for board to boot and CDC to re-initialize...")
            time.sleep(3.5)

        # Read any boot logs or startup messages
        if s.in_waiting:
            time.sleep(0.1)
            incoming = s.read(s.in_waiting)
            print("\nIncoming data prior to handshake:")
            print(incoming.decode('utf-8', errors='ignore'))
            print("Hex:", incoming.hex())
            print("-" * 30)

        # Send GET_CONF packet
        packet = build_get_conf_packet()
        print(f"\nTX -> GET_CONF ({packet.hex()})")
        s.write(packet)
        s.flush()

        # Read response
        print("Waiting for response (timeout 2s)...")
        time.sleep(0.5)
        
        if s.in_waiting:
            resp = s.read(s.in_waiting)
            print(f"RX <- Received {len(resp)} bytes")
            
            # Print raw logs if mixed in
            text_part = resp.decode('utf-8', errors='ignore')
            print("\nReceived stream text / logs:")
            print(text_part)
            
            # Extract and parse binary packet starting with 0x55
            idx = resp.find(0x55)
            if idx != -1:
                pkt_data = resp[idx:]
                if len(pkt_data) >= 6:
                    length = pkt_data[1] | (pkt_data[2] << 8)
                    cmd = pkt_data[3]
                    print(f"\nDetected Packet at offset {idx}:")
                    print(f"  Length: {length} bytes")
                    print(f"  Command: {cmd:#04x} ({'CONF_DATA' if cmd == RK_CMD_CONF_DATA else 'UNKNOWN'})")
                    
                    if cmd == RK_CMD_CONF_DATA:
                        # Validate CRC
                        computed_crc = rk_crc16(pkt_data[3:length-2])
                        received_crc = pkt_data[length-2] | (pkt_data[length-1] << 8)
                        if computed_crc == received_crc:
                            print("  CRC Check: PASS")
                            parse_conf_data(pkt_data[:length])
                        else:
                            print(f"  CRC Check: FAIL (got {received_crc:#06x}, expected {computed_crc:#06x})")
                else:
                    print("Packet fragment is too short to parse.")
            else:
                print("No packet start byte (0x55) found in the received stream.")
        else:
            print("\nTIMEOUT: No response received from device.")
            print("\n💡 Troubleshooting Tips:")
            print("1. ESP32-S3 Native USB CDC requires DTR=True to process serial data.")
            print("2. If the board did not reset, it might have missed the trigger. Try running without --no-reset.")
            print("3. Ensure that your sketch calls RadioKit.update() in loop() and initRadioKit() in setup().")
            
        s.close()
        print("\nSession closed.")

    except Exception as e:
        print(f"Error during debugging: {e}")

def main():
    parser = argparse.ArgumentParser(description="RadioKit Serial Protocol CLI Debugger")
    parser.add_argument("-l", "--list", action="store_true", help="List available serial ports")
    parser.add_argument("-p", "--port", type=str, default="/dev/ttyACM0", help="Serial port to connect (default: /dev/ttyACM0)")
    parser.add_argument("-b", "--baud", type=int, default=1000000, help="Baud rate (default: 1000000)")
    parser.add_argument("--no-reset", action="store_true", help="Skip resetting the board on connection (bypasses DTR/RTS reset pulse)")
    
    args = parser.parse_args()

    if args.list:
        list_ports()
    else:
        run_debug(args.port, args.baud, not args.no_reset)

if __name__ == "__main__":
    main()
