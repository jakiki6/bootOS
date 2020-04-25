import os, shutil, sys

files = []

for r, _, f in os.walk("software/"):
    for file in f:
        if os.path.abspath(os.path.join(file, r)) in [os.path.abspath(i) for i in sys.argv]:
            continue
        if len(files) > 32:
            print("Limit of files reached")
            break
        if len(file) > 16:
            print(f + " has a too big filename")
            continue
        files.append(file.encode())
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
with open("appendix", "rb") as file:
    appendix = file.read()
    file_space[33*512:33*512 + len(appendix)] = bytearray(appendix)
flash = dir + file_space
with open("base.img", "wb") as output:
        output.write(flash)
        print("Wrote {} bytes of data".format(len(flash)))