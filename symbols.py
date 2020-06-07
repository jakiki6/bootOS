#!/bin/env python3
import os, sys

if len(sys.argv) < 3:
    print(sys.argv[0], "<input>", "<include>")
    exit(1)

content = ""
org = 0

with open(sys.argv[1], "r") as file:
    for line in file.readlines():
        if ";" in line:
            line = line.split(";")[0]
        for char in "\t\n[]() ":
            if char in line:
                line = line.replace(char, "")
        if line == "":
            continue
        if line.startswith("org"):
            try:
                org = eval(line.replace("org", ""))
                break
            except:
                pass
with open(sys.argv[1], "r") as file:
    for line in file.readlines():
        if line.startswith("%"):
            continue
        if ":" in line:
            ln = line
            line = line.split(";")[0]
            if "equ" in line:
                content += ln
                continue
            if line == "":
                content += ln
                continue
            line = line.split(":")[0] + "\n"
            content += ln + "%assign __" + line.replace("\n", "") + " $ - $$\n%warning _" + line.replace("\n", "") + " __" + line
        else:
            content += line
with open("tmp.asm", "w") as file:
    file.write(content)

os.system(f"nasm -f bin -o tmp.img tmp.asm 2> tmp.txt")
os.system(f"rm tmp.asm tmp.img")

content = ""
prev = ""

with open("tmp.txt", "r") as file:
    for line in file.readlines():
        ln = line
        line = ("_".join(line.split("_")[1:])).split(" ")[:2]
        if line[0] == "":
            continue
        if line[0][0] == ".":
            line[0] = prev + line[0]
        else:
            prev = line[0]
        line[0] = "bootOS." + line[0]
        try:
            content += "%define " + line[0] + " " + hex(org + int(line[1])) + "\n"
        except:
            pass
content += '''
%define exit int 0x20
'''[1:]
with open(sys.argv[2], "w") as file:
    file.write(content)

os.system("rm tmp.txt")
