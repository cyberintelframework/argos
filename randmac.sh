#!/bin/bash

numbers=6
i=0
mac=""
if [ -r "/dev/urandom" ]; then
	SEED=$(head -1 /dev/urandom | od -N 1 | awk '{ print $2 }')
else
	SEED=`date +"%N"`
fi

while [ $i -le $numbers ]
do
	number[$i]=$RANDOM
	let "number[$i] %= 256"
	let "i += 1"
done
printf "%02X:%02X:%02X:%02X:%02X:%02X\n" ${number[0]} ${number[1]} ${number[2]}\
	${number[3]} ${number[4]} ${number[5]}
