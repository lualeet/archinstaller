#!/bin/sh
set -e
. /tmp/scripts/colors

if [ -z "$TMUX" ] && [ -f /usr/bin/tmux ]; then
	exec tmux new-session sh -c "sh $(pwd)/linuxsetup-livecd.sh \"$*\""
fi;

if [ -n "$1" ] && [ $1 = "-q" ]; then
	quiet=true
	if [ -z "$2" ]; then
		echo "${status}  -> ${nc}if running in quiet mode, a path to disk device is required."
		exit 1
	fi;
	installdisk=$2
fi;

if [ -n "$1" ] && [ $1 = "-qq" ]; then
	if [ -z "$2" ]; then
		if [ -z "$3" ]; then
			echo "${status}  -> ${nc}if running in quiet mode, a path to a disk device and a root password are required."
			exit 1
		fi;
		echo "${status}  -> ${nc}if running in quiet mode, a path to disk device is required."
		exit 1
	fi;
	if [ -z "$3" ]; then
		echo "${status}  -> ${nc}if running in quiet mode, a root password is also required."
		exit 1
	fi;
	quiet=true
	veryquiet=true
	installdisk=$2
	rootpass=$3
fi;

qread() {
	if [ -n "$quiet" ]; then
		echo "$2"
		eval $1="\"$2\""
		return
	fi;
	read -r "$1"
}
qqread() {
	if [ -n "$quiet" ] && [ -n "$veryquiet" ]; then
		echo "$2"
		eval $1="\"$2\""
		return
	fi;
	read -r "$1"
}

stat ./linuxsetup-chroot.sh 2>/dev/null >/dev/null || sh -c "echo \"${status}  -> ${nc}linuxsetup-chroot.sh has not been found in current dir, you'll have to copy it manually\"; sleep 2; echo \" -> proceeding anyways\""

err_alreadymounted_umountfail() {
	echo "${status}  -> ${nc}failed to umount"
	exit 1
}
err_alreadymounted() {
	printf '%s%s' "${interact}==> ${nc}" "/mnt is already mounted, umount and continue? "
	qread unmount y
	if [ "$unmount" = "y" ]; then
		umount /mnt || err_alreadymounted-umountfail
	else
		echo "${status}  -> ${nc}idk what to do then"
		exit 1
	fi;
}
if mountpoint -q /mnt; then
	err_alreadymounted
fi;

if ! stat /etc/pacman.conf -c ""; then
	echo "${status}  -> ${nc}making pacman.conf backup at /etc/pacman.conf.backup"
	cp /etc/pacman.conf /etc/pacman.conf.backup
else
	echo "${status}  -> ${nc}/etc/pacman.conf.backup already exists, not making backup"
fi;
echo "${status}  -> ${nc}enabling Color and ParallelDownloads in pacman.conf"
sed -i "s/#Color/Color/" /etc/pacman.conf
sed -i "s/#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf
if ! [ -s /etc/pacman.conf ]; then
	echo "${status}  -> ${nc}/etc/pacman.conf is now empty. why"
	exit 1
fi;
#cat /etc/pacman.conf | sed "s/#Color/Color/" | sed "s/#ParallelD/ParallelD/" > /etc/pacman.conf

err_updatefailed() {
	printf '%s%s' "${error}==> ${nc}" "Failed system update, continue anyways? "
	qread keepgoing y;
	if [ "$keepgoing" = "y" ]; then
		echo "${status}  -> ${nc}proceeding"
	else
		exit 1
	fi;
}
echo "${status}  -> ${nc}updating system"
pacman -Syu --noconfirm || err_updatefailed

fdisk -l | grep -i /dev/sd
printf '%s%s' "${interact}==> ${nc}" "Choose disk to partition (${gold}/dev/sdX${nc}): "
qread installdisk "$installdisk"
installdisk2="$installdisk""2"

if ! stat "$installdisk" -c ""; then
	echo "${status}  -> ${nc}${gold}$installdisk${nc} is not a valid file"
fi;

fdisk -l "$installdisk"

printf '%s%s' "${interact}==> ${nc}" "Partition disk \"${gold}$installdisk${nc}\"? "
qread tocontinue y
if [ "$tocontinue" = "y" ]; then
	echo "${status}  -> ${nc}proceeding"
else
	echo "${error}  -> ${nc}quitting"
	exit 0
fi;

printf '%s%s' "${interact}==> ${nc}" "Partition automatically with${green} parted (y) ${nc}or manually with fdisk (n)? "
qread useparted y
if [ "$useparted" = "y" ]; then
	echo "${status}  -> ${nc}using parted"
	parted "$installdisk" ---pretend-input-tty <<EOF
