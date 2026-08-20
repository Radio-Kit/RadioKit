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

class EventSerialMonitor:
    def __init__(self, port, baud):
        self.ser = serial.Serial(port, baud, timeout=0.02)
        self.running = True
        self.events = []
        self.lock = threading.Lock()
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
                            if len(self.events) > 500:
                                self.events.pop(0)
            except Exception:
                break

    def wait_for_event(self, pattern, start_time, timeout=1.0):
        deadline = start_time + timeout
        while time.perf_counter() < deadline:
            with self.lock:
                for t, text in reversed(self.events):
                    if t >= start_time and pattern in text:
                        return (t - start_time) * 1000.0
            time.sleep(0.002)
        return None

    def close(self):
        self.running = False
        try:
            self.ser.close()
        except Exception:
            pass

def main():
    print("=" * 70)
    print("  INSTANT FIRMWARE EVENT LATENCY MEASUREMENT (App API -> MCU Loop)")
    print("=" * 70)

    mon = EventSerialMonitor(SERIAL_PORT, BAUD_RATE)
    time.sleep(0.5)

    # 1. Horn Instant Event Latency ([EVENT] Horn -> ON / OFF)
    print("\n--- 1. Horn Event Latency (Widget 8) ---")
    horn_latencies = []
    for i in range(10):
        t0, _ = set_widget(8, [1])
        res = mon.wait_for_event("[EVENT] Horn -> ON", t0)
        if res is not None:
            horn_latencies.append(res)
            print(f"  Horn ON  #{i+1:2d}: {res:5.1f} ms")
        time.sleep(0.05)

        t0, _ = set_widget(8, [0])
        res = mon.wait_for_event("[EVENT] Horn -> OFF", t0)
        if res is not None:
            horn_latencies.append(res)
            print(f"  Horn OFF #{i+1:2d}: {res:5.1f} ms")
        time.sleep(0.05)

    # 2. Headlight Instant Event Latency ([EVENT] Headlight -> LOW / HIGH / OFF)
    print("\n--- 2. Headlight Event Latency (Widget 3) ---")
    light_latencies = []
    steps = [
        (1, "[EVENT] Headlight -> LOW", "Low Beam"),
        (3, "[EVENT] Headlight -> HIGH", "High Beam"),
        (0, "[EVENT] Headlight -> OFF", "All OFF"),
    ]
    for cycle in range(5):
        for bitmask, pat, name in steps:
            t0, _ = set_widget(3, [bitmask])
            res = mon.wait_for_event(pat, t0)
            if res is not None:
                light_latencies.append(res)
                print(f"  Headlight {name:<9}: {res:5.1f} ms")
            time.sleep(0.08)

    # 3. Turn Signals Instant Event Latency
    print("\n--- 3. Turn Indicator Event Latency (Widgets 5, 6) ---")
    ind_latencies = []
    for cycle in range(5):
        # Left
        t0, _ = set_widget(5, [1])
        res = mon.wait_for_event("[EVENT] Left indicator ON", t0)
        if res is not None:
            ind_latencies.append(res)
            print(f"  Left Indicator ON : {res:5.1f} ms")
        time.sleep(0.08)
        set_widget(5, [0])
        time.sleep(0.05)

        # Right
        t0, _ = set_widget(6, [1])
        res = mon.wait_for_event("[EVENT] Right indicator ON", t0)
        if res is not None:
            ind_latencies.append(res)
            print(f"  Right Indicator ON: {res:5.1f} ms")
        time.sleep(0.08)
        set_widget(6, [0])
        time.sleep(0.05)

    # 4. Engine Start / Stop Event Latency
    print("\n--- 4. Engine Power State Latency (Widget 4) ---")
    eng_latencies = []
    t0, _ = set_widget(4, [1])
    res = mon.wait_for_event("[EVENT] Engine -> STARTING", t0, timeout=2.0)
    if res is not None:
        eng_latencies.append(res)
        print(f"  Engine STARTING : {res:5.1f} ms")
    time.sleep(1.5)

    t0, _ = set_widget(4, [0])
    res = mon.wait_for_event("[EVENT] Engine -> STOPPING", t0, timeout=2.0)
    if res is not None:
        eng_latencies.append(res)
        print(f"  Engine STOPPING : {res:5.1f} ms")

    print("\n" + "=" * 70)
    print("               TRUE REAL-TIME EVENT LATENCY SUMMARY")
    print("=" * 70)
    results = [
        ("Horn Trigger Latency", horn_latencies),
        ("Headlight Switch Latency", light_latencies),
        ("Indicator Switch Latency", ind_latencies),
        ("Engine Ignition Latency", eng_latencies),
    ]
    for name, samples in results:
        if samples:
            print(f"  • {name:<30}: Min={min(samples):5.1f}ms | Mean={statistics.mean(samples):5.1f}ms | Median={statistics.median(samples):5.1f}ms | Max={max(samples):5.1f}ms")
        else:
            print(f"  • {name:<30}: No samples")
    print("=" * 70)

    mon.close()

if __name__ == "__main__":
    main()
