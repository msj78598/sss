#!/usr/bin/env python3
"""يسجّل معرّف الحزمة في Apple Developer Portal عبر App Store Connect API إن لم يكن مسجّلًا."""
import json, os, sys, time, urllib.request, urllib.error
import jwt  # PyJWT

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
KEY_PATH = os.environ["ASC_KEY_PATH"]
BUNDLE_ID = sys.argv[1]
NAME = sys.argv[2] if len(sys.argv) > 2 else "Thakir"

token = jwt.encode(
    {"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 600, "aud": "appstoreconnect-v1"},
    open(KEY_PATH).read(), algorithm="ES256", headers={"kid": KEY_ID})
BASE = "https://api.appstoreconnect.apple.com/v1"
H = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

def call(method, path, body=None):
    req = urllib.request.Request(BASE + path, method=method, headers=H,
                                 data=json.dumps(body).encode() if body else None)
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        print(e.read().decode(), file=sys.stderr)
        raise

existing = call("GET", f"/bundleIds?filter[identifier]={BUNDLE_ID}&filter[platform]=IOS")["data"]
if any(b["attributes"]["identifier"] == BUNDLE_ID for b in existing):
    print(f"bundle id {BUNDLE_ID} already registered")
else:
    call("POST", "/bundleIds", {"data": {"type": "bundleIds", "attributes": {
        "identifier": BUNDLE_ID, "name": NAME, "platform": "IOS"}}})
    print(f"registered bundle id {BUNDLE_ID}")
