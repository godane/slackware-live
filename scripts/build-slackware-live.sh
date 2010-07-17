#!/bin/sh

SLTITLE="Slackware 13.1 Live"


function create_menu() {
	menufile=$1
	
	cat > $menufile << EOF
default menu.c32
prompt 0
menu title $SLTITLE
timeout 100

label fr
	menu label FR
	menu default
	kernel /boot/vmlinuz
	append initrd=/boot/initrd.gz vga=791 lang=fr_FR keymap=fr

label us
	menu label US
	kernel /boot/vmlinuz
	append initrd=/boot/initrd.gz vga=791 lang=en_US keymap=us

EOF
}


function compress_system() {
	rootdirectory=$1
	livedirectory=$2
	
	#not done by startup scripts: FIX ?
	cat > $rootdirectory/usr/sbin/slackware-postinstall.sh << EOF
if [ -x /usr/bin/update-desktop-database ] && [ -d /usr/share/applications ]; then
	update-desktop-database /usr/share/applications/
fi
if [ -x /usr/bin/mkfontdir ] && [ -d /usr/share/fonts ]; then
	mkfontdir /usr/share/fonts/*
fi
if [ -x /usr/bin/mkfontscale ] && [ -d /usr/share/fonts ]; then
	mkfontscale /usr/share/fonts/*
fi
if [ -x /usr/bin/update-pango-querymodules ]; then
	update-pango-querymodules
fi
EOF
	chmod +x $rootdirectory/usr/sbin/slackware-postinstall.sh
	chroot $rootdirectory slackware-postinstall.sh
	rm -f $rootdirectory/usr/sbin/slackware-postinstall.sh
	
	cat > $rootdirectory/etc/fstab << EOF
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
tmpfs /dev/shm tmpfs defaults,mode=777 0 0
EOF
	
	mksquashfs $rootdirectory $livedirectory/boot/slackware-live.sfs -e tmp dev proc sys $livedirectory/boot/slackware-live.sfs
}


function create_initrd() {
	rootdirectory=$1
	livedirectory=$2
	
	kv=`basename $rootdirectory/lib/modules/*`
	modulelist="squashfs:fuse:loop:isofs:nls_utf8:ehci-hcd:uhci-hcd:ohci-hcd:usb-storage:vfat:nls_cp437:nls_iso8859-1"
		#remarq: scsi and sata controlers drivers have to be included in kernel, or added here
		#remarq: for Slackware huge kernel, only squashfs and fuse modules are needed
	mount --bind /proc $rootdirectory/proc
	chroot $rootdirectory mkinitrd -c -o /tmp/initrd.gz -s /tmp/initrd-tree -k $kv -m $modulelist
	umount $rootdirectory/proc
	rm -f $rootdirectory/tmp/initrd.gz
	rm -f $rootdirectory/tmp/initrd-tree/{initrd-name,keymap,luksdev,resumedev,rootfs,rootdev,wait-for-root}
	
	initscriptbasepath=$(dirname $(dirname $(which build-slackware-live.sh)))
	cp $initscriptbasepath/lib/slackware-live/init/init $rootdirectory/tmp/initrd-tree/init
	chmod +x $rootdirectory/tmp/initrd-tree/init
	
	cp `which unionfs` $rootdirectory/tmp/initrd-tree/bin/
	cp $initscriptbasepath/lib/slackware-live/init/rc.? $rootdirectory/tmp/initrd-tree/
	
	find $rootdirectory/tmp/initrd-tree/lib/modules/ -name "*.ko" | xargs strip --strip-unneeded
	cd $rootdirectory/tmp/initrd-tree
	find . | cpio -o -H newc | gzip -9c > $livedirectory/boot/initrd.gz
	cd - >/dev/null
	
	rm -rf $rootdirectory/tmp/initrd-tree
}


function create_iso() {
	livedirectory=$1
	imagedirectory=$2
	
	if [ -d "$livedirectory" ] && [ -d "$imagedirectory" ]
	then mkdir $livedirectory/boot/isolinux
		syslinuxdir=$(dirname $(grep isolinux.bin /var/log/packages/syslinux*))
		cp /$syslinuxdir/isolinux.bin $livedirectory/boot/isolinux/
		cp /$syslinuxdir/menu.c32 /mnt/install/boot/extlinux/
		#~ cp /$syslinuxdir/vesamenu.c32 $livedirectory/boot/extlinux/
		create_menu $livedirectory/boot/isolinux/isolinux.cfg
		
		mkisofs -l -r -V "$SLTITLE" -b boot/isolinux/isolinux.bin -hide boot.catalog -hide-joliet boot.catalog -no-emul-boot -boot-load-size 4 -boot-info-table -o $imagedirectory/slackware-live.iso $livedirectory
		
		rm -rf $livedirectory/boot/isolinux
	fi
}


function install_usb() {
	livedirectory=$1
	installmedia=$2
	
	installdevice=`echo $installmedia | cut -c6-8`
	mediasize=`cat /sys/block/$installdevice/size`
	installdevice="/dev/$installdevice"
	
	if [ "$installdevice" == "$installmedia" ]
	then #partition and format media
		if (( $mediasize < 4194304 )) #2GB
		then heads=128; sectors=32
		else heads=255; sectors=63
		fi
		mkdiskimage $installdevice 1 $heads $sectors
		dd if=/dev/zero of=$installdevice bs=1 seek=446 count=64
		echo -e ',0\n,0\n,0\n,,83,*' | sfdisk $installdevice
		installmedia="$installdevice""4"
		
		mke2fs $installmedia
	fi
	
	mkdir /mnt/install
	mount $installmedia /mnt/install || { mke2fs $installmedia; mount $installmedia /mnt/install; }
	mkdir -p /mnt/install/boot/extlinux
	extlinux -i /mnt/install/boot/extlinux
	
	syslinuxdir=$(dirname $(grep isolinux.bin /var/log/packages/syslinux*))
	cat /$syslinuxdir/mbr.bin > $installdevice
	cp /$syslinuxdir/menu.c32 /mnt/install/boot/extlinux/
	#~ cp /$syslinuxdir/vesamenu.c32 $livedirectory/boot/extlinux/
	create_menu /mnt/install/boot/extlinux/extlinux.conf
	
	cp $livedirectory/boot/slackware-live.sfs /mnt/install/boot/
	
	cp $livedirectory/boot/vmlinuz /mnt/install/boot/
	cp $livedirectory/boot/initrd.gz /mnt/install/boot/
	
	umount /mnt/install
	rmdir /mnt/install
}


function build_live() {
	rootdirectory=$1
	livedirectory=$2
	
	if [ -d "$rootdirectory" ] && [ ! -z "$livedirectory" ]
	then rm -rf $livedirectory
		mkdir -p $livedirectory/boot
		compress_system $rootdirectory $livedirectory
		create_initrd $rootdirectory $livedirectory
		cp $rootdirectory/boot/vmlinuz $livedirectory/boot/
	fi
}


function install_system() {
	rootdirectory=$1
	systempart=$2

	if [ -b "$systempart" ] && [ -d "$rootdirectory" ]
	then mkfs.ext4 $systempart

		mkdir -p /mnt/install
		mount $systempart /mnt/install

		for directory in bin boot etc home lib lib64 media mnt opt root sbin srv usr var; do
			cp -dpr $rootdirectory/$directory /mnt/install
		done
		mkdir /mnt/install/{dev,proc,sys,tmp}
		cp -dpr $rootdirectory/lib/udev/devices/* /mnt/install/dev/

		umount /mnt/install #syncing
		mount $systempart /mnt/install

		cat > /mnt/install/etc/fstab << EOF
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
tmpfs /dev/shm tmpfs defaults,mode=777 0 0
$systempart / ext4 defaults 1 1
EOF
		echo "$systempart / ext4 defaults 1 1" > /mnt/install/etc/mtab
		
		#lilo begin
		installdevice=`echo $systempart | cut -c1-8`
		cp -dpr $installdevice /mnt/install/dev/
		cp -dpr $systempart /mnt/install/dev/
		cat > /mnt/install/etc/lilo.conf << EOF
boot = $installdevice

bitmap = /boot/slack.bmp
bmp-colors = 255,0,255,0,255,0
bmp-table = 60,6,1,16
bmp-timer = 65,27,0,255
vga = 791
lba32

prompt
timeout = 150

image = /boot/vmlinuz
	root = $systempart
	label = Linux
	read-only
	
EOF

		windowspartition=`fdisk -l $installdevice| grep "^$installdevice.*\*" | cut -f1 -d' '`
		if [ ! -z "$windowspartition" ]
		then cp -dpr $windowspartition /mnt/install/dev/ 
			cat >> /mnt/install/etc/lilo.conf << EOF
other = $windowspartition
	label = Windows
	table = $installdevice
EOF
		fi
		
		chroot /mnt/install mount /proc
		chroot /mnt/install lilo
		chroot /mnt/install umount /proc
		#lilo end
		
		cp -f /etc/rc.d/rc.keymap /mnt/install/etc/rc.d/
		cp -f /etc/profile.d/lang.sh /mnt/install/etc/profile.d/
		if [ -f /etc/hal/fdi/policy/10osvendor/10-keymap.fdi ]; then
			cp -f /etc/hal/fdi/policy/10osvendor/10-keymap.fdi /mnt/install/etc/hal/fdi/policy/10osvendor/
		fi
		if [ -f /etc/X11/xorg.conf ]; then
			cp -f /etc/X11/xorg.conf /mnt/install/etc/X11/ #in case it has been changed
		fi

		umount /mnt/install
		rmdir /mnt/install
	fi
}


function add_packages() {
	packagesdirectory=$1
	rootdirectory=$2
	packageslistfile=$3

	if [ -d "$packagesdirectory/extra" ] && [ ! -z "$rootdirectory" ] && [ -f "$packageslistfile" ]
	then mkdir -p $rootdirectory
		for package in `cat "$packageslistfile" | sed 's/ *#.*//'`
		do 	installpkg -root $rootdirectory $packagesdirectory/$package*.t?z || break
		done
	fi
}


