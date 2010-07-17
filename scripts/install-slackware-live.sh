#!/bin/sh
PATH=/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/local/bin


if [ -z "$DISPLAY" ]
then echo "GUI only; see 'build-slackware-live.sh' for text mode."
	exit 1
fi

XDIALOG=`which Xdialog 2>/dev/null || which xdialog 2>/dev/null`
if [ -z "$XDIALOG" ]; then exit 2; fi

case `echo $LANG | cut -c-2` in
"fr") MSGUNIT="Kio" 
	MSGXDIALOGTITLE="Installation de SLTITLE"
	MSGXDIALOGPARTITION="Choisir l'action (toutes les données de la destination seront détruites):"
	MSGSYSINSTALL="Installation sur"
	MSGLIVEINSTALL="Copie du système Vif sur"
	MSGXDIALOGERRORNODESTINATION="Erreur: aucune destination disponible pour l'installation."
	;;
*) MSGUNIT="KiB" 
	MSGXDIALOGTITLE="SLTITLE installation"
	MSGXDIALOGPARTITION="Choose action (all data on destination will be destroyed):"
	MSGSYSINSTALL="Installation on"
	MSGLIVEINSTALL="Live system copy on"
	MSGXDIALOGERRORNODESTINATION="Error: no available destination for installation."
	;;
esac


listsysinstallparts=""
listpart=`fdisk -l | sed -n '/ 83 /p' | sed 's/[*+]//g' | sed 's/  */:/g' | cut -f1,4 -d':' `
for partinfo in $listpart; do
	partdev=`echo $partinfo | cut -f1 -d:`
	partsize=`echo $partinfo | cut -f2 -d:`
	device=`echo $partdev | cut -c6-8`
	if [ `cat /sys/block/$device/removable` == 0 ]
	then listsysinstallparts+="s$partdev '$MSGSYSINSTALL $partdev ($partsize $MSGUNIT)' "
	fi
done

listliveinstallparts=""
listpart=`fdisk -l | sed -n '/ 83 /p' | sed 's/[*+]//g' | sed 's/  */:/g' | cut -f1,4 -d':' `
for partinfo in $listpart; do
	partdev=`echo $partinfo | cut -f1 -d:`
	partsize=`echo $partinfo | cut -f2 -d:`
	device=`echo $partdev | cut -c6-8`
	if [ `cat /sys/block/$device/removable` == 1 ]
	then listliveinstallparts+="l$partdev '$MSGLIVEINSTALL $partdev ($partsize $MSGUNIT)' "
	fi
done

listliveinstalldisks=""
for partdev in `ls -d /sys/block/sd?`; do
	device=`basename $partdev`
	partdev="/dev/$device"
	partsize=`cat /sys/block/$device/size`
	let partsize/=2
	if [ $partsize != 0 ] && [ `cat /sys/block/$device/removable` == 1 ]
	then listliveinstalldisks+="l$partdev '$MSGLIVEINSTALL $partdev ($partsize $MSGUNIT)' "
	fi
done

if [ -z "$listsysinstallparts" ] && [ -z "$listliveinstalldisks" ]; then 
	$XDIALOG --title "$MSGXDIALOGTITLE" --msgbox "$MSGXDIALOGERRORNODESTINATION" 0 0
	exit 3
fi

cmd="$XDIALOG --no-tags --stdout --title \"$MSGXDIALOGTITLE\" --menubox \"$MSGXDIALOGPARTITION\" 20 100 0 $listsysinstallparts $listliveinstallparts $listliveinstalldisks"
installtypeandlocation=`eval $cmd` || exit 2
location=`echo $installtypeandlocation | cut -c2-`
installtype=`echo $installtypeandlocation | cut -c1`


LOGFILE="/tmp/~Xhdinstall.sh$$"
if [ "$installtype" == "s" ]
then build-slackware-live.sh --install /live/system $location >> $LOGFILE 2>&1 & pid=$!
else build-slackware-live.sh --usb /live/media $location >> $LOGFILE 2>&1 & pid=$!
fi
$XDIALOG --title "$MSGXDIALOGTITLE" --no-ok --no-cancel --tailbox $LOGFILE 25 80
if (($?)); then
	kill `pstree -p | grep "($pid)" | sed 's/[^(0-9)]//g' | sed 's/)[^(]\+(/)(/g' | sed 's/(/ /g' | sed 's/)/ /g'`
	sleep 5
	umount $location
	rmdir /mnt/install
fi
rm -f $LOGFILE
