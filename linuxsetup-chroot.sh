#!/bin/sh
set -e
cd /
source scripts/colors

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
	echo "${error}  -> ${nc}if running in quiet mode, a path to disk device is required."
	exit 1
fi;

if [ $installdisk = placeholder ]; then
	installdisk=$1
	if [ -z $installdisk ]; then
		echo "${error}  -> ${nc}please provide disk device you're installing to as argument"
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

echo "${status}  -> ${nc}setting timezone"
hwclock --systohc

echo "${status}  -> ${nc}generating locale"
locale-gen

printf "${interact}==> ${nc}Create non root user? "
qread nonroot y
if [ $nonroot = "n" ]; then
	true
else
	printf "${interact}==> ${nc}Username: "
	qqread username user
	if [ -z $username ]; then
		username=user
	fi;
	if id $username &>/dev/null; then
		echo "${status}  -> ${nc}user $username already exists, skipping"
	else
		useradd -m $username
		echo "${interact}==> ${nc}Password: "
		if [ -z $veryquiet ]; then
			passwd $username
		else
			echo "${attention}  -> ${nc}setting user \"${gold}$username${nc}\" password to \"${gold}password${nc}\""
			echo "password" | passwd $username --stdin
			sleep 2
		fi;
	fi;
fi;

echo "${status}  -> ${nc}adding to sudoers"
sed -i "s/root ALL=(ALL) ALL/root ALL=(ALL) ALL\n$username ALL=(ALL) ALL/" /etc/sudoers

echo "${status}  -> ${nc}installing grub as bootloader"
grub-install --target=i386-pc $installdisk
echo "${status}  -> ${nc}removing quiet from grub linux parameters"
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\"/" /etc/default/grub
#cat /etc/default/grub | sed "s/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\"/" > /etc/default/grub
echo "${status}  -> ${nc}making grub config"
grub-mkconfig -o /boot/grub/grub.cfg

echo "${status}  -> ${nc}chroot setup done"

echo "${status}  -> ${nc}running scripts"
source scripts/main

echo "${status}  -> ${nc}exiting"
