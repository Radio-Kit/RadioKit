import time
import json
import urllib.request
import threading
import serial
import statistics

BASE_URL = "http://127.0.0.1:7007"
SERIAL_PORT = "/dev/ttyACM0"
BAUD_RATE = 115200

def set_widget(widget_id, values):
    url = f"{BASE_URL}/api/widgets/{widget_id}"
    req = urllib.request.Request(
        url,
        data=json.dumps({"values": values}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="PUT"
    )
    t0 = time.perf_counter()
    with urllib.request.urlopen(req, timeout=5) as resp:
        body = resp.read()
    t1 = time.perf_counter()
    return t0, (t1 - t0) * 1000.0

class SerialMonitor:
    def __init__(self, port, baud):
        self.ser = serial.Serial(port, baud, timeout=0.05)
        self.running = True
        self.events = []
        self.lock = threading.Lock()
        self.latest_status = {}
        self.history = []
        self.thread = threading.Thread(target=self._reader, daemon=True)
        self.thread.start()

    def _reader(self):
        while self.running:
            try:
                line = self.ser.readline()
                if line:
                    t = time.perf_counter()
                    text = line.decode("utf-8", errors="replace").strip()
                    if text:
                        with self.lock:
                            self.events.append((t, text))
                            self._parse_status(t, text)
            except Exception:
                break

    def _parse_status(self, t, text):
        if text.startswith("[STATUS]"):
            fields = {}
            parts = text[8:].strip().split()
            for p in parts:
                if ":" in p:
                    k, v = p.split(":", 1)
                    fields[k] = v.rstrip("%")
            fields["_timestamp"] = t
            self.latest_status = fields
            self.history.append((t, dict(fields)))
            if len(self.history) > 200:
                self.history.pop(0)

    def get_latest(self):
        with self.lock:
            return dict(self.latest_status)

    def wait_for_condition(self, check_fn, start_time, timeout=1.5):
        deadline = start_time + timeout
        while time.perf_counter() < deadline:
            with self.lock:
                for t, st in reversed(self.history):
                    if t >= start_time and check_fn(st):
                        return (t - start_time) * 1000.0
            time.sleep(0.004)
        return None

    def close(self):
        self.running = False
        try:
            self.ser.close()
        except Exception:
            pass

def main():
    print("=" * 70)
    print("  MIKRO_V2 HARDWARE LATENCY & RESPONSE BENCHMARK (Remote API -> MCU)")
    print("=" * 70)

    print("\nConnecting to Serial Monitor on", SERIAL_PORT, "...")
    mon = SerialMonitor(SERIAL_PORT, BAUD_RATE)
    time.sleep(0.5)

    status = mon.get_latest()
    print("Initial MCU Status:", status)

    # 1. API RTT & Fast Button Dispatch
    print("\n--- 1. Testing Remote API RTT (50 Horn Pulses) ---")
    rtt_samples = []
    for _ in range(25):
        _, rtt1 = set_widget(8, [1])
        _, rtt2 = set_widget(8, [0])
        rtt_samples.extend([rtt1, rtt2])
        time.sleep(0.02)

    print(f"API RTT (50 samples): Min={min(rtt_samples):.1f}ms, Mean={statistics.mean(rtt_samples):.1f}ms, Median={statistics.median(rtt_samples):.1f}ms, Max={max(rtt_samples):.1f}ms")

    # 2. Benchmark Lighting (Headlight State Sync)
    print("\n--- 2. Testing Lighting Latency (Widget 3 -> Headlight State) ---")
    light_latencies = []
    # 0x01: Low Beam (Head:2), 0x03: High Beam (Head:3), 0x00: OFF (Head:0)
    light_steps = [(1, "2", "Low Beam"), (3, "3", "High Beam"), (0, "0", "OFF")]
    for _ in range(3):
        for bitmask, expected_head, label in light_steps:
            t0, _ = set_widget(3, [bitmask])
            res = mon.wait_for_condition(lambda s: s.get("Head") == expected_head, t0)
            if res is not None:
                light_latencies.append(res)
                print(f"  Light -> {label:<10} (Mask: {bitmask}): Latency = {res:5.1f} ms")
            else:
                print(f"  Light -> {label:<10} (Mask: {bitmask}): Timeout")
            time.sleep(0.15)

    # 3. Benchmark Turn Signals (Widgets 5, 6)
    print("\n--- 3. Testing Turn Signal Latency (Widgets 5, 6 -> Indicator LEDs) ---")
    ind_latencies = []
    for _ in range(4):
        # Left ON
        t0, _ = set_widget(5, [1])
        res = mon.wait_for_condition(lambda s: s.get("L") == "1", t0)
        if res is not None:
            ind_latencies.append(res)
            print(f"  Left Indicator ON  : Latency = {res:5.1f} ms")
        time.sleep(0.12)
        # Left OFF
        t0, _ = set_widget(5, [0])
        res = mon.wait_for_condition(lambda s: s.get("L") == "0", t0)
        if res is not None:
            ind_latencies.append(res)
            print(f"  Left Indicator OFF : Latency = {res:5.1f} ms")
        time.sleep(0.12)

    # 4. Benchmark Steering Wheel (Widget 0 -> Servo Angle)
    print("\n--- 4. Testing Steering Wheel Latency (Widget 0 -> Servo Dispatch) ---")
    steer_latencies = []
    for _ in range(2):
        for angle in [45, -45, 90, -90, 0]:
            t0, _ = set_widget(0, [angle])
            res = mon.wait_for_condition(lambda s: s.get("Steer") == str(angle), t0)
            if res is not None:
                steer_latencies.append(res)
                print(f"  Steer {angle:>3}° -> Latency = {res:5.1f} ms")
            else:
                print(f"  Steer {angle:>3}° -> Timeout")
            time.sleep(0.12)

    # 5. Benchmark Throttle / Motor (Widget 1 -> Motor Speed & PWM)
    print("\n--- 5. Testing Throttle & Motor PWM Latency ---")
    # Start engine
    t0, _ = set_widget(4, [1])
    mon.wait_for_condition(lambda s: s.get("Eng") in ("IDLE", "RUNNING"), t0, timeout=3.0)
    time.sleep(0.4)

    # Shift to Drive (D)
    t0, _ = set_widget(9, [0])
    mon.wait_for_condition(lambda s: s.get("Gear") == "D", t0, timeout=1.0)
    time.sleep(0.3)

    throttle_latencies = []
    for _ in range(2):
        for thr in [30, 60, 90, 0]:
            raw_val = thr * 2 - 100
            t0, _ = set_widget(1, [raw_val])
            res = mon.wait_for_condition(
                lambda s: int(s.get("Thr", -1)) >= thr - 5 if thr > 0 else int(s.get("Thr", -1)) == 0,
                t0
            )
            if res is not None:
                throttle_latencies.append(res)
                mot = mon.get_latest().get("Mot", "0")
                print(f"  Throttle {thr:>3}% (Raw: {raw_val:>4}) -> MCU Mot={mot}% | Latency = {res:5.1f} ms")
            else:
                print(f"  Throttle {thr:>3}% -> Timeout")
            time.sleep(0.2)

    # Park & Stop Engine
    set_widget(9, [1])
    set_widget(4, [0])
    time.sleep(0.3)

    # Summary
    print("\n" + "=" * 70)
    print("                    HARDWARE LATENCY BENCHMARK REPORT")
    print("=" * 70)
    all_tests = [
        ("HTTP Remote API RTT", rtt_samples),
        ("Lighting Control (Headlight Sync)", light_latencies),
        ("Turn Signals (Indicator LED Sync)", ind_latencies),
        ("Steering Wheel (Servo Dispatch)", steer_latencies),
        ("Throttle / Gas Pedal (PWM Dispatch)", throttle_latencies),
    ]

    for name, samples in all_tests:
        if samples:
            print(f"  • {name:<36}: Min={min(samples):5.1f}ms | Mean={statistics.mean(samples):5.1f}ms | Median={statistics.median(samples):5.1f}ms | Max={max(samples):5.1f}ms")
        else:
            print(f"  • {name:<36}: No samples")
    print("=" * 70)

    mon.close()

if __name__ == "__main__":
    main()
