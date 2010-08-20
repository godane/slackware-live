#!/bin/bash

function print_usage() {
	#~ echo "usage: `basename $0` [--add|--remove] /path/to/module"
	echo "usage: `basename $0` --add /path/to/module"
	echo "example: `basename $0` --add /live/media/boot/optional/ati-driver" 
	exit 2
}


if (( `id -u` != 0 )); then
	echo "Please run this script as 'root'."
	exit 1
fi

action=$1
module=$2

if [ ! -f $module ]; then
	print_usage
fi

case $action in
"--add")
	modulename=`basename $module`
	if [ ! -d /live/modules/$modulename ]; then
		mkdir /live/modules/$modulename
		mount -o loop -t squashfs $module /live/modules/$modulename
		mount -o remount,add:1:/live/modules/$modulename=ro /live/union
		mount -o remount,add:1:/live/modules/$modulename=ro /live/system
	else echo "error: '/live/modules/$modulename' already exist; already loaded ?"
		exit 3
	fi
	;;
#~ "--remove")
	#~ modulename=`basename $module`
	#~ if [ -d /live/modules/$modulename ]; then
		#~ mount -o remount,del:/live/modules/$modulename=ro /live/union
		#~ mount -o remount,del:/live/modules/$modulename=ro /live/system
		#~ umount /live/modules/$modulename
		#~ rmdir /live/modules/$modulename
	#~ else echo "error: '/live/modules/$modulename' doesn't exist; not loaded ?"
		#~ exit 3
	#~ fi
	#~ ;;
*) print_usage
	;;
esac

