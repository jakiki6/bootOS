import os, shutil, sys, math

files = []

for r, _, f in os.walk("software/"):
    for file in f:
        if os.path.abspath(os.path.join(file, r)) in [os.path.abspath(i) for i in sys.argv]:
            continue
        if len(file) > 16:
            print(f + " has a too big filename")
            continue
        files.append(file.encode())
flash = bytearray(0)

for s in range(0, math.ceil(len(files) / 32)):
    dir = bytearray(16 * 32)
    file_space = bytearray(512 * 2879)
    for i in range(0, len(files)):
        file = files[i]
        with open("software/" + file.decode(), "rb") as f:
            content = f.read()
            if len(content) > 512:
                print(file.decode() + " is too big")
                continue
            dir[i*16:i*16+len(file)] = bytearray(file)
            file_space[i*512:i*512+512] = bytearray(content)
    flash += dir + file_space
    if not len(flash) % 256:
        continue
    flash += bytearray(256 - (len(flash) % 256))

with open("base.img", "wb") as output:
        output.write(flash)
        print("Wrote {} bytes of data".format(len(flash)))
