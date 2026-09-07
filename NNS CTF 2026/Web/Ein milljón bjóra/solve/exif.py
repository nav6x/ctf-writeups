import sys, json, piexif
def inject(inpath, outpath, x=0.0, y=0.0):
    comment = json.dumps({"location":{"x":x,"y":y}}).encode('ascii')
    user_comment = b"ASCII\x00\x00\x00" + comment
    exif_dict = {"0th":{}, "Exif":{piexif.ExifIFD.UserComment: user_comment}, "GPS":{}, "1st":{}, "thumbnail":None}
    exif_bytes = piexif.dump(exif_dict)
    piexif.insert(exif_bytes, inpath, outpath)
if __name__=='__main__':
    inject(sys.argv[1], sys.argv[2])
    print("wrote", sys.argv[2])
