#!/bin/sh

if [ ! -f /.root_pw_set ]; then
	sh /set_root_pw.sh
fi

ssh-keygen -A

exec /usr/sbin/sshd -D
