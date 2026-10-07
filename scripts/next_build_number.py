#!/usr/bin/env python3
"""Prints the next build number for MARKETING_VERSION: highest existing build + 1, never below FIRST_BUILD."""
import os, sys, time, json, urllib.request, urllib.parse
import jwt

KEY_ID = os.environ["KEY_ID"]; ISSUER = os.environ["ISSUER_ID"]; APP = os.environ["ASC_APP_ID"]
VERSION = os.environ["MARKETING_VERSION"]; FIRST = int(os.environ.get("FIRST_BUILD", "1"))
key = open(os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")).read()
token = jwt.encode({"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 600, "aud": "appstoreconnect-v1"},
                   key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})
q = urllib.parse.urlencode({"filter[app]": APP, "filter[preReleaseVersion.version]": VERSION, "limit": 200})
req = urllib.request.Request(f"https://api.appstoreconnect.apple.com/v1/builds?{q}", headers={"Authorization": f"Bearer {token}"})
with urllib.request.urlopen(req) as r:
    data = json.load(r)["data"]
nums = [int(b["attributes"]["version"]) for b in data if b["attributes"]["version"].isdigit()]
print(max(nums + [FIRST - 1]) + 1)
