#!/bin/sh
proxy=proxy:9050
sha_pool=stratum+tcp://eu.multipool.us:8888 
scrypt_pool=stratum+tcp://ltc.pool.minergate.com:3336 
usb=$(lsusb |grep "0483:5740"|cut -d " " -f 2,4|sed 's/://g'|sed 's/ /:/g')
while getopts b:l:p: option 
do
	case "${option}" in
		b) sha_pool=${OPTARG};;
		l) scrypt_pool=${OPTARG};;
		p) proxy=${OPTARG};;
	esac
done

echo "Starting cminer on USB ${usb}"
cgminer --gridseed-options=baud115200,freq=800,chips=5,modules=1,usefifo=0,btc=16 --hotplug=0 -o ${sha_pool} -u whatever4711.1 -p x --socks-proxy="${proxy}" --usb ${usb}  -T &
  
minerd --algo=scrypt -F 800 -G /dev/ttyACM0 -o ${scrypt_pool} -u whatever4711@gmail.com -p x --proxy="socks5://${proxy}" --dual