mktable gpt
Yes
mkpart primary 1MiB 3MiB
toggle 1 bios
mkpart primary 3MiB 100%
print
quit
EOF
	echo "${done}  -> ${nc}done"
elif [ $useparted = "n" ]; then
	echo "${status}  -> ${nc}using fdisk"
	fdisk "$installdisk"
else
	echo "${error}  -> ${nc}invalid response, expected (y/n)"
	exit 1
fi;

printf '%s%s' "${interact}==> ${nc}" "Format${gold} $installdisk2 ${nc}with ext4? "
qread ext4 y
if [ "$ext4" = "y" ]; then
	mkfs.ext4 -F "$installdisk2"
elif [ "$ext4" = "n" ]; then
	echo "${attention}  -> ${nc}^D or exit when you're done formatting"
	zsh || bash || sh
else
	echo "${error}  -> ${nc}invalid response, expected (y/n)"
	exit 1
fi;

if ! mountpoint -q /mnt; then
	echo "${status}  -> ${nc}mounting${gold} $installdisk2 ${nc}to /mnt/"
	mount "$installdisk2" /mnt
else
	echo "${status}  -> ${nc}/mnt already mounted, proceeding"
fi;

pacstrap /mnt base base-devel linux linux-firmware
printf '%s%s' "${interact}==> ${nc}" "Install extra terminal software? (neovim, tmux) "
qread extras y
if [ "$extras" = "y" ]; then
	pacstrap /mnt neovim tmux
fi;

printf '%s%s' "${interact}==> ${nc}" "Install NetworkManager? "
qread networkmanager y
if [ "$networkmanager" = "y" ]; then
	pacstrap /mnt networkmanager
fi;

prompt_installcustom() {
	printf '%s%s' "${interact}==> ${nc}" "Install custom software? (space separated list of packages, empty for none) "
	qread customs
	if [ -n "$customs" ]; then
		pacstrap /mnt "$customs" || prompt_installcustom
	fi;
}
prompt_installcustom

echo "${status}  -> ${nc}genfstab -U /mnt >> /mnt/etc/fstab"
genfstab -U /mnt >> /mnt/etc/fstab

cat /mnt/etc/fstab
printf '%s%s' "${interact}==> ${nc}" "Does this fstab file seem correct? "
qread fstabhealthy y
if [ "$fstabhealthy" = "n" ]; then
	pacman -S neovim --needed --noconfirm
	nvim /mnt/etc/fstab
fi;

echo "${status}  -> ${nc}preparing timezone to Europe/Vilnius (Lithuania)"
ln -sf /mnt/usr/share/zoneinfo/Europe/Vilnius /mnt/etc/localtime

echo "${status}  -> ${nc}preparing locale to en_US.UTF-8"
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

printf '%s%s' "${interact}==> ${nc}" "Your hostname: "
qqread hostname hostname
if [ -z "$hostname" ]; then
	hostname=hostname
fi;
echo $hostname > /mnt/etc/hostname

echo "${interact}==> ${nc}Root password:"
if [ -n "$veryquiet" ]; then
	echo "${attention}  -> ${nc}in very quiet mode, setting password to $rootpass"
	echo "root:$rootpass" | chpasswd -R /mnt
	sleep 1;
else
	passwd
fi;

echo "${status}  -> ${nc}installing grub"
pacstrap /mnt grub --needed --noconfirm

echo "${status}  -> ${nc}copying chroot setup script"
stat ./linuxsetup-chroot.sh 2>/dev/null >/dev/null || echo "${attention}  -> ${nc}linuxsetup-chroot.sh was not found in current dir, please locate it and copy it to /mnt/"
cp ./linuxsetup-chroot.sh /mnt/linuxsetup-chroot.sh || true
if [ -f /mnt/linuxsetup-chroot.sh ]; then
	sanitizedinstalldisk=$(echo "$installdisk" | sed "s:/:\\\/:g")
	sed -i "s/installdisk=placeholder/installdisk=$sanitizedinstalldisk/" /mnt/linuxsetup-chroot.sh
	#cat /mnt/linuxsetup-chroot.sh | sed "s/installdisk=placeholder/installdisk="$installdisk"/" > /mnt/linuxsetup-chroot.sh
fi;
echo "${status}  -> ${nc}copying config scripts"
cp -r ./scripts /mnt/

echo "${status}  -> ${nc}wait for the partition to unmount (this can take a while)"
umount "$installdisk2"

mount "$installdisk2" /mnt

echo "${status}  -> ${nc}livecd setup done"
#echo "   arch-chroot /mnt"
#echo "   /linuxsetup-chroot.sh"
#echo "${interact}==> ${nc}Press enter to exit "
#read
arch-chroot /mnt /linuxsetup-chroot.sh
