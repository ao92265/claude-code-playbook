"""Pull the image out of a Gemini response on stdin and write it. Arg: output path.

Two things the Gemini passthrough does that the obvious code gets wrong:
the payload is base64url (so it carries - and _, which plain b64decode
silently discards), and the model returns JPEG regardless of the extension
you asked for.
"""
import base64, json, os, sys

out = sys.argv[1]
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception:
    sys.stderr.write("imagegen: non-JSON response: " + raw[:400] + "\n")
    sys.exit(1)
if "error" in d:
    sys.stderr.write("imagegen: gateway error: " + json.dumps(d["error"])[:500] + "\n")
    sys.exit(1)

EXT = {"image/jpeg": ".jpg", "image/jpg": ".jpg", "image/png": ".png",
       "image/webp": ".webp"}

for cand in d.get("candidates", []):
    for part in cand.get("content", {}).get("parts", []):
        blob = part.get("inlineData") or part.get("inline_data")
        if not (blob and blob.get("data")):
            continue
        s = blob["data"].replace("-", "+").replace("_", "/")
        data = base64.b64decode(s + "=" * (-len(s) % 4))
        want = EXT.get(blob.get("mimeType", ""), os.path.splitext(out)[1] or ".jpg")
        if os.path.splitext(out)[1].lower() != want:
            out = os.path.splitext(out)[0] + want
        with open(out, "wb") as fh:
            fh.write(data)
        print(out)
        sys.exit(0)

# No image came back. Surface any text the model returned instead, which is
# usually a refusal or a safety block and explains the empty result.
texts = [p["text"] for c in d.get("candidates", [])
         for p in c.get("content", {}).get("parts", []) if p.get("text")]
sys.stderr.write("imagegen: no image returned. "
                 + (" ".join(texts)[:400] or json.dumps(d)[:400]) + "\n")
sys.exit(1)
