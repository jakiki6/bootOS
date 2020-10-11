import os, shutil, sys, math

files = []

with open("software.txt", "r") as file:
    for line in file.readlines():
        if line.startswith("#"):
            continue
        line = line[:-1]
        c = []
        for file in line.split(" "):
            c.append(file.encode())
        files.append(c)

flash = bytearray(0)

for s in range(0, len(files)):
    dir = bytearray(16 * 32)
    file_space = bytearray(512 * 256 - 2)
    container = files[s]
    for i in range(0, len(container)):
        file = container[i]
        with open("software/" + file.decode(), "rb") as f:
            content = f.read()
            if len(content) > 512:
                print(file.decode() + " is too big")
                continue
            dir[i*16:i*16+len(file)] = bytearray(file)
            file_space[i*512:i*512+512] = bytearray(content)
    flash += bytearray(512) + dir + file_space
    if not len(flash) % (512 * 256):
        continue
    flash += bytearray((256 * 512) - (len(flash) % (256 * 512)))

with open("base.img", "wb") as output:
        output.write(flash)
        print("Wrote {} bytes of data".format(len(flash)))
