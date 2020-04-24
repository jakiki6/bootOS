import math
with open("os.img", "rb") as file:
    data = list(file.read())
digits = math.ceil(math.log(len(data), 10))
i = 0
while data[len(data) - 1] == 0:
    data.pop()
    i += 1
    print("\r" + str(i).zfill(digits) + " bytes stripped...", end="")
with open("os.img", "wb") as file:
    file.write(bytes(data))
print()
