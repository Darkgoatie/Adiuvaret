#!/usr/bin/env python3
"""Waits until the uploaded build is VALID, makes sure it is in an internal TestFlight group, and fails if it is not."""
import os, sys, time, json, urllib.request, urllib.parse
import jwt

KEY_ID = os.environ["KEY_ID"]; ISSUER = os.environ["ISSUER_ID"]; APP = os.environ["ASC_APP_ID"]
BUILD = os.environ["BUILD_NUMBER"]
key = open(os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")).read()

def call(path, method="GET", body=None):
    token = jwt.encode({"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 600, "aud": "appstoreconnect-v1"},
                       key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})
    req = urllib.request.Request("https://api.appstoreconnect.apple.com" + path, method=method,
                                 data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read(); return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.read().decode()[:200]}

build = None
for _ in range(60):
    q = urllib.parse.urlencode({"filter[app]": APP, "filter[version]": BUILD, "limit": 5})
    _, d = call(f"/v1/builds?{q}")
    found = d.get("data", [])
    if found:
        build = found[0]; state = build["attributes"]["processingState"]; print("build", BUILD, state, flush=True)
        if state == "VALID": break
        if state in ("FAILED", "INVALID"): sys.exit(f"build {BUILD} is {state}")
    else:
        print("build", BUILD, "not listed yet", flush=True)
    time.sleep(30)
else:
    sys.exit(f"build {BUILD} never became VALID")

_, g = call(f"/v1/apps/{APP}/betaGroups?limit=50")
groups = [x["id"] for x in g.get("data", []) if x["attributes"].get("isInternalGroup")]
if not groups: sys.exit("no internal TestFlight group on this app")
for gid in groups:
    st, _ = call(f"/v1/betaGroups/{gid}/relationships/builds", "POST", {"data": [{"type": "builds", "id": build["id"]}]})
    print("attach", gid[:8], st)  # 422 is fine: the group already has access to all builds
inside = set()
for gid in groups:
    _, r = call(f"/v1/betaGroups/{gid}/relationships/builds?limit=200")
    inside |= {x["id"] for x in r.get("data", [])}
if build["id"] not in inside: sys.exit(f"build {BUILD} is VALID but not in any internal group")
_, bd = call(f"/v1/builds/{build['id']}/buildBetaDetail")
print("DONE build", BUILD, bd.get("data", {}).get("attributes", {}).get("internalBuildState"), "in group: yes")
