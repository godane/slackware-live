#!/bin/sh


function create_menu() {
	menufile=$1
	shift; appends=$*
	
	cat > $menufile << EOF
default menu.c32
#ui menu.c32 ~
#default vesamenu.c32
prompt 0
menu title $SLTITLE
timeout 100

label arabic # العربية tz=GMT+3
	menu label Arabic
	kernel /boot/vmlinuz
	append initrd=/boot/initrd.gz vga=791 locale=ar_EG.UTF-8 keymap=us $appends

#TODO: Bengali

label chinese # 官话 tz=GMT+8
	menu label Chinese
	kernel /boot/vmlinuz
	append initrd=/boot/initrd.gz vga=791 locale=zh_cn.UTF-8 keymap=us $appends

label danish # Dansk tz=GMT+1
	menu label Danish
	kernel /boot/vmlinuz
	append initrd=/boot/initrd.gz vga=791 locale=da_DK.UTF-8 keymap=dk $appends

label english # tz=GMT-5
	menu label English
	kernel /boot/vmlinuz
	append initrd=/boot/initrd.gz vga=791 locale=en_US.UTF-8 keymap=us $appends

label french # Français tz=GMT+1
	menu label French
	menu default
	kernel /boot/vmlinuz
	append initrd=/boot/initrd.gz vga=791 locale=fr_FR.UTF-8 keymap=fr $appends
	
label german # Deutsch tz=GMT+1
	menu label German
	kernel /boot/vmlinuz
	append initrd=/boot/initrd.gz vga=791 locale=de_DE.UTF-8 keymap=de $appends
	
#TODO: Hindi

label japan # 日本語 tz=GMT+9
	menu label Japan
	kernel /boot/vmlinuz
	append initrd=/boot/initrd.gz vga=791 locale=ja_JP.UTF-8 keymap=jp106 $appends

label portuguese # Português tz=GMT
	menu label Portuguese
	kernel /boot/vmlinuz
	append initrd=/boot/initrd.gz vga=791 locale=pt_PT.UTF-8 keymap=pt $appends
	
label russian # русский язык tz=GMT+3
	menu label Russian
	kernel /boot/vmlinuz
	append initrd=/boot/initrd.gz vga=791 locale=ru_RU.UTF-8 keymap=ru $appends
	
label spanish # Español tz=GMT+1
	menu label Spanish
	kernel /boot/vmlinuz
	append initrd=/boot/initrd.gz vga=791 locale=es_ES.UTF-8 keymap=es $appends

EOF
}


