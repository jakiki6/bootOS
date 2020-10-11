import sys, os

if len(sys.argv) < 3:
    print("Usage:", sys.argv[0], "<input>", "<output>")
    exit(1)

content = ""
org = 0

with open(sys.argv[1], "r") as file:
    for line in file.readlines():
        ln = line
        if ";" in line:
            line = line.split(";")[0] + "\n"
        if ":" in line:
            line = line.split(":")[0]
            line = line.strip().replace(" ", "").replace("\t", "")
            if not "equ" in ln.split(";")[0]:
                content += f"%assign __{line} ($ - $$)\n%warning {line} at __{line} n\n"
            else:
                l = ln.split(";")[0].strip()
                l = l.split(":")[1]
                l = l.replace("equ", "").strip()
                content += f"%assign __{line} {l}\n%warning {line} at __{line} e\n"
        elif "org" in line:
            line = line.replace("org", "").strip()
            org = eval(line)
        content += ln

with open("tmp.asm", "w") as file:
    file.write(content)

os.system("nasm -f bin -o tmp.img tmp.asm 2> tmp.txt")

os.unlink("tmp.img")
os.unlink("tmp.asm")

refs = []
last = ""

with open("tmp.txt", "r") as file:
    for line in file.readlines():
        line = line.strip()
        if line == "":
            continue
        line = line.split(":")[3].strip()
        line = line.replace("[-w+user]", "").strip()
        l = line.split(" ")
        line = " ".join(l[:-1])
        couple = line.split(" at ")
        try:
            couple[1] = int(couple[1])
        except:
            continue
        if l[-1] == "n":
            couple[1] += org
        if couple[0].startswith("."):
            couple[0] = last + couple[0]
        else:
            last = couple[0]
        refs.append(couple)

content = ""
for couple in refs:
    content += f"%define bootOS.{couple[0]} {couple[1]}\n"

with open(sys.argv[2], "w") as file:
    file.write(content)

os.unlink("tmp.txt")
