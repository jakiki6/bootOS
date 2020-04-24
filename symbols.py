import os

content = ""
org = 0

with open("os.asm", "r") as file:
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
with open("os.asm", "r") as file:
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
with open("sysmap.asm", "w") as file:
    file.write(content)

os.system("nasm -f bin -o tmp.img sysmap.asm 2> sysmap.txt")
os.system("rm sysmap.asm tmp.img")

content = ""
prev = ""

with open("sysmap.txt", "r") as file:
    for line in file.readlines():
        ln = line
        line = ("_".join(line.split("_")[1:])).split(" ")[:2]
        if line[0] == "":
            continue
        if line[0][0] == ".":
            line[0] = prev + line[0]
        else:
            prev = line[0]
        try:
            content += "%define " + line[0] + " " + hex(org + int(line[1])) + "\n"
        except:
            pass
with open("sysmap.inc", "w") as file:
    file.write(content)

os.system("rm sysmap.txt")