function gui_prep() {
	rwdirectory=$1
	shift
	for rodirectory in $*; do rodirectories="$rodirectories:$rodirectory=ro"; done
	
	mkdir /mnt/union
	mount -t aufs -o br=$rwdirectory=rw$rodirectories none /mnt/union 2>/dev/null ||
	unionfs -o allow_other,suid,dev,use_ino,cow,max_files=524288 $rwdirectory=rw$rodirectories /mnt/union

	if [ -x /mnt/union/bin/sh ]; then
		#not done by stock Slackware startup scripts, but by pkgtool during install:
		cat > /mnt/union/auto-pkgtool.sh << EOF
if [ -x /usr/bin/update-desktop-database ] && [ -d /usr/share/applications ]; then
	update-desktop-database /usr/share/applications/
fi
if [ -x /usr/bin/mkfontdir ] && [ -d /usr/share/fonts ]; then
	mkfontdir /usr/share/fonts/*
fi
if [ -x /usr/bin/mkfontscale ] && [ -d /usr/share/fonts ]; then
	mkfontscale /usr/share/fonts/*
fi
EOF

		#done by stock Slackware startup scripts, but not by LiNomad ones (for speed improvement)
		cat > /mnt/union/auto-pkgtool.sh << EOF
if [ -x /usr/bin/fc-cache ]; then
	fc-cache -f
fi

if [ -x /usr/bin/gtk-update-icon-cache ] && [ -d /usr/share/icons ]; then
	for theme in /usr/share/icons/*; do gtk-update-icon-cache -t -f \$theme; done
	rm -f /usr/share/icons/icon-theme.cache
fi
if [ -x /usr/bin/update-mime-database ] && [ -d /usr/share/mime ]; then
	update-mime-database /usr/share/mime
fi

if [ -x /usr/bin/update-gtk-immodules ]; then
	update-gtk-immodules #--verbose
fi
if [ -x /usr/bin/update-gdk-pixbuf-loaders ]; then
	update-gdk-pixbuf-loaders #--verbose
fi
if [ -x /usr/bin/update-pango-querymodules ]; then
	update-pango-querymodules #--verbose
fi
EOF
		chmod +x /mnt/union/auto-pkgtool.sh
		chroot /mnt/union /auto-pkgtool.sh
		rm -f /mnt/union/auto-pkgtool.sh
	fi
	
	umount /mnt/union
	rmdir /mnt/union
}


function add_module() {
	rootdirectory=$1
	livedirectory=$2
	modulename=$3
	option=$4
	
	gui_prep $rootdirectory
	if [ "$option" == "-optional" ]
	then modulepath=$livedirectory/boot/optional/$modulename
	else modulepath=$livedirectory/boot/modules/$modulename
	fi
	mkdir -p `dirname $modulepath`
	rm -f $modulepath
	mksquashfs $rootdirectory $modulepath -e tmp dev proc sys $livedirectory
}


function create_initrd() {
	rootdirectory=$1
	livedirectory=$2
	modulelist=$3
	option=$4
	
	kv=`basename $rootdirectory/lib/modules/*`
	mount --bind /proc $rootdirectory/proc
	chroot $rootdirectory mkinitrd -c -o /tmp/initrd.gz -s /tmp/initrd-tree -k $kv -m $modulelist
	umount $rootdirectory/proc
	rm -f $rootdirectory/tmp/initrd.gz
	rm -f $rootdirectory/tmp/initrd-tree/{initrd-name,keymap,luksdev,resumedev,rootfs,rootdev,wait-for-root}
	
	initscriptbasepath=$(dirname $(dirname $0))
	cp $initscriptbasepath/share/slackware-live/init $rootdirectory/tmp/initrd-tree/
	chmod +x $rootdirectory/tmp/initrd-tree/init
	
	#put in initrd everything needed to install live system
	mkdir $rootdirectory/tmp/initrd-tree/slackware-live
	cp $0 $rootdirectory/tmp/initrd-tree/slackware-live/
	if [ "$option" != "-nosli" ]; then
		cp $initscriptbasepath/share/slackware-live/install-slackware-live.* $rootdirectory/tmp/initrd-tree/slackware-live/
	fi
	
	#~ #put in initrd everything needed to load optional modules
	#~ cp $initscriptbasepath/share/slackware-live/manage-optional-modules.sh $rootdirectory/tmp/initrd-tree/slackware-live/
	#~ if [ "$option" != "-nosli" ]; then
		#~ cp $initscriptbasepath/share/slackware-live/load-optional-modules.* $rootdirectory/tmp/initrd-tree/slackware-live/
	#~ fi

	if [ "$option" == "-linomad" ]; then #if LiNomad startup is requested
		cp $initscriptbasepath/share/slackware-live/rc.linomad-* $rootdirectory/tmp/initrd-tree/slackware-live/
		cp $initscriptbasepath/share/slackware-live/inittab.linomad $rootdirectory/tmp/initrd-tree/slackware-live/
		cp $initscriptbasepath/share/slackware-live/autologin $rootdirectory/tmp/initrd-tree/slackware-live/
	fi
	
	cp `which unionfs` $rootdirectory/tmp/initrd-tree/bin/
	ldd `which unionfs` | sed 's/[^\/]*\(\/[^ ]*\) .*/\1/' | sed -n /^\\//p | while read lib; do
		cp $lib $rootdirectory/tmp/initrd-tree/lib/ #shared libs needed for unionfs
	done
	
	echo "$SLTITLE" > $rootdirectory/tmp/initrd-tree/SLTITLE #for initrd to setup install-slackware-live desktop file
	
	find $rootdirectory/tmp/initrd-tree/lib/modules/ -name "*.ko" | xargs strip --strip-unneeded
	cd $rootdirectory/tmp/initrd-tree
	rm -f $livedirectory/boot/initrd.gz
	find . | cpio -o -H newc | gzip -9c > $livedirectory/boot/initrd.gz
	cd - >/dev/null
	
	rm -rf $rootdirectory/tmp/initrd-tree
}


