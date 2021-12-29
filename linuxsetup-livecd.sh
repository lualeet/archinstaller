#!/bin/sh
set -e

if ! [ -z $1 ] && [ $1 = "-q" ]; then
	quiet=true
	if [ -z $2 ]; then
		if [ -z $3 ]; then
			echo " -> if running in quiet mode, a path to a disk device and a root password are required."
			exit 1
		fi;
		echo " -> if running in quiet mode, a path to disk device is required."
		exit 1
	fi;
	if [ -z $3 ]; then
		echo " -> if running in quiet mode, a root password is also required."
	fi;
	installdisk=$2
	rootpass=$3
fi;

qread() {
	if ! [ -z $quiet ]; then
		echo $2
		return $2
	fi;
	read $1
}

stat ./linuxsetup-chroot.sh 2>/dev/null >/dev/null || sh -c "echo \" -> linuxsetup-chroot.sh has not been found in current dir, you'll have to copy it manually\"; sleep 2; echo \" -> proceeding anyways\""

err_alreadymounted_umountfail() {
	echo " -> failed to umount"
	exit 1
}
err_alreadymounted() {
	printf " => /mnt is already mounted, umount and continue? "
	qread unmount y
	if [ $unmount = "y" ]; then
		umount /mnt || err_alreadymounted-umountfail
	else
		echo " -> idk what to do then"
		exit 1
	fi;
}
if mountpoint -q /mnt; then
	err_alreadymounted
fi;

if ! stat /etc/pacman.conf -c ""; then
	echo " -> making pacman.conf backup at /etc/pacman.conf.backup"
	cp /etc/pacman.conf /etc/pacman.conf.backup
else
	echo " -> /etc/pacman.conf.backup already exists, not making backup"
fi;
echo " -> enabling pacman Color and ParallelDownloads"
sed -i "s/#Color/Color/" /etc/pacman.conf
sed -i "s/#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf
if ! [ -s /etc/pacman.conf ]; then
	echo " -> /etc/pacman.conf is now empty. why"
	exit 1
fi;
#cat /etc/pacman.conf | sed "s/#Color/Color/" | sed "s/#ParallelD/ParallelD/" > /etc/pacman.conf

err_updatefailed() {
	printf " => Failed system update, continue anyways? "
	qread keepgoing y;
	if [ $keepgoing = "y" ]; then
		echo " -> proceeding"
	else
		exit 1
	fi;
}
echo " -> updating system"
pacman -Syu --noconfirm || err_updatefailed

fdisk -l | grep -i /dev/sd
printf " => Choose disk to partition (/dev/sdX): "
qread installdisk $installdisk
installdisk2="$installdisk""2"

if ! stat $installdisk -c ""; then
	echo " -> $installdisk is not a valid file"
fi;

fdisk -l $installdisk

printf " => Partition disk \"$installdisk\"? "
qread tocontinue y
if [ $tocontinue = "y" ]; then
	echo " -> proceeding"
else
	echo " -> quitting"
	exit 0
fi;

printf " => Partition automatically with parted (y) or manually with fdisk (n)? "
qread useparted y
if [ $useparted = "y" ]; then
	echo " -> using parted"
	parted $installdisk ---pretend-input-tty <<EOF
mktable gpt
Yes
mkpart primary 1MiB 3MiB
toggle 1 bios
mkpart primary 3MiB 100%
print
quit
EOF
	echo " -> done"
elif [ $useparted = "n" ]; then
	echo " -> using fdisk"
	fdisk $installdisk
else
	echo " -> invalid response, expected (y/n)"
	exit 1
fi;

printf " => Format $installdisk2 with ext4? "
qread ext4 y
if [ $ext4 = "y" ]; then
	mkfs.ext4 -F $installdisk2
elif [ $ext4 = "n" ]; then
	echo " -> ^D or exit when you're done formatting"
	zsh || bash || sh
else
	echo " -> invalid response, expected (y/n)"
	exit 1
fi;

if ! mountpoint -q /mnt; then
	echo " -> mounting $installdisk2 to /mnt/"
	mount $installdisk2 /mnt
else
	echo " -> /mnt already mounted, proceeding"
fi;

pacstrap /mnt base base-devel linux linux-firmware
printf " => Install extra terminal software? (neovim, tmux) "
qread extras y
if [ $extras = "y" ]; then
	pacstrap /mnt neovim tmux
fi;

printf " => Install NetworkManager? "
qread networkmanager y
if [ $networkmanager = "y" ]; then
	pacstrap /mnt networkmanager
fi;

prompt_installcustom() {
	printf " => Install custom software? (space separated list of packages, empty for none) "
	qread customs
	if ! [ -z $customs ]; then
		pacstrap /mnt $customs || prompt_installcustom
	fi;
}
prompt_installcustom

echo " -> genfstab -U /mnt >> /mnt/etc/fstab"
genfstab -U /mnt >> /mnt/etc/fstab

cat /mnt/etc/fstab
printf " => Does this fstab file seem correct? "
qread fstabhealthy y
if [ $fstabhealthy = "n" ]; then
	pacman -S neovim --needed --noconfirm
	nvim /mnt/etc/fstab
fi;

echo " -> preparing timezone to Europe/Vilnius (Lithuania)"
ln -sf /mnt/usr/share/zoneinfo/Europe/Vilnius /mnt/etc/localtime

echo " -> preparing locale to en_US.UTF-8"
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

printf " => Your hostname: "
qread hostname hostname
if [ -z $hostname ]; then
	hostname=hostname
fi;
echo $hostname > /mnt/etc/hostname

echo " => Root password:"
if ! [ -z $quiet ]; then
	echo " -> in quiet mode, setting password to $rootpass"
	echo $rootpass | passwd --stdin
else
	passwd
fi;

echo " -> installing grub"
pacstrap /mnt grub --needed --noconfirm

echo " -> copying chroot setup script"
stat ./linuxsetup-chroot.sh 2>/dev/null >/dev/null || echo " -> linuxsetup-chroot.sh was not found in current dir, please locate it and copy it to /mnt/"
cp ./linuxsetup-chroot.sh /mnt/linuxsetup-chroot.sh || true
if [ -f /mnt/linuxsetup-chroot.sh ]; then
	sanitizedinstalldisk=$(echo $installdisk | sed "s:/:\\\/:g")
	sed -i "s/installdisk=placeholder/installdisk=$sanitizedinstalldisk/" /mnt/linuxsetup-chroot.sh
	#cat /mnt/linuxsetup-chroot.sh | sed "s/installdisk=placeholder/installdisk="$installdisk"/" > /mnt/linuxsetup-chroot.sh
fi;

echo " -> wait for the partition to unmount"
umount $installdisk2

mount $installdisk2 /mnt

echo " -> livecd setup done, run"
echo "   arch-chroot /mnt"
echo "   /linuxsetup-chroot.sh"
echo " -> exiting"

