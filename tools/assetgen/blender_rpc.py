"""Talk to a running Blender through the BlenderMCP add-on's socket (default port 9876).

    python tools/assetgen/blender_rpc.py info
    python tools/assetgen/blender_rpc.py run path/to/script.py     # runs inside the open Blender

Start the add-on first: Blender > N sidebar > BlenderMCP > Connect to MCP server.
"""

import json
import socket
import sys


def call(command: str, params: dict | None = None, port: int = 9876, timeout: float = 120.0) -> dict:
    sock = socket.create_connection(("localhost", port), timeout=timeout)
    sock.sendall(json.dumps({"type": command, "params": params or {}}).encode("utf-8"))
    data = b""
    while True:
        chunk = sock.recv(65536)
        if not chunk:
            break
        data += chunk
        try:
            return json.loads(data.decode("utf-8"))
        except json.JSONDecodeError:
            continue
    return json.loads(data.decode("utf-8"))


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    if sys.argv[1] == "info":
        print(json.dumps(call("get_scene_info"), indent=2)[:4000])
    elif sys.argv[1] == "run" and len(sys.argv) > 2:
        with open(sys.argv[2], "r", encoding="utf-8") as handle:
            result = call("execute_code", {"code": handle.read()})
        print(json.dumps(result, indent=2)[:4000])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
