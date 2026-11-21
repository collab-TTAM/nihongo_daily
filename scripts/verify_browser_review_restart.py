"""Real Chrome page reload/second-tab check; standard library, no hosted service."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import threading
import time
from urllib.request import Request, urlopen


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def verify(directory):
    driver = shutil.which("chromedriver")
    if not driver:
        driver = str(Path(os.environ.get("CHROMEWEBDRIVER", "")) / "chromedriver")
    if not Path(driver).is_file():
        raise RuntimeError("ChromeDriver required; browser verification cannot be skipped")
    directory = Path(directory).resolve()
    if not (directory / "main.js").is_file():
        raise RuntimeError("Compiled Dart browser verifier missing")
    (directory / "index.html").write_text(
        '<!doctype html><html><body>LOADING<script src="main.js"></script></body></html>',
        encoding="utf-8",
    )
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(directory)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    process = subprocess.Popen(
        [driver, f"--port={port}", "--allowed-ips=127.0.0.1"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    base = f"http://127.0.0.1:{port}"
    session = None

    def command(method, path, data=None):
        encoded = None if data is None else json.dumps(data).encode("utf-8")
        request = Request(base + path, data=encoded, method=method,
                          headers={"Content-Type": "application/json"})
        with urlopen(request, timeout=30) as response:
            value = json.load(response)["value"]
        if isinstance(value, dict) and "error" in value:
            raise RuntimeError("Browser driver command failed")
        return value

    def await_status(expected):
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            actual = command("POST", f"/session/{session}/execute/sync",
                             {"script": "return document.body.textContent", "args": []})
            if actual == expected:
                return
            if actual == "FAIL":
                raise RuntimeError("Dart IndexedDB reload verifier failed")
            time.sleep(0.1)
        raise RuntimeError(f"Browser verifier did not reach {expected}")

    try:
        for _ in range(100):
            try:
                command("GET", "/status")
                break
            except (OSError, ValueError):
                if process.poll() is not None:
                    raise RuntimeError("ChromeDriver exited during startup") from None
                time.sleep(0.1)
        else:
            raise RuntimeError("ChromeDriver startup timed out")
        result = command("POST", "/session", {"capabilities": {"alwaysMatch": {
            "browserName": "chrome", "goog:chromeOptions": {
                "args": ["--headless=new", "--no-sandbox", "--disable-dev-shm-usage"]
            }
        }}})
        session = result["sessionId"]
        target = f"http://127.0.0.1:{server.server_port}/index.html"
        command("POST", f"/session/{session}/url", {"url": target})
        await_status("PENDING_COMMITTED")
        # The browser tears down the entire page/JS memory with the DB still open.
        command("POST", f"/session/{session}/refresh", {})
        await_status("RECEIPT_COMMITTED")
        command("POST", f"/session/{session}/refresh", {})
        await_status("PASS")
        second = command("POST", f"/session/{session}/window/new", {"type": "tab"})
        command("POST", f"/session/{session}/window", {"handle": second["handle"]})
        command("POST", f"/session/{session}/url", {"url": target})
        await_status("PASS")
        print("PASS: actual Chrome page reload preserves pending/exact time/original receipt; second tab reads committed history. No hosted Auth/RPC or power-loss claim.")
    finally:
        if session:
            try:
                command("DELETE", f"/session/{session}")
            except OSError:
                pass
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


if __name__ == "__main__":
    verify(sys.argv[1])
