#!/usr/bin/env bash
#
#
#dependencie finder v0.1a (c)Halma ~ Tinycoreforum 05.Sep.2014
#
#with this script you can find every dependencie of an extention if exists.
#
#Thanks goes to: tinypoodle,Misalf
#
#
EXTENSIONS=(mc) 						#put your extentions,like (mc) or for more (extention1 extention2 ext...), inside the Clips (your extention.without ending)
MIRROR="distro.ibiblio.org/tinycorelinux/5.x/x86_64/tcz" 	#the mirror for the extention if not on harddrive
DESTDIR=/tmp/testt 						#your destination directory where to save the extentions
#
#
#DO NOT CHANGE ANYTHING AFTER THIS LINE
#
#
#set -x
declare -a EXTENSIONS  # indexed array
declare -a ALLEXTENSIONS #all extensions ever added

ALLEXTENSIONS=()
EXTENSIONFILESSOURCE=/etc/sysconfig/tcedir/optional #thanks Misalf http://forum.tinycorelinux.net/index.php/topic,17454.msg104621.html#msg104621

[ -d $DESTDIR ] && rm -rf $DESTDIR
mkdir -p $DESTDIR

count=0
function1 () {

#first get the .dep file to parse
for A in ${EXTENSIONS[@]}; do
    if [ ! -f $DESTDIR/$A.tcz.dep ];then
	wget $MIRROR/$A.tcz.dep -O $DESTDIR/$A.tcz.dep || rm -f $DESTDIR/$A.tcz.dep
    fi
done

for i in ${EXTENSIONS[@]}; do
    echo "start...."$count
    #if the extention has an .dep file
    if [ -f $DESTDIR/$i.tcz.dep ];then #if .dep file exists write it into an array
	echo "current dep: "$i
	#put new deps into array-elements
	for j in $(cat $DESTDIR/$i.tcz.dep | sed -r 's/\.tcz+$//') ; do
	    #check that the extention isnt allready in the ALLEXTTENSIONS array
	    for h in ${ALLEXTENSIONS[@]}; do
		
		#if $j allready exists in $ALLEXTENSIONS[@] ,skip it
		if [ "$j" == "$h" ]; then
		    echo "skipping: "$j
		j=""
		fi
	    done
	    echo "add dep: "$j
	    EXTENSIONS+=($j)
	    ALLEXTENSIONS+=($j)
	done
    fi
	#copy the extention files
	echo "copying: "$i
	
	for K in $i.{tcz.dep,tcz.md5.txt,tcz}; do
	    if [ -f "$EXTENSIONFILESSOURCE/$K" ]; then
		echo "copying :"$K
		cp -f $EXTENSIONFILESSOURCE/$K $DESTDIR
	    else
		echo "wget ---->" $K
		wget $MIRROR/$K -O $DESTDIR/$K || rm -f $DESTDIR/$K
	    fi
	done
	
	#fi
	echo "delete: "$i
        unset EXTENSIONS[0] #remove current array-element from array
	EXTENSIONS=( "${EXTENSIONS[@]}" ) #(re)set the array
	((count=count+1))
done

}

while [ $(echo ${#EXTENSIONS[@]}) -gt 0 ] ; do
echo "calle function1"
function1
done
echo ""
echo "---------"
echo "- Done! -"
echo "---------"
