#!/usr/bin/env python3
"""parent-guide local server: static hosting + data API. Stdlib only.

Serves the built single-file renderer (web/dist/render.html) and reads/writes
the user's local data directory (data/child.json + data/page.json). Data never
leaves the machine; GET falls back to data-templates when files are missing.

Usage:
    python3 server.py [--open] [--port N] [--data DIR] [--web DIR]
    Env overrides: PG_PORT / PG_DATA / PG_WEB (CLI flags win over env).
"""
import argparse
import json
import os
import webbrowser
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TEMPLATE_PAGE = ROOT / "skills/parent-guide/data-templates/page.json"
TEMPLATE_DATA = ROOT / "skills/parent-guide/data-templates/child.json"


def _load_json(path, bootstrap_flag=False):
    """Read JSON file; on missing file, fall back to the shipped template.

    Returns (obj, bootstrapped): bootstrapped=True means "no real file yet,
    content came from data-templates" so the client can hint first-time setup.
    """
    try:
        return json.loads(path.read_text("utf-8")), False
    except FileNotFoundError:
        obj = json.loads(TEMPLATE_PAGE.read_text("utf-8")) if path.name == "page.json" \
            else json.loads(TEMPLATE_DATA.read_text("utf-8"))
        return obj, True


def make_server(port, data_dir, web_dir):
    """Build an HTTPServer bound to localhost. Paths are resolved by the caller
    (CLI/env), so this factory stays test-friendly: no globals, no side effects."""
    data_dir = Path(data_dir)
    page_file = data_dir / "page.json"
    data_file = data_dir / "child.json"

    class Handler(SimpleHTTPRequestHandler):
        # SimpleHTTPRequestHandler(directory=...) confines static serving to
        # web_dir and normalizes away any ../ traversal internally.

        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(web_dir), **kwargs)

        def log_message(self, *args):  # keep console quiet
            pass

        def _send_json(self, code, obj):
            body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _read_body(self):
            length = int(self.headers.get("Content-Length") or 0)
            return json.loads(self.rfile.read(length) or b"{}")

        def do_GET(self):
            try:
                if self.path == "/api/page":
                    obj, bootstrapped = _load_json(page_file)
                    if bootstrapped:
                        obj["bootstrapped"] = True
                    return self._send_json(200, obj)
                if self.path == "/api/data":
                    obj, bootstrapped = _load_json(data_file)
                    if bootstrapped:
                        obj["bootstrapped"] = True
                    return self._send_json(200, obj)
            except (OSError, ValueError) as e:
                return self._send_json(500, {"error": str(e)})
            if self.path == "/":
                self.path = "/render.html"  # root serves the renderer directly
            super().do_GET()

        def do_POST(self):
            kind = self.path.removeprefix("/api/")
            target = {"page": page_file, "data": data_file}.get(kind)
            if target is None:
                return self._send_json(404, {"error": "unknown endpoint"})
            try:
                payload = self._read_body()
                if kind == "page" and not isinstance(payload.get("blocks"), list):
                    raise ValueError("page.json 必须包含 blocks 数组")
                if kind == "page":
                    # duplicate/missing block ids corrupt geometry write-backs
                    # (GridStack keys by id) -- fail fast, 400
                    ids = [b.get("id") for b in payload["blocks"] if isinstance(b, dict)]
                    bad = [i for i in ids if i is None or not str(i).strip()]
                    dup = sorted({i for i in ids if ids.count(i) > 1 and i is not None})
                    if bad or dup:
                        raise ValueError(f"blocks 存在重复/缺失 id: {dup or '(有 block 无 id)'}")
                    if len(ids) != len(payload["blocks"]):
                        raise ValueError("blocks 里混入了非对象条目")
                if kind == "data" and not [k for k in payload if not k.startswith("_")]:
                    raise ValueError("child.json 必须包含至少一个孩子数据键")
                payload.pop("bootstrapped", None)  # internal flag never persists
                data_dir.mkdir(parents=True, exist_ok=True)
                tmp = target.with_suffix(".json.tmp")
                tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), "utf-8")
                tmp.replace(target)  # atomic: tmp + rename, no half-written files
                self._send_json(200, {"saved": target.name})
            except (OSError, ValueError) as e:
                self._send_json(400, {"error": str(e)})

    return HTTPServer(("127.0.0.1", port), Handler)


def main():
    ap = argparse.ArgumentParser(description="parent-guide local server")
    ap.add_argument("--open", action="store_true", help="open the page in a browser")
    ap.add_argument("--port", type=int, default=int(os.environ.get("PG_PORT", 8765)))
    ap.add_argument("--data", default=os.environ.get("PG_DATA", str(ROOT / "data")))
    ap.add_argument("--web", default=os.environ.get("PG_WEB", str(ROOT / "web/dist")))
    args = ap.parse_args()

    httpd = make_server(args.port, args.data, args.web)
    url = f"http://127.0.0.1:{args.port}/render.html"
    print(f"parent-guide 本地服务已启动:{url}(Ctrl+C 退出)")
    if args.open:
        webbrowser.open(url)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nbye")


if __name__ == "__main__":
    main()
