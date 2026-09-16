import urllib.request
import json
import re

url = "https://api.github.com/repos/larp-larp-larp/larp/commits/2ff1293a0da908202dc16628e5c1fa68c05294ec"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
data = json.loads(urllib.request.urlopen(req).read().decode())
patch = data["files"][0]["patch"]
flag = re.search(r"K17\{[^}]+\}", patch).group(0)
print(flag)