case $1 in
"--live") build_live $2 $3 ;;
"--usb") install_usb $2 $3 ;;
"--iso") create_iso $2 $3 ;;
"--install") install_system $2 $3;;
"--add") add_packages $2 $3 $4 ;;
*)	
	echo "===== Building system from packages: ====="
	echo -e "usage: `basename $0` --add packages_dir system_root_dir pkg_list_file"
	echo "example: `basename $0` --add /mnt/cdrom /mnt/system packages-list.txt"
	echo "----------------------------------------
\`packages-list.txt' example:
----------------------------------------
slackware/a/*
slackware/n/dhcpcd
slackware/n/iputils
slackware/n/net-tools
slackware/n/network-scripts
----------------------------------------"
	echo "remarq - adding packages could also be done by a command like:"
	echo -e "\tinstallpkg -root /mnt/system /mnt/cdrom/slackware/a/*.t?z"
	echo ""
	
	echo "===== Convert installed system to live system (compression): ====="
	echo "usage: `basename $0` --live system_root_directory live_system_directory"
	echo "example: `basename $0` --live /mnt/system /tmp/live"
	echo ""
	
	echo "===== Copy live system on USB device: ====="
	echo "usage: `basename $0` --usb live_system_directory device"
	echo "example - after \``basename $0` --live /mnt/system /tmp/live':"
	echo -e "\t`basename $0` --usb /tmp/live /dev/sdx1"
	echo "example - from a running live system:"
	echo -e "\t`basename $0` --usb /live/livemedia /dev/sdx1"
	echo ""
	
	echo "===== Create a live CD/DVD ISO from live system: ====="
	echo "usage: `basename $0` --iso live_system_directory iso_destination_directory"
	echo "example - after \``basename $0` --live /mnt/system /tmp/live':"
	echo -e "\t`basename $0` --iso /tmp/live /tmp"
	echo ""
	
	echo "===== Install a system: ====="
	echo "usage: `basename $0` --install system_root_directory partition_device"
	echo "example - from a running live system (typically):"
	echo -e "\t`basename $0` --install /live/system /dev/sdx2"
	echo "example - system cloning:"
	echo -e "\t`basename $0` --install /mnt/system /dev/sdx2"
esac