function create_iso() {
	livedirectory=$1
	imagefilename=$2
	option=$3
	
	mkdir $livedirectory/boot/isolinux
	syslinuxdir=$(dirname $(grep isolinux.bin /var/log/packages/syslinux*))
	cp /$syslinuxdir/isolinux.bin $livedirectory/boot/isolinux/
	cp /$syslinuxdir/menu.c32 $livedirectory/boot/isolinux/
	#~ cp /$syslinuxdir/vesamenu.c32 $livedirectory/boot/isolinux/
	if [ "$option" == "-linomad" ]
	then create_menu $livedirectory/boot/isolinux/isolinux.cfg gui=auto #gui=auto|no|yes
	else create_menu $livedirectory/boot/isolinux/isolinux.cfg
	fi
	
	mkisofs -l -r -V "$SLTITLE" -b boot/isolinux/isolinux.bin -hide boot.catalog -hide-joliet boot.catalog -no-emul-boot -boot-load-size 4 -boot-info-table -o $imagefilename $livedirectory
	
	rm -rf $livedirectory/boot/isolinux
}


function install_usb() {
	livedirectory=$1
	installmedia=$2
	option=$3
	
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
	echo -n "cp -r $livedirectory/boot/modules /mnt/install/boot/ ..."
	cp -r $livedirectory/boot/modules /mnt/install/boot/
	echo ""
	echo -n "cp -r $livedirectory/boot/optional /mnt/install/boot/ ..."
	cp -r $livedirectory/boot/optional /mnt/install/boot/
	echo ""
	
	cp $livedirectory/boot/vmlinuz /mnt/install/boot/
	cp $livedirectory/boot/initrd.gz /mnt/install/boot/
	
	if [ "$option" == "-linomad" ] || [ -f /etc/rc.d/rc.linomad-boot ]
	then create_menu /mnt/install/boot/extlinux/extlinux.conf usbhome=yes gui=auto #usbhome=yes|no
	else create_menu /mnt/install/boot/extlinux/extlinux.conf
	fi
	
	umount /mnt/install
	rmdir /mnt/install
	echo "Live system copy completed."
}


function init_live() {
	rootdirectory=$1
	livedirectory=$2
	option=$3
	
	mkdir -p $livedirectory/boot/modules
	mkdir -p $livedirectory/boot/optional
	create_initrd $rootdirectory $livedirectory $SLMODLIST $option
	cp -f $rootdirectory/boot/vmlinuz $livedirectory/boot/
}


