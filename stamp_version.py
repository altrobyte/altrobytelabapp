"""Stamp a version onto the app's entry point after a build.

index.html is served no-cache, so every visit refetches it. flutter_bootstrap.js
is not hashed by Flutter, so a browser that cached it under the old
max-age=31536000 rule will keep using that copy for a year and never see a new
deploy — the header fix only helps browsers that ask again.

Changing the URL is what forces them to ask. index.html comes back fresh,
points at a bootstrap URL they have never seen, and the whole chain reloads.

Run after `flutter build web`, before deploying.
"""

import io
import re
import sys
import time

path = "build/web/index.html"
version = str(int(time.time()))

html = io.open(path, encoding="utf-8").read()
before = html

html = re.sub(r'(src="flutter_bootstrap\.js)(\?v=\d+)?(")',
              rf'\1?v={version}\3', html)

if html == before:
    print("WARNING: flutter_bootstrap.js not found in index.html - nothing stamped")
    sys.exit(1)

io.open(path, "w", encoding="utf-8", newline="\n").write(html)
print(f"stamped flutter_bootstrap.js?v={version}")
