#!/bin/sh
proxy=proxy:9050
sha_pool=stratum+tcp://eu.multipool.us:8888 
sha_user=whatever4711.1
scrypt_pool=stratum+tcp://ltc.pool.minergate.com:3336
scrypt_user=whatever4711@gmail.com
usb=$(lsusb |grep "0483:5740"|cut -d " " -f 2,4|sed 's/://g'|sed 's/ /:/g')
tty="/dev/ttyACM0"
while getopts b:c:l:m:p: option 
do
	case "${option}" in
		b) sha_pool=${OPTARG};;
		c) sha_user=${OPTARG};;
		l) scrypt_pool=${OPTARG};;
		m) scrypt_user=${OPTARG};;
		p) proxy=${OPTARG};;
	esac
done

echo "Starting cminer on USB ${usb}"
echo "With SHA-Pool ${sha_pool}"
cgminer --gridseed-options=baud115200,freq=800,chips=5,modules=1,usefifo=0,btc=16 --hotplug=0 -o ${sha_pool} -u ${sha_user} -p x --socks-proxy="${proxy}" --usb ${usb} -T &
echo "Starting minerd on ${tty}"
echo "With Scrypt-Pool ${scrypt_pool}"
minerd --algo=scrypt -F 800 -G ${tty} -o ${scrypt_pool} -u ${scrypt_user} -p x --proxy="socks5://${proxy}" --dual
