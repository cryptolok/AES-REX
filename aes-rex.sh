#!/usr/bin/env bash

#$ apt install gdb

echo -e "\033[01;33m"
echo '
	          ██▄▄       
	          ██▀▀       
	        ▄███▄        
	      ▄█████         
	 ▀▄▄▀▀  █▄ █▄        
'
echo 'AES-REX - AES-ni Registers kEy eXtractor'
echo -e "\e[0m"

process=$1
pid=$2
if [[ ! "$process" ]]
then
	echo 'Usage : aes-rex (-p $PID) $PROCESS'
	echo 'Example : aes-rex openssl'
	echo 'Example : aes-rex -p 1234'
	exit 1
fi
if [[ "$process" != "-p" ]]
then
	pid=$(pidof $process)
fi
if [[ ! "$pid" ]]
then
	echo 'PROCESS NOT FOUND'
	echo 'try to specify the PID'
	exit 2
fi

libcrypto=$(cat /proc/$pid/maps | grep 'lib.*.crypt' | head -n 1)
if [[ ! "$libcrypto" ]]
then
	echo 'PROCESS DOESNT USE A KNOWN CRYPTOGRAPHIC LIBRARY'
	exit 3
fi
address=$(echo "$libcrypto" | cut -d '-' -f 1)
location=$(echo '/')$(echo "$libcrypto" | cut -d '/' -f 2-)

debug="-p $pid -nh -q -batch "
breaks=$(objdump -d "$location" | grep -B10 'aesenc %xmm1,%xmm2' | grep 'xorps  %xmm0' | cut -d ':' -f 1 | tr -d ' ')
#libcrypto
if [[ ! "$breaks" ]]
then
	breaks=$(objdump -d "$location" | grep -B5 'aesenc %xmm1,%xmm0' | grep 'pxor   %xmm1,%xmm0' | cut -d ':' -f 1 | tr -d ' ')
#libgcrypt
	if [[ ! "$breaks" ]]
	then
		echo 'CANT FIND AES-NI INSTRUCTIONS'
		exit 4
	fi
fi
for break in $breaks
do
	debug=$debug"-ex 'tbreak *0x$address+0x$break' "
#	echo "tbreak *0x$address+0x$break"
done

debug=$debug'-ex "continue" -ex "print $xmm0.uint128" -ex "print $xmm1.uint128" -ex "print /x $rax" -ex "print /x $rdx" -ex "print /x $r9" -ex "print /x $r15"'
dump=$(echo "$debug" | xargs gdb 2>/dev/null | egrep '\$[1-6]' | cut -d '=' -f 2 | sed s/0x//g | tr -d '\nx')
#echo "$dump"
key=$(echo "$dump" | cut -d ' ' -f 2,3 | tr -d ' ' | tac -rs .. | tr -d '\n')
rounds=$(echo "$dump" | cut -d ' ' -f 4)
length=$(echo -n "$rounds" | wc -c)
if [[ $length -ne 1 ]]
then
	rounds=$(echo "$dump" | cut -d ' ' -f 5)
fi
r9=$(echo "$dump" | cut -d ' ' -f 6)
r15=$(echo "$dump" | cut -d ' ' -f 7)
mode=''

if [ "$r15" == "0" ] && [ "$r9" != "8" ]
then
	mode='CTR'
elif [[ "$r15" == "14" ]]
then
	mode='GCM'
elif [ "$r9" == "10" ] || [ "$r9" == "8" ]
then
	mode='ECB'
elif [ "$r15" == "7" ] || [ "$r9" == "8" ]
then
	mode='CFB/OFB'
elif [[ "$r9" == "1" ]]
then
	mode='CBC'
fi

if [[ "$rounds" == "9" ]]
then
	echo "*** AES 128 $mode KEY FOUND ***"
	echo "${key:32:64}"
elif [[ "$rounds" == "b" ]]
then
	echo "*** AES 192 $mode KEY FOUND ***"
	echo "${key:32:64}${key:0:16}"
elif [[ "$rounds" == "d" ]]
then
	echo "*** AES 256 $mode KEY FOUND ***"
	echo "${key:32:64}${key:0:32}"
else
	echo "*** AES $mode KEYS/IV FOUND ***"
	echo "${key:32:64}"
	echo "${key:32:64}${key:0:32}"
fi

#TODO get IV/counter (debug prior to key scheduling), get 256/512 keys for XTS mode, detect more cipher modes (like XTS) on more OSes, key modification/swap (depends on lib implementation, but once the good position found, can easily be done), support more cryptographic libraries, process wraping (see CryKeX project), add more OSes support (ubuntu, but baiscally depends on libs)

