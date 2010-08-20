#!/bin/bash

#
# optional modules loader for Slackware-Live-Scripts
# (c) 2010 Sebastian Reisse
# Inspirated by Jean-Philippe Guillemin's "serviceconfig" for Zenwalk 
# This is free software, you can redistribute it and/or modify it 
# under the terms of the GNU General Public License (GPL), published by the Free Software Foundation; 
# either version 2 or any later version.
# See http://www.gnu.org/copyleft/gpl.htm for more details.
#




if [[ -z $DISPLAY ]]
then 
   DIALOG=dialog
else
   DIALOG=Xdialog
fi

OPTMODDIR='/live/media/boot/optional/'

if [[ -z $(ls -A $OPTMODDIR) ]]; then 
	$DIALOG --title "optional modules loader" --msgbox "No optional modules found!" 10 50
	exit 1
fi

dialogscript="${DIALOG} \
--stdout \
--title \"optional modules loader\" \
--clear \
--item-help \
--checklist \
\"Please select the optional modules you would like to activate:\" \
20 70 20 "

for module in $OPTMODDIR/* ; do
	modulename="$(basename $module)"
	modulelist="${modulelist} $modulename"
	if [ ! -d /live/module/$modulename ]
	then dialogscript="${dialogscript} \"$modulename\" \"\" off \"\"" 
	#~ else dialogscript="${dialogscript} \"$modulename\" \"\" on \"\"" 
	fi
done

choice=$(eval "$dialogscript")

if [ "$choice" ]; then
    for modulename in $modulelist ; do
	if [[ "$(echo $choice | grep -w $modulename)" ]];then
		#~ if [ ! -d /live/module/$modulename ] #it could be already mounted
		#~ then manage-optional-modules.sh --add /live/media/boot/optional/$modulename
		#~ fi
		manage-optional-modules.sh --add /live/media/boot/optional/$modulename
	#~ else #the module is either not loaded or asked to unload
		#~ if [ -d /live/module/$modulename ] #it could be already mounted
		#~ then manage-optional-modules.sh --remove /live/media/boot/optional/$modulename
		#~ fi
	fi
    done
fi
