#!/bin/sh
set -e

if ! [ -z $1 ] && [ $1 = "-q" ]; then
	quiet=true
	installdisk=$2
fi;

if ! [ -z $1 ] && [ $1 = "-qq" ]; then
	quiet=true
	veryquiet=true
	installdisk=$2
fi;

if [ -z $installdisk ]; then
	installdisk=placeholder
fi;

if ! [ -z $quiet ] && [ $installdisk = "placeholder"]; then
	echo " -> if running in quiet mode, a path to disk device is required."
	exit 1
fi;

if [ $installdisk = placeholder ]; then
	installdisk=$1
	if [ -z $installdisk ]; then
		echo " -> please provide disk device you're installing to as argument"
		exit 1
	fi;
fi;

qread() {
	if ! [ -z $quiet ]; then
		echo $2
		eval $1="\"$2\""
		return
	fi;
	read $1
}
qqread() {
	if ! [ -z $quiet ] && ! [ -z $veryquiet]; then
		echo $2
		eval $1="\"$2\""
		return
	fi;
	read $1
}

echo " -> setting timezone"
hwclock --systohc

echo " -> generating locale"
locale-gen

printf " => Create non root user? "
qread nonroot y
if [ $nonroot = "n" ]; then
	true
else
	printf " => Username: "
	qqread username user
	if [ -z $username ]; then
		username=user
	fi;
	if id $username &>/dev/null; then
		echo " -> user $username already exists, skipping"
	else
		useradd -m $username
		echo " => Password: "
		if [ -z $veryquiet ]; then
			passwd $username
		else
			echo " -> SETTING USER \"$username\" PASSWORD TO \"password\""
			echo "password" | passwd $username --stdin
			sleep 2
		fi;
	fi;
fi;

echo " -> adding to sudoers"
sed -i "s/root ALL=(ALL) ALL/root ALL=(ALL) ALL\n$username ALL=(ALL) ALL/" /etc/sudoers

echo " -> installing grub as bootloader"
grub-install --target=i386-pc $installdisk
echo " -> removing quiet from grub linux parameters"
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\"/" /etc/default/grub
#cat /etc/default/grub | sed "s/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\"/" > /etc/default/grub
echo " -> making grub config"
grub-mkconfig -o /boot/grub/grub.cfg

echo " -> chroot setup done"

echo " -> running scripts"
source scripts/main

echo " -> exiting"
