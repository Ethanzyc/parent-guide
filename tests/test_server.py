#!/usr/bin/env python3
"""Unit tests for the production server.py (stdlib only).

Runs the server in-process on a worker thread against temp dirs, then checks
the API contract: template bootstrap fallback, atomic writes, validation
rejections, static hosting. Run: python3 tests/test_server.py
"""
import http.client
import json
import shutil
import tempfile
import threading
import unittest
from pathlib import Path

import sys, os
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
import server  # noqa: E402

HOST, PORT = "127.0.0.1", 18765  # test fixture constants


def call(method, path, payload=None):
    """Talk to the in-process test server over http.client."""
    conn = http.client.HTTPConnection(HOST, PORT, timeout=5)
    try:
        headers, body = {}, None
        if payload is not None:
            body = json.dumps(payload)
            headers["Content-Type"] = "application/json"
        conn.request(method, path, body=body, headers=headers)
        resp = conn.getresponse()
        return resp.status, json.loads(resp.read() or b"{}")
    finally:
        conn.close()


class ServerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix="pg-server-test-"))
        cls.data_dir = cls.tmp / "data"
        cls.web_dir = cls.tmp / "web"
        cls.web_dir.mkdir()
        (cls.web_dir / "render.html").write_text("<!DOCTYPE html><title>stub</title>",
                                                 encoding="utf-8")
        cls.httpd = server.make_server(PORT, cls.data_dir, cls.web_dir)
        threading.Thread(target=cls.httpd.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_01_get_page_bootstraps_from_template(self):
        code, body = call("GET", "/api/page")
        self.assertEqual(code, 200)
        self.assertTrue(isinstance(body.get("blocks"), list))
        self.assertTrue(body.get("bootstrapped"), "missing-file GET must flag bootstrapped")

    def test_02_get_data_bootstraps_from_template(self):
        code, body = call("GET", "/api/data")
        self.assertEqual(code, 200)
        keys = [k for k in body if not k.startswith("_")]
        self.assertTrue(keys, "template data must contain a child key")
        self.assertTrue(body.get("bootstrapped"))

    def test_03_static_hosting(self):
        conn = http.client.HTTPConnection(HOST, PORT, timeout=5)
        try:
            conn.request("GET", "/")
            resp = conn.getresponse()
            self.assertEqual(resp.status, 200)
            self.assertIn("stub", resp.read().decode())
        finally:
            conn.close()

    def test_04_post_bad_json_rejected(self):
        conn = http.client.HTTPConnection(HOST, PORT, timeout=5)
        try:
            conn.request("POST", "/api/page", body=b"{not json",
                         headers={"Content-Type": "application/json"})
            resp = conn.getresponse()
            self.assertEqual(resp.status, 400)
            resp.read()
        finally:
            conn.close()

    def test_05_post_page_without_blocks_rejected(self):
        code, _ = call("POST", "/api/page", {"version": 2, "blocks": "nope"})
        self.assertEqual(code, 400)

    def test_06_post_data_without_child_rejected(self):
        code, _ = call("POST", "/api/data", {"_meta": {"notice": "no child"}})
        self.assertEqual(code, 400)

    def test_07_post_page_atomic_roundtrip(self):
        page = {"version": 2, "title": "t", "child": "c", "blocks":
                [{"id": "b1", "type": "profile", "x": 0, "y": 0, "w": 4, "h": 5}]}
        code, _ = call("POST", "/api/page", page)
        self.assertEqual(code, 200)
        code, got = call("GET", "/api/page")
        self.assertEqual(code, 200)
        self.assertEqual(got["blocks"][0]["id"], "b1")
        self.assertNotIn("bootstrapped", got, "after a real file exists, no bootstrap flag")
        leftovers = [f.name for f in self.data_dir.iterdir() if f.name.endswith(".tmp")]
        self.assertEqual(leftovers, [], "atomic write must leave no tmp files")

    def test_08_post_data_writes_child(self):
        child = {"_meta": {"notice": "n"}, "taozi": {"name": "桃子", "birthdate": "2024-04-10"}}
        code, _ = call("POST", "/api/data", child)
        self.assertEqual(code, 200)
        code, got = call("GET", "/api/data")
        self.assertEqual(code, 200)
        self.assertEqual(got["taozi"]["name"], "桃子")


if __name__ == "__main__":
    unittest.main(verbosity=2)