function install_system() {
	rootdirectory=$1
	systempart=$2
	loadersetup=$3

	SYSINSTALLFS="ext4"
	mkfs.$SYSINSTALLFS $systempart

	mkdir -p /mnt/install
	mount $systempart /mnt/install

	for directory in $rootdirectory/*; do
		echo -n "cp -dpr $directory /mnt/install/ ..."
		cp -dpr $directory /mnt/install/
		echo ""
	done
	
	mkdir -p /mnt/install/{dev,proc,sys,tmp} #-p shouldn't be needed
	cp -dpr $rootdirectory/lib/udev/devices/* /mnt/install/dev/

	umount /mnt/install #syncing
	mount $systempart /mnt/install

	cat > /mnt/install/etc/fstab << EOF
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
tmpfs /dev/shm tmpfs defaults,mode=777 0 0
$systempart / $SYSINSTALLFS defaults 1 1
EOF
	echo "$systempart / $SYSINSTALLFS defaults 1 1" > /mnt/install/etc/mtab
	
	#initrd begin
	if [ ! -f /mnt/install/boot/initrd.gz ]; then
		kv=`basename /mnt/install/lib/modules/*`
		if lsmod | grep -q $SYSINSTALLFS; then
			modulelist="$SYSINSTALLFS"
		fi
		for module in `lsmod | sed 1d | cut -f1 -d' '`; do 
			modulebis=`echo $module | sed 's/_/-/g'` #'_' -> '-'
			if [ -f /lib/modules/$kv/kernel/drivers/ata/$module.ko ] || [ -f /lib/modules/$kv/kernel/drivers/scsi/$module.ko ]; then
				modulelist="$module:$modulelist"
			fi
			if [ "$module" != "$modulebis" ]; then
				if [ -f /lib/modules/$kv/kernel/drivers/ata/$modulebis.ko ] || [ -f /lib/modules/$kv/kernel/drivers/scsi/$modulebis.ko ]; then
					modulelist="$modulebis:$modulelist"
				fi
			fi
		done
		modulelist=`echo $modulelist | sed 's/:$//'`
		if [ ! -z "$modulelist" ]; then
			chroot /mnt/install mount /proc
			chroot /mnt/install mkinitrd -c -f $SYSINSTALLFS -r $systempart -k $kv -m $modulelist
			chroot /mnt/install umount /proc
		fi
	fi
	#initrd end
	
	#lilo begin
	if [ "$loadersetup" == "-auto" ]; then
		installdevice=`echo $systempart | cut -c1-8`
		cp -dpr /dev/sd* /mnt/install/dev/ #create disk nodes needed for LiLo
		echo "boot = $installdevice" > /mnt/install/etc/lilo.conf
		if [ -f /mnt/install/boot/slack.bmp ]; then
			cat >> /mnt/install/etc/lilo.conf << EOF

bitmap = /boot/slack.bmp
bmp-colors = 255,0,255,0,255,0
bmp-table = 60,6,1,16
bmp-timer = 65,27,0,255

EOF
		fi
		cat >> /mnt/install/etc/lilo.conf << EOF
vga = 791
lba32

prompt
timeout = 150

image = /boot/vmlinuz
root = $systempart
label = Linux
read-only
EOF
		if [ -f /mnt/install/boot/initrd.gz ]; then
			echo "initrd = /boot/initrd.gz" >> /mnt/install/etc/lilo.conf
		fi
		windowspartition=`fdisk -l $installdevice | grep "^$installdevice.*\*.*NTFS$" | cut -f1 -d' '`
		if [ ! -z "$windowspartition" ]; then
			cat >> /mnt/install/etc/lilo.conf << EOF

other = $windowspartition
label = Windows
table = $installdevice
EOF
		fi
		chroot /mnt/install mount /proc
		chroot /mnt/install lilo
		chroot /mnt/install umount /proc
	else echo -e "\nTo setup LiLo after installation, You can run the following command:\n\t`basename $0` --loadersetup $systempart\n"
	fi
	#lilo end
	
	if [ -f /etc/rc.d/rc.keymap ]; then
		cp -f /etc/rc.d/rc.keymap /mnt/install/etc/rc.d/
	fi
	cp -f /etc/profile.d/lang.sh /mnt/install/etc/profile.d/
	if [ -f /etc/hal/fdi/policy/10osvendor/10-keymap.fdi ]; then
		mkdir -p /mnt/install/etc/hal/fdi/policy/10osvendor
		cp -f /etc/hal/fdi/policy/10osvendor/10-keymap.fdi /mnt/install/etc/hal/fdi/policy/10osvendor/
	fi
	if [ -f /etc/X11/xorg.conf ]; then
		cp -f /etc/X11/xorg.conf /mnt/install/etc/X11/
	fi
	#~ if [ -f /etc/hardwareclock ]; then
		#~ cp -f /etc/hardwareclock /mnt/install/etc/
	#~ fi
	#~ cp -f /etc/localtime /mnt/install/etc/

	umount /mnt/install
	rmdir /mnt/install
	echo "System installation completed."
}


function loadersetup() {
	systempart=$1
	
	mkdir /mnt/install
	mount $systempart /mnt/install
	chroot /mnt/install mount /proc
	chroot /mnt/install liloconfig
	chroot /mnt/install umount /proc
	umount /mnt/install
	rmdir /mnt/install
}


function add_packages() {
	packagesdirectory=$1
	rootdirectory=$2
	packageslistfile=$3

	for package in `cat "$packageslistfile" | sed 's/ *#.*//' | sed /=/d`
	do 	installpkg -root $rootdirectory $packagesdirectory/$package*.t?z || break
	done
	
	IFS=$'\n'; 
	pushd $rootdirectory >/dev/null
	for action in `cat "$packageslistfile" | sed 's/^#.*//' | sed -n '/postinstall/p' | cut -f2- -d=`; do
		eval $action
	done
	popd >/dev/null
}


