cd software_src
touch ../lst/_.lst
rm ../lst/*.lst
for i in *; do nasm -f bin $i -o ../software/$i -l ../lst/$i.lst; done
