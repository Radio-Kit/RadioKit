#!/usr/bin/env python3
"""
RadioKit In-App MCP Server E2E Verification Script.

Tests the full SSE handshake, session initialization, tool discovery,
tool invocation, and resource reading against a running RadioKit companion app.
"""

import sys
import json
import time
import urllib.request
import urllib.parse
import threading

SERVER_URL = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:7007"

class McpClient:
    def __init__(self, base_url):
        self.base_url = base_url
        self.session_id = None
        self.endpoint_url = None
        self.sse_thread = None
        self.running = True
        self.received_messages = []
        self.lock = threading.Lock()

    def connect(self, timeout=5.0):
        req = urllib.request.Request(f"{self.base_url}/sse", headers={"Accept": "text/event-stream"})
        resp = urllib.request.urlopen(req, timeout=timeout)
        
        # Read the first event to get endpoint
        line = resp.readline().decode('utf-8').strip()
        while line != "event: endpoint":
            if not line:
                time.sleep(0.05)
            line = resp.readline().decode('utf-8').strip()
        
        data_line = resp.readline().decode('utf-8').strip()
        assert data_line.startswith("data: "), f"Unexpected data line: {data_line}"
        rel_endpoint = data_line[len("data: "):]
        self.endpoint_url = f"{self.base_url}{rel_endpoint}"
        
        # Extract sessionId
        parsed = urllib.parse.urlparse(self.endpoint_url)
        params = urllib.parse.parse_qs(parsed.query)
        self.session_id = params.get('sessionId', [None])[0]
        assert self.session_id, f"Could not find sessionId in {self.endpoint_url}"

        # Start background reader for subsequent SSE events
        def sse_reader():
            while self.running:
                try:
                    l = resp.readline().decode('utf-8')
                    if not l:
                        break
                    l = l.strip()
                    if l.startswith("data: "):
                        data_json = l[len("data: "):]
                        try:
                            msg = json.loads(data_json)
                            with self.lock:
                                self.received_messages.append(msg)
                        except Exception:
                            pass
                except Exception:
                    break

        self.sse_thread = threading.Thread(target=sse_reader, daemon=True)
        self.sse_thread.start()

    def send_rpc(self, method, params=None, msg_id=None):
        if msg_id is None:
            msg_id = int(time.time() * 1000)
        payload = {
            "jsonrpc": "2.0",
            "id": msg_id,
            "method": method,
            "params": params or {}
        }
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            self.endpoint_url,
            data=data,
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=15.0) as resp:
            resp_body = resp.read().decode('utf-8')
        return msg_id

    def wait_for_response(self, msg_id, timeout=15.0):
        start = time.time()
        while time.time() - start < timeout:
            with self.lock:
                for msg in self.received_messages:
                    if msg.get("id") == msg_id:
                        return msg
            time.sleep(0.05)
        raise TimeoutError(f"Timeout waiting for response to message {msg_id}")

    def call_tool(self, name, arguments=None):
        mid = self.send_rpc("tools/call", {"name": name, "arguments": arguments or {}})
        resp = self.wait_for_response(mid)
        if "error" in resp:
            raise RuntimeError(f"Tool call error: {resp['error']}")
        return resp.get("result", {})

    def close(self):
        self.running = False