#~ function share_live() {
	#~ livedirectory=$1
	#~ listeniface=$2
	#~ iprange=$3
	#~ option=$4
	
	#~ #backups
	#~ if [ ! -f /etc/export.sl ]; then mv /etc/exports{,.sl}; fi
	#~ if [ ! -f /etc/dhcpd.conf.sl ]; then mv /etc/dhcpd.conf{,.sl}; fi
	
	#~ #retrieve network parameters
	#~ serverip=`ifconfig $listeniface | sed -n 2p | cut -f2 -d: | cut -f1 -d' '`
	#~ netmask=`ifconfig $listeniface | sed -n 2p | cut -f4 -d:`
	#~ gateway=`route -n | sed  -n /^0.0.0.0/p | sed s/\ \ */:/g | cut -f2 -d:`
	#~ nameserver=`cat /etc/resolv.conf | grep nameserver | sed -n 1p | cut -f2 -d' '`
	#~ if [ "$gateway" == "0.0.0.0" ]; then
		#~ gateway=$serverip
		#~ nameserver=$serverip
	#~ fi
	#~ network=`ifconfig $listeniface | sed -n 2p | cut -f3 -d: | cut -f1 -d' ' | sed s/255/0/g`
	
	#~ #setup NFS server
	#~ mkdir /export
	#~ mkdir -p /export$livedirectory
	#~ mount --bind $livedirectory /export$livedirectory
	#~ #mkdir -p /export/home
	#~ #mount --bind /home /export/home
	#~ cat > /etc/exports << EOF
#~ /export $network/$netmask(ro,no_root_squash,no_all_squash,async,no_subtree_check,fsid=0)
#~ /export$livedirectory $network/$netmask(ro,no_root_squash,no_all_squash,async,no_subtree_check)
#~ #/export/home $network/$netmask(rw,no_root_squash,no_all_squash,async,no_subtree_check) #fsid=1
#~ EOF
	#~ . /etc/rc.d/rc.nfsd start
	
	#~ #setup TFTP booting
	#~ mkdir -p /tftpboot
	#~ cp  /boot/vmlinuz /tftpboot/
	#~ syslinuxdir=$(dirname $(grep isolinux.bin /var/log/packages/syslinux*))
	#~ cp /$syslinuxdir/pxelinux.0 /tftpboot/
	#~ mkdir /tftpboot/pxelinux.cfg
	#~ if [ "$option" == "-linomad" ]
	#~ then create_menu /tftpboot/pxelinux.cfg/default gui=auto nfsroot=$serverip:/export$livedirectory
	#~ else create_menu /tftpboot/pxelinux.cfg/default nfsroot=$serverip:/export$livedirectory
	#~ fi
	#~ sed -i 's/\(timeout.*\)/\1\nipappend 1/' /tftpboot/pxelinux.cfg/default
	#~ sed -i s/^\#\ tftp/tftp/ /etc/inetd.conf
	#~ . /etc/rc.d/rc.inetd start
	
	#~ #setup DHCP server
	#~ rangeprefix=`echo $serverip | cut -f1-3 -d .` #(FIXME): only the last byte is used for network machine number
	#~ rangebegin=`echo $iprange | cut -f1 -d-`
	#~ rangeend=`echo $iprange | cut -f2 -d-`
	#~ cat > /etc/dhcpd.conf << EOF
#~ ddns-update-style none;
#~ option routers $gateway;
#~ option domain-name-servers $nameserver;

#~ subnet $network netmask $netmask {
	#~ range $rangeprefix.$rangebegin $rangeprefix.$rangeend;
	#~ filename "pxelinux.0";
	#~ next-server $serverip; #TFTP server
#~ }
#~ EOF
	#~ rm -f /var/state/dhcp/dhcpd.leases; touch /var/state/dhcp/dhcpd.leases #Needed on live system
	#~ dhcpd $listeniface
#~ }


#~ function unshare_live() {
	#~ . /etc/rc.d/rc.nfsd stop
	#~ . /etc/rc.d/rc.inetd stop
	#~ killall dhcpd
	#~ sed -i s/^tftp/\#\ tftp/ /etc/inetd.conf
	#~ rm -rf /tftpboot
	#~ #umount /export/home
	#~ livedirectorybind=`mount | grep export | cut -f3 -d' '`
	#~ if [ ! -z "livedirectorybind" ]; then umount $livedirectorybind; fi
	#~ rm -rf /export
	#~ if [ -f /etc/export.sl ]; then mv /etc/exports{.sl,}; fi
	#~ if [ -f /etc/dhcpd.conf.sl ]; then mv /etc/dhcpd.conf{.sl,}; fi
#~ }


function define_sltitle() {
	if [ -z "$SLTITLE" ]; then
		SLTITLE="Slackware 13.1 Live"
		echo "note: 'SLTITLE' unset, using: '$SLTITLE'"
		echo -e "info: this is the live-CD/DVD label, the boot menu title and the GUI \n\tinstallation program title"
		echo "to set: export SLTITLE=\"your custom title\""
	else echo "SLTITLE='$SLTITLE'"
	fi
	echo ""
}


