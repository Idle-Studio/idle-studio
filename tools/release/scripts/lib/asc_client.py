"""
asc_client.py — Thin JWT-authenticated App Store Connect REST API client.

Handles:
  - Token generation and auto-refresh (tokens expire after 20 min)
  - Automatic pagination (follows links.next)
  - Rate-limit retry (HTTP 429 → back off and retry)
  - JSON:API request/response structure

Usage:
    client = ASCClient.from_env()
    apps = client.get("/v1/apps", params={"filter[bundleId]": "com.example.app"})
"""

import os
import time
import datetime
import json
import requests
import jwt


BASE_URL = "https://api.appstoreconnect.apple.com"
TOKEN_LIFETIME_SECONDS = 1140  # 19 min (API max is 20)


class ASCClient:
    def __init__(self, key_id: str, issuer_id: str, private_key_path: str):
        self.key_id = key_id
        self.issuer_id = issuer_id
        with open(private_key_path) as f:
            self.private_key = f.read()
        self._token: str | None = None
        self._token_expiry: float = 0

    @classmethod
    def from_env(cls) -> "ASCClient":
        key_id   = os.environ["ASC_KEY_ID"]
        issuer   = os.environ["ASC_ISSUER_ID"]
        key_path = os.environ["ASC_KEY_PATH"]
        return cls(key_id, issuer, key_path)

    # ── Token ─────────────────────────────────────────────────────────────────

    def _make_token(self) -> str:
        now = int(time.time())
        payload = {
            "iss": self.issuer_id,
            "iat": now,
            "exp": now + TOKEN_LIFETIME_SECONDS,
            "aud": "appstoreconnect-v1",
        }
        return jwt.encode(
            payload,
            self.private_key,
            algorithm="ES256",
            headers={"kid": self.key_id, "typ": "JWT"},
        )

    def _token_header(self) -> dict:
        if time.time() >= self._token_expiry:
            self._token = self._make_token()
            self._token_expiry = time.time() + TOKEN_LIFETIME_SECONDS - 60
        return {"Authorization": f"Bearer {self._token}"}

    # ── HTTP ──────────────────────────────────────────────────────────────────

    def _request(self, method: str, path: str, **kwargs) -> dict:
        url = f"{BASE_URL}{path}" if path.startswith("/") else path
        headers = {**self._token_header(), "Content-Type": "application/json"}

        for attempt in range(5):
            resp = requests.request(method, url, headers=headers, **kwargs)
            if resp.status_code == 429:
                wait = int(resp.headers.get("Retry-After", 10)) + 1
                print(f"  Rate limited — waiting {wait}s...")
                time.sleep(wait)
                continue
            if resp.status_code == 204:
                return {}
            try:
                resp.raise_for_status()
            except requests.HTTPError as e:
                # Include ASC error details in the exception message
                try:
                    body = resp.json()
                    errors = body.get("errors", [])
                    detail = "; ".join(
                        f'{e.get("title")}: {e.get("detail")}' for e in errors
                    )
                    raise requests.HTTPError(f"{e}\n  ASC: {detail}", response=resp) from None
                except (ValueError, KeyError):
                    raise
            return resp.json() if resp.content else {}

        raise RuntimeError(f"Max retries exceeded for {method} {path}")

    def get(self, path: str, params: dict | None = None) -> dict:
        return self._request("GET", path, params=params)

    def get_all(self, path: str, params: dict | None = None) -> list:
        """Fetch all pages and return combined data list."""
        params = {**(params or {}), "limit": 200}
        results = []
        next_url: str | None = f"{BASE_URL}{path}"
        while next_url:
            resp = self._request("GET", next_url if "appstoreconnect" in next_url else path,
                                  params=params if "appstoreconnect" not in (next_url or "") else None)
            results.extend(resp.get("data", []))
            next_url = resp.get("links", {}).get("next")
            params = None  # pagination URL already has params embedded
        return results

    def post(self, path: str, body: dict) -> dict:
        return self._request("POST", path, data=json.dumps(body))

    def patch(self, path: str, body: dict) -> dict:
        return self._request("PATCH", path, data=json.dumps(body))

    def delete(self, path: str) -> None:
        self._request("DELETE", path)