def run_tests():
    print(f"=== RadioKit In-App MCP Verification ===")
    print(f"Connecting to {SERVER_URL}...")
    client = McpClient(SERVER_URL)
    
    try:
        client.connect()
        print(f"✓ SSE connected. Session ID: {client.session_id}")
        
        # 1. Initialize
        print("\n1. Testing 'initialize'...")
        mid = client.send_rpc("initialize", {
            "protocolVersion": "2024-11-05",
            "clientInfo": {"name": "e2e-tester", "version": "1.0"}
        })
        resp = client.wait_for_response(mid)
        server_info = resp.get("result", {}).get("serverInfo", {})
        print(f"✓ Initialized with server: {server_info.get('name')} v{server_info.get('version')}")
        assert server_info.get("name") == "radiokit-app"

        # 2. List Tools
        print("\n2. Testing 'tools/list'...")
        mid = client.send_rpc("tools/list")
        resp = client.wait_for_response(mid)
        tools = resp.get("result", {}).get("tools", [])
        tool_names = [t["name"] for t in tools]
        print(f"✓ Registered tools count: {len(tool_names)}")
        print(f"  Tools: {', '.join(tool_names[:8])}...")
        
        required_tools = [
            "radiokit_scan_devices",
            "radiokit_connect",
            "radiokit_disconnect",
            "radiokit_get_connection_status",
            "radiokit_get_connection_diagnostics",
            "radiokit_retry_handshake",
            "radiokit_get_packet_log",
            "radiokit_send_raw_packet",
            "radiokit_list_widgets",
            "radiokit_set_widget",
            "radiokit_fs_list",
            "radiokit_ota_upload",
            "radiokit_nvs_get",
        ]
        for rt in required_tools:
            assert rt in tool_names, f"Missing expected tool: {rt}"
        print("✓ All required tools present in tools/list")

        # 3. List Resources
        print("\n3. Testing 'resources/list'...")
        mid = client.send_rpc("resources/list")
        resp = client.wait_for_response(mid)
        resources = resp.get("result", {}).get("resources", [])
        resource_uris = [r["uri"] for r in resources]
        print(f"✓ Registered resources count: {len(resource_uris)}")
        print(f"  Resources: {resource_uris}")
        expected_uris = [
            "radiokit://console",
            "radiokit://widgets",
            "radiokit://fs",
            "radiokit://docs",
            "radiokit://diagnostics/connection",
            "radiokit://packets",
            "radiokit://devices",
            "radiokit://models",
            "radiokit://designs",
            "radiokit://session",
            "radiokit://app-log",
            "radiokit://flasher/log",
        ]
        for eu in expected_uris:
            assert eu in resource_uris, f"Missing expected resource: {eu}"

        # 4. Invoke radiokit_get_connection_status and diagnostics
        print("\n4. Testing 'radiokit_get_connection_diagnostics' and 'radiokit_get_packet_log'...")
        diag_res = client.call_tool("radiokit_get_connection_diagnostics")
        print("✓ radiokit_get_connection_diagnostics invoked successfully")

        packet_res = client.call_tool("radiokit_get_packet_log", {"limit": 10})
        print("✓ radiokit_get_packet_log invoked successfully")

        # 5. Invoke radiokit_get_connection_status
        print("\n4. Invoking 'radiokit_get_connection_status'...")
        result = client.call_tool("radiokit_get_connection_status")
        content = result.get("content", [{}])[0].get("text", "{}")
        status_data = json.loads(content)
        print(f"✓ Connection status: connected={status_data.get('connected')}")

        # 5. Read Resource radiokit://docs
        print("\n5. Testing 'resources/read' on 'radiokit://docs'...")
        mid = client.send_rpc("resources/read", {"uri": "radiokit://docs"})
        resp = client.wait_for_response(mid)
        contents = resp.get("result", {}).get("contents", [])
        assert len(contents) > 0, "No content returned for radiokit://docs"
        docs_text = contents[0].get("text", "")
        print(f"✓ Documentation resource read successfully ({len(docs_text)} chars)")

        # 6. Read Resource radiokit://console
        print("\n6. Testing 'resources/read' on 'radiokit://console'...")
        mid = client.send_rpc("resources/read", {"uri": "radiokit://console"})
        resp = client.wait_for_response(mid)
        contents = resp.get("result", {}).get("contents", [])
        assert len(contents) > 0, "No content returned for radiokit://console"
        print(f"✓ Console resource read successfully: {contents[0].get('text', '')[:60]}...")

        # 7. Read Resource radiokit://widgets
        print("\n7. Testing 'resources/read' on 'radiokit://widgets'...")
        mid = client.send_rpc("resources/read", {"uri": "radiokit://widgets"})
        resp = client.wait_for_response(mid)
        contents = resp.get("result", {}).get("contents", [])
        assert len(contents) > 0, "No content returned for radiokit://widgets"
        print(f"✓ Widgets resource read successfully: {contents[0].get('text', '')[:60]}...")

        # 8. Invoke radiokit_flasher_scan (triggers follow mode to /flasher)
        print("\n8. Invoking 'radiokit_flasher_scan' (triggers Follow Mode to /flasher)...")
        result = client.call_tool("radiokit_flasher_scan")
        content = result.get("content", [{}])[0].get("text", "{}")
        print(f"✓ Flasher scan result: {content}")

        # 9. Invoke radiokit_scan_devices (triggers follow mode to /models?sheet=pair)
        print("\n9. Invoking 'radiokit_scan_devices' (triggers Follow Mode to /models)...")
        result = client.call_tool("radiokit_scan_devices", {"timeoutSeconds": 1})
        content = result.get("content", [{}])[0].get("text", "{}")
        print(f"✓ Scan devices result: {content[:100]}...")

        print("\n=== ALL MCP E2E TESTS PASSED SUCCESSFULLY! ===")
    finally:
        client.close()

if __name__ == "__main__":
    run_tests()
