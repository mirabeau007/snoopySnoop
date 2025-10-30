#!/bin/bash
filename=""
outDir="./files_snooped/"
name="---->> SnoopySnoop <<----"
date=$(date)
nbFile=0

if [ ! -d "$outDir" ]; then
	mkdir "$outDir"
fi

echo $name && echo $name > "$outDir"audit.txt
echo $date >> "$outDir"audit.txt
echo -e "\nfilename		offset		size (bytes)\n" >> "$outDir"audit.txt
echo # just a newline


read -p "Please enter the path and filename of the .dd file: " filename
while [ ! -f "$filename" ]; do
	read -p "That file does not exist. Please enter the path and filename of the .dd file: " filename
done

recoverFiles() # $1: start;  $2: end;  $3: extension
{
	pattern=$(echo "$1" | tr -d " ").*?$(echo "$2" | tr -d " ")
	matches=$(xxd -ps -c 0 $filename | grep -P -b -o -i "$pattern")
	if [[ $matches != "" ]]; then
		while IFS= read -r line; do
			echo -n "#"
	    	offset=$(cut -d ":" -f1 <<< "$line")
	    	content=$(cut -d ":" -f2- <<< "$line")

	    	if [[ $(( offset % 2 )) == 0 ]]; then 	# ignores ‘misaligned’ matches
	    		offset=$((offset / 2)) 				# we divide by 2 because grep interprets hexadecimal as 2 char (2 bytes)
	    		length=$(( ${#content} / 2 )) 		# again we need to divide by 2
	    		$(dd if="$filename" of="$outDir""$nbFile"."$3" skip="$offset" count="$length" bs=1 conv=notrunc status=none)
	    		echo -e "$nbFile"."$3""\t\t\t$offset\t\t\t$length" >> "$outDir"audit.txt
	    		nbFile=$((nbFile+1))
	    	fi
		done <<< "$matches"
	fi
}

recoverBmp()
{
	matches=$(xxd -ps -c 0 $filename | grep -P -b -o -i "424d.{8}00000000")
	if [[ $matches != "" ]]; then
		while IFS= read -r line; do
			echo -n "#"
	    	offset=$(cut -d ":" -f1 <<< "$line")
	    	content=$(cut -d ":" -f2- <<< "$line")

	    	if [[ $(( offset % 2 )) == 0 ]]; then 	# ignores ‘misaligned’ matches
	    		offset=$((offset / 2)) 				# we divide by 2 because grep interprets hexadecimal as 2 char (2 bytes)
	    		hexlength=$(echo ${content:4:12} | tac -rs .. | echo "$(tr -d '\n')")
	    		length=$((16#$hexlength))
	    		$(dd if="$filename" of="$outDir""$nbFile".bmp skip="$offset" count="$length" bs=1 conv=notrunc status=none)
	    		echo -e "$nbFile".bmp"\t\t\t$offset\t\t\t$length" >> "$outDir"audit.txt
	    		nbFile=$((nbFile+1))
	    	fi
		done <<< "$matches"
	fi
}

menu="\nFile types that can be searched for are:\n
1 jpg\n 2 bmp\n 3 png\n 4 gif\n 5 pdf\n
6 all – search for all 5 file types\n
7 custom – search for a custom file signature\n
8 quit"
echo -e $menu
read selection

while [[ "$selection" != *"8"* && "$selection" != *"q"* ]]; do

	if [[ "$selection"  == *"1"* || "$selection" == *"6"* ]]; then
		recoverFiles "ffd8ff" "ffd90000" "jpg"
	fi
	if [[ "$selection"  == *"2"* || "$selection" == *"6"*  ]]; then
		recoverBmp
	fi
	if [[ "$selection"  == *"3"* || "$selection" == *"6"*  ]]; then
		recoverFiles "89504e470d0a1a0a" "49454e44" "png"
	fi
	if [[ "$selection"  == *"4"* || "$selection" == *"6"*  ]]; then
		recoverFiles "47494638" "3b0000" "gif"
	fi
	if [[ "$selection"  == *"5"* || "$selection" == *"6"*  ]]; then
		recoverFiles "255044462d" "25454f46" "pdf"
	fi
	if [[ "$selection"  == *"7"* ]]; then
		read -p "Please enter the custom start signature of 4 hexadecimal pairs: " customStart
		read -p "Please enter the custom end signature of 4 hexadecimal pairs: " customEnd
		recoverFiles "$customStart" "$customEnd" "dd"
	fi

	echo -e "\n$nbFile file(s) were recovered (total)"
	read -p "select new files to search or quit: " selection
done
echo -e "\n$nbFile file(s) were recovered" >> "$outDir"audit.txt

printf "\n\033[0;31m     |\__/,|   (\`\\ \n" &&  printf "\n\n     |\__/,|   (\`\\ \n" >> "$outDir"audit.txt
printf "   _.|o o  |_   ) )\n" && printf "   _.|o o  |_   ) )\n" >> "$outDir"audit.txt
printf " -(((---(((--------\033[0m\n\n" && printf " -(((---(((--------" >> "$outDir"audit.txt