function define_slmodlist() {
	if [ -z "$SLMODLIST" ]; then
		SLMODLIST="squashfs:fuse" #using stock Slackware huge' kernel
		echo "note: 'SLMODLIST' unset, using: '$SLMODLIST'"
		echo "info: should be set if you don't use Slackware stock huge kernel"
		echo "to set: export SLMODLIST=\"module1:module2:...\""
		echo "example: export SLMODLIST=\"squashfs:fuse:loop:isofs:nls_utf8:ehci-hcd:uhci-hcd:ohci-hcd:usb-storage\""
		#remarq: scsi and sata controlers drivers have to be included in kernel, or added here
	else echo "SLMODLIST='$SLMODLIST'"
	fi
	echo ""
}


function print_add_usage() {
	echo "===== Building system from packages ====="
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
postinstall=ln -sf ifconfig usr/bin/ifcfg
postinstall=echo \"live.slackware.org\" > etc/HOSTNAME
----------------------------------------"
	echo "remarqs:"
	echo "- adding packages could also be done by a command like:"
	echo -e "\tinstallpkg -root /mnt/system /mnt/cdrom/slackware/a/*.t?z"
	echo -e "- packages slackware-live, unionfs-fuse and squashfs-tools are recommended on\nthe live system;"
	echo "- think to create a user with the following command for exemple:"
	echo -e "\tchroot /mnt/system useradd -m -g users -G floppy,cdrom,netdev,plugdev,scanner,lp,audio,video,power -s /bin/bash liveuser"
	echo -e "\tsed -i 's/liveuser:.:/liveuser::/' /mnt/system/etc/shadow #no password"
	echo ""
}

function print_init_usage() {
	echo "===== Setup kernel and initrd ====="
	echo "usage: `basename $0` --init system_root_dir live_system_dir [-linomad|-nosli]"
	echo -e "\t(the '-linomad' option enables LiNomad startup scripts)"
	echo -e "\t(the '-nosli' option prevents the use of Slackware-Live installer)"
	echo "example: `basename $0` --init /mnt/system /tmp/live"
	echo "warning: the following drivers are needed to boot the live system:"
	echo "squashfs,fuse,loop,isofs,nls_utf8,ehci-hcd,uhci-hcd,ohci-hcd,usb-storage;"
	echo "they have to be included in kernel or initrd (if they are available as modules);"
	echo "see 'SLMODLIST' environment variable"
	echo ""
}

function print_guiprep_usage() {
	echo "===== Prepare system GUI (fonts, icons ...) ====="
	echo "usage: `basename $0` --guiprep root_dir_1(rw) root_dir_2(ro) ..."
	echo -e "\t(list needed root directories to recompose a working system)"
	echo "example: `basename $0` --guiprep /mnt/system-core /mnt/system-gui"
	echo "remarq: only needed if the system is divided into multiple directories"
	echo ""
}

function print_module_usage() {
	echo "===== Create a SquashFS module for the system ====="
	echo "usage: `basename $0` --module system_root_dir live_system_dir module_name [-optional]"
	echo -e "\t(with the '-optional' option, the module is stored in the optional directory)"
	echo "example: `basename $0` --module /mnt/system /tmp/live 0-slackware-live"
	echo -e "remarq: you can put your own modules inside 'live_system_dir/boot/modules/' or\n'live_system_dir/boot/optional/', or move them between 'modules' and 'optional'"
	echo ""
}

function print_loadersetup_usage() {
	echo "===== LiLo expert setup ====="
	echo "usage: `basename $0` --loadersetup partition_device"
	echo "example - after a system install:"
	echo -e "\t`basename $0` --loadersetup /dev/sdx2"
	echo ""
}

function print_install_usage() {
	echo "===== Install live system ====="
	echo "usage: `basename $0` --install system_root_dir partition_device [-auto|-expert]"
	echo -e "\t(the '-auto' option enables LiLo installation into the MBR)"
	echo -e "\t(with the '-expert' option LiLo is not installed - see expert setup)"
	echo "example - from a running live system (typically):"
	echo -e "\t`basename $0` --install /live/system /dev/sdx2 -auto"
	echo "example - system cloning:"
	echo -e "\t`basename $0` --install /mnt/system /dev/sdx2"
	echo ""
}

