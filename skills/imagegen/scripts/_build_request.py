"""Build the Gemini generateContent request body. Args: aspect, prompt, [image paths...]"""
import base64, json, mimetypes, sys

aspect, prompt, *inputs = sys.argv[1:]
parts = [{"text": prompt}]
for path in inputs:
    mime = mimetypes.guess_type(path)[0] or "image/png"
    with open(path, "rb") as fh:
        parts.append({"inlineData": {"mimeType": mime,
                                     "data": base64.b64encode(fh.read()).decode()}})
print(json.dumps({"contents": [{"parts": parts}],
                  "config": {"responseModalities": ["IMAGE"],
                             "imageConfig": {"aspectRatio": aspect}}}))