function print_usb_usage() {
	echo "===== Copy live system on USB device ====="
	echo "usage: `basename $0` --usb live_system_dir device [-linomad]"
	echo -e "\t(the '-linomad' option enables the home dir stored on USB key \n\tand GUI auto-detection for LiNomad startup scripts)"
	echo "example - after initialization and module creation:"
	echo -e "\t`basename $0` --usb /tmp/live /dev/sdx1"
	echo "example - from a running live system:"
	echo -e "\t`basename $0` --usb /live/livemedia /dev/sdx1"
	echo ""
}

function print_iso_usage() {
	echo "===== Create a live CD/DVD ISO from live system ====="
	echo "usage: `basename $0` --iso live_system_dir iso_file_name [-linomad]"
	echo -e "\t(the '-linomad' option enables GUI auto-detection for LiNomad startup scripts)"
	echo "example - after initialization and module creation:"
	echo -e "\t`basename $0` --iso /tmp/live /tmp/slackware-live.iso"
	echo ""
}

function print_usage() {
	print_add_usage
	print_init_usage
	print_guiprep_usage
	print_module_usage
	print_usb_usage
	print_iso_usage
	print_install_usage
	print_loadersetup_usage
}


if (( `id -u` != 0 )); then
	echo "Please run this script as 'root'."
	exit 1
fi


action=$1
case $action in
"--init")
	rootdirectory=$2
	livedirectory=$3
	option=$4
	if [ -d "$rootdirectory" ] && [ ! -z "$livedirectory" ]
	then define_sltitle
		define_slmodlist
		init_live $rootdirectory $livedirectory $option
	else print_init_usage
		exit 2
	fi
	;;
"--module")
	rootdirectory=$2
	livedirectory=$3
	modulename=$4
	option=$5
	if [ -d "$rootdirectory" ] && [ -d "$livedirectory" ] && [ ! -z "$modulename" ]
	then add_module $rootdirectory $livedirectory $modulename $option
	else print_module_usage
		exit 2
	fi
	;;
"--usb")
	livedirectory=$2
	installmedia=$3
	option=$4
	if [ -d "$livedirectory" ] && [ -b "$installmedia" ]
	then define_sltitle
		install_usb $livedirectory $installmedia $option
	else print_usb_usage
		exit 2
	fi
	;;
"--iso")
	livedirectory=$2
	imagefilename=$3
	option=$4
	if [ -d "$livedirectory" ] && [ -d "`dirname $imagefilename`" ] && [ ! -d "$imagefilename" ]
	then define_sltitle
		create_iso $livedirectory $imagefilename $option
	else print_iso_usage
		exit 2
	fi
	;;
"--install")
	rootdirectory=$2
	systempart=$3
	loadersetup=$4
	if [ -d "$rootdirectory" ] && [ -b "$systempart" ]
	then install_system $rootdirectory $systempart $loadersetup
	else print_install_usage
		exit 2
	fi
	;;
"--loadersetup")
	systempart=$2
	if [ -b "$systempart" ]
	then loadersetup $systempart
	else print_loadersetup_usage
		exit 2
	fi
	;;
"--add")
	packagesdirectory=$2
	rootdirectory=$3
	packageslistfile=$4
	if [ -d "$packagesdirectory" ] && [ ! -z "$rootdirectory" ] && [ -f "$packageslistfile" ]
	then add_packages $packagesdirectory $rootdirectory $packageslistfile
	else print_add_usage
		exit 2
	fi
	;;
"--guiprep")
	rwdirectory=$2
	if [ -d "$rwdirectory" ] 
	then shift; shift 
		gui_prep "$rwdirectory" $*
	else print_guiprep_usage
		exit 2
	fi
	;;
#~ "--share")
	#~ livedirectory=$2
	#~ listeniface=$3
	#~ iprange=$4
	#~ option=$5
	#~ if [ -d "$livedirectory" ] && ifconfig | grep -q "$listeniface " && [ ! -z "$iprange" ]
	#~ then define_sltitle
		#~ define_slmodlist
		#~ unshare_live
		#~ share_live $livedirectory $listeniface $iprange $option
	#~ else print_share_usage
		#~ exit 2
	#~ fi
	#~ ;;
#~ "--unshare")
	#~ unshare_live
	#~ ;;
*)	print_usage
	exit 2
	;;
esac
