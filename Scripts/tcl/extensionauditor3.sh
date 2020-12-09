#!/bin/sh
# Extension audit script
#http://forum.tinycorelinux.net/index.php/topic,2475.0.html

. /etc/init.d/tc-functions

MIRROR=`cat /opt/tcemirror`
VERSION="3.x"

THISDIR=`pwd`

if [ ! -f /usr/local/tce.installed/file ]; then
	echo "${RED}Install the file.tcz extension.${NORMAL}"
	exit 1
fi

if [ ! -f /usr/local/tce.installed/diffutils ]; then
	echo "${RED}Install the diffutils.tcz extension.${NORMAL}"
	exit 1
fi

if [ ! -f /usr/local/tce.installed/squashfs-tools-4.x ]; then
	echo "${RED}Install the squashfs-tools extension.${NORMAL}"
	exit 1
fi

if [ ! -f /usr/local/tce.installed/wget ]; then
	echo "${RED}Install wget extension.${NORMAL}"
	exit 1
fi




checkstartup() {
	if [ -d "$TMP2"/usr/local/tce.installed/ ]; then
	     if [ `ls "$TMP2"/usr/local/tce.installed/ | wc -l` == "1" ]; then	
			
			OUT=$(ls -d -l "$TMP2"/usr/local/tce.installed)
      			PERM=$(echo $OUT | cut -d" " -f1)
      			OWNER=$(echo $OUT | cut -d" " -f3-4)

      			[ "$PERM" == "drwxrwxr-x" ] || [ "$PERM" == "drwxrwsr-x" ] || export FILE=1
      			[ "$OWNER" == "root staff" ] || export FILE=1
		
		    if [ -f "$TMP2"/usr/local/tce.installed/"$BASENAME" ]; then
			if [ ! -x "$TMP2"/usr/local/tce.installed/"$BASENAME" ]; then
				export FILE=1	
				echo "${YELLOW}Will rebuild ${BLUE}"$F"${YELLOW} for wrong /usr/local/tce.installed perms.${NORMAL}"
				echo "$F" >> /tmp/submitqc/wrongstartscriptperms	
			fi
		    fi


		    if [ ! -z `ls "$TMP2"/usr/local/tce.installed/` ] && [ ! -f "$TMP2"/usr/local/tce.installed/"$BASENAME" ]; then
			
				echo "${YELLOW}Will rebuild ${BLUE}"$F"${YELLOW} for wrong /usr/local/tce.installed script name.${NORMAL}"
				echo "$F" >> /tmp/submitqc/wrongstartscriptname
				export FILE=1
			
		    fi
		

		if [ "$FILE" == "1" ]; then
			
			rebuild
		fi
		unset FILE
             else
		echo "${BLUE}"$F"${RED} has more than one /usr/local/tce.installed script.  Please remake.${NORMAL}"
		unset FILE
	     fi
	
		
	fi
}


checkmaintainer() {
unset NAMES
if  wget -O /tmp/submitqc/."$F".info "$MIRROR""$VERSION"/tcz/"$F".info > /dev/null 2>&1; then
MAINTAINER=`grep "Extension_by" /tmp/submitqc/."$F".info | cut -d: -f2`
SUBMITTER=`grep "Extension_by" "$F".info | cut -d: -f2`
	echo "Extension: "$F"" >> /tmp/submitqc/tcemaintainer
	echo "Maintainer is "$MAINTAINER"" >> /tmp/submitqc/tcemaintainer
	echo "Submitter is "$SUBMITTER"" >> /tmp/submitqc/tcemaintainer
	echo " " >> /tmp/submitqc/tcemaintainer
	echo " "
	echo "${BLUE}"$F"${YELLOW} is maintained by ${GREEN}"$MAINTAINER"${YELLOW}. You are ${GREEN}"$SUBMITTER"${YELLOW}.  Make sure the maintainer is aware you are updating his extension.${NORMAL}"
fi
echo " "
echo "$F" > /tmp/submitqc/.extname

echo "EXT: "$F" - SIMILARLY NAMED EXTENISIONS:" >> /tmp/submitqc/similarextensions
> /tmp/submitqc/.temp
for I in `grep $(basename "$F" .tcz) /tmp/submitqc/.info.lst`; do echo "$I".tcz >> /tmp/submitqc/.temp; done
for I in `cat /tmp/submitqc/.info.lst `; do grep "$I" /tmp/submitqc/.extname >/dev/null && echo "$I".tcz >> /tmp/submitqc/.temp; done

cat /tmp/submitqc/.temp | uniq >> /tmp/submitqc/similarextensions

NAMES=`cat /tmp/submitqc/.temp | uniq`
if [ ! -z "$NAMES" ]; then
   echo "${BLUE}"$F"${YELLOW}  has some similarly named extensions in the repo.  Make sure yours does not \
   collide with these:${NORMAL}"
   echo " "
   echo "${GREEN}"$NAMES"${NORMAL}"
   echo " " >> /tmp/submitqc/similarextensions
   echo " "
fi
}

checkdiff() {
[ -f /tmp/submitqc/listfilediffs/"$F".difflist ] && rm /tmp/submitqc/listfilediffs/"$F".difflist
[ -d /tmp/submitqc/listfilediffs/ ] || mkdir -p /tmp/submitqc/listfilediffs/
#> /tmp/submitqc/listfilediffs/"$F".difflist
if  wget -O /tmp/submitqc/."$F".repolist "$MIRROR""$VERSION"/tcz/"$F".list > /dev/null 2>&1; then
	diff -NBa -U 0  /tmp/submitqc/."$F".repolist "$F".list > /tmp/submitqc/listfilediffs/"$F".difflist
 
  if [ -s /tmp/submitqc/listfilediffs/"$F".difflist ]; then
	echo " "
	sed -i '1,3d' /tmp/submitqc/listfilediffs/"$F".difflist
	
	sed -i '1i ---' /tmp/submitqc/listfilediffs/"$F".difflist
	sed -i '1i Minus means file is in the existing repo ext. and not in yours' /tmp/submitqc/listfilediffs/"$F".difflist
	sed -i '1i Plus means file is in your ext. and not in repos' /tmp/submitqc/listfilediffs/"$F".difflist
   	echo " "
   echo ${BLUE}"$F": "${YELLOW}There are filename differences in your extension and the one\
	existing in the repo,they are noted above and stored in ${BLUE}/tmp/submitqc/listfilediffs/"$F".difflist.${NORMAL}"
	
	
  fi			
	
 sleep 5
fi
[ -f /tmp/submitqc/."$F".repolist ] && rm /tmp/submitqc/."$F".repolist


}

checkappend() {
	if find "$TMP2" -maxdepth 1 | grep "_1"; then
			export APPEND=1	
	fi

	if [ "$APPEND" == "1" ]; then
			echo "${BLUE}"$F"${RED} has unwanted data appended to it. Please remake.${NORMAL}"
			echo "$F" >> /tmp/submitqc/appendeddata
			unset APPEND
			sleep 3
	fi
}

checkblock() {
	if ! unsquashfs -s "$F" | grep "Block size" | grep "4096" > /dev/null; then
			echo "${BLUE}"$F"${YELLOW} is not 4096 block size.  Rebuilding with -b 4096.${NORMAL}"
			rebuild
	fi
}


rebuild() {
	mkdir "$F".123456789
	cp -a "$TMP2"/* "$F".123456789/
	chmod 775 "$F".123456789/
	#if [ "$BADPERM" == "1" ]; then
	#for I in `find "$F".123456789/ -type d`; do stat -c '%a' "$I" | grep 755 >/dev/null || \
#stat -c '%a' "$I" | grep 775 >/dev/null || stat -c '%a' "$I" | grep 2755 >/dev/null || stat -c '%a' "$I" | grep 2775 >/dev/null || chmod 755 "$I" ; done
 	#fi

	if [ ! -z `ls "$F".123456789/usr/local/tce.installed/` ] && [ ! -f "$F".123456789/usr/local/tce.installed/"$BASENAME" ]; then
	   
		mv `find "$F".123456789/usr/local/tce.installed/ -not -type d | tail -n 1` "$F".123456789/usr/local/tce.installed/"$BASENAME"
	   
	fi

	if [ -d "$F".123456789/usr/local/tce.installed ]; then
		chmod -R 775 "$F".123456789/usr/local/tce.installed
		chown -R root:staff "$F".123456789/usr/local/tce.installed
	fi
	sudo busybox umount -d "$TMP2"
	
	mksquashfs "$F".123456789 "$F".new -b 4096
	mv "$F".new "$F"
	rm -r "$F".123456789
	sudo busybox mount -o loop "$F" "$TMP2" > /dev/null 2>&1
	[ -f "$F".md5.txt ] && rm "$F".md5.txt
	
		
		
}

checkbasedirperm() {
	if ! su tc -c "ls "$THISDIR"/"$TMP2"" > /dev/null 2>&1; then
		echo "${YELLOW}Rebuilding "$F" for unreadable base squashfs directory.${NORMAL}"
		rebuild
	fi
}


checkdirperms() {
	unset BADPERM
	for I in `find "$TMP2" -type d`; do
		if ! stat -c '%a' "$I" | grep 755 > /dev/null && \
! stat -c '%a' "$I" | grep 775 >/dev/null && ! stat -c '%a' "$I" | grep 2755 >/dev/null && ! stat -c '%a' "$I" | grep 2775 >/dev/null; then
		#export BADPERM=1
		DIR=`echo "$I" | sed "s:"$TMP2"::"`
		echo ""$F":  `stat -c '%a' "$I"`  "$DIR"" >> /tmp/submitqc/baddirperms
		echo "${BLUE}"$F": ${GREEN}"$DIR"${YELLOW} directory has suspicious permissionss: ${GREEN}`stat -c '%a' "$I"`${NORMAL}"
		fi
		done
		sleep 3
	
}
	

echo_green() {
		if [ -f "$F".md5.txt ]; then
			echo "${BLUE}"$F"${GREEN} is a valid tcz file. Checking MD5 for ${BLUE}"$F":${NORMAL}"
			md5sum -c "$F".md5.txt
			if [ ! "$?" == "0" ]; then
				echo "${RED}Md5sum failed for "$F"${NORMAL}"
				echo "$F" >> /tmp/wrongmd5
			fi
		else
			echo "${BLUE}"$F"${GREEN} is a valid tcz file.  Creating MD5 for ${BLUE}"$F":${NORMAL}"
			md5sum "$F" > "$F".md5.txt
		fi

		
		cd "$TMP2"
		find `ls` -not -type d > ../"$F".list
		cd ..
		
		zsyncmake "$F" > /dev/null 2>&1
		
		
}





checkdep() {
if `ls *.dep > /dev/null 2>&1`; then
[ "$(ls -A /tmp/submitqc/missingdeps/)" ] && rm /tmp/submitqc/missingdeps/*
 for I in `ls *.dep`; do
	for F in `cat "$I"`; do

	if echo "$F" | grep "2.6.33.3" > /dev/null 2>&1; then
		echo "${RED}The ${BLUE}"$F"${RED} entry in ${BLUE}"$I" ${RED}needs to use the KERNEL variable instead of kernel version number.${NORMAL}"
		echo "The "$F" entry in "$I" needs to use the KERNEL variable instead of kernel version number." >> /tmp/submitqc/missingdeps/"$I"
		echo " " >> /tmp/submitqc/missingdeps/"$I"
	elif echo "$F" | grep "KERNEL" > /dev/null 2>&1; then
	    	
	    if B=`echo "$F" | sed 's:KERNEL:2.6.33.3-tinycore:g'` && wget --spider "$MIRROR""$VERSION"/tcz/"$B" \
		> /dev/null 2>&1; then
		sleep .001
            elif B=`echo "$F" | sed 's:KERNEL:2.6.33.3-tinycore64:g'` && wget --spider "$MIRROR""$VERSION"/tcz/"$B" \
		> /dev/null 2>&1; then
		sleep .001
	    else
		echo ""$F" is missing in the repo as a dependency of "$I"" >> /tmp/submitqc/missingdeps/"$I"
		echo "${BLUE}"$F"${RED} is missing in the repo as a dependency of ${BLUE}"$I"${NORMAL}"
		echo " " >> /tmp/submitqc/missingdeps/"$I"
	    fi			
   	else
	    if ! wget --spider "$MIRROR""$VERSION"/tcz/"$F" \
		> /dev/null 2>&1; then
		echo ""$F" is missing in the repo as a dependency of "$I"" >> /tmp/submitqc/missingdeps/"$I"
		echo "${BLUE}"$F"${RED} is missing in the repo as a dependency of ${BLUE}"$I"${NORMAL}"
		echo " " >> /tmp/submitqc/missingdeps/"$I"
		if [ -f "$F" ]; then
		  echo "${BLUE}"$F"${GREEN}, however is present in this batch of extensions being checked for upload.${NORMAL}"
	          echo ""$F", however, is present in this batch of extensions being checked for upload." >> /tmp/submitqc/missingdeps/"$I"
		fi	
	    fi
	    	
	fi   

	done
 done
[ "$(ls -A /tmp/submitqc/missingdeps/)" ] || echo "${GREEN}Dep files seem to have no detectable errors.${NORMAL}"
fi
}	

checkinfo() {
for I in `ls *.info`; do

	NAME=`basename "$I" .info`
	INFONAME=`cat "$I" | grep "Title" | awk '{print $2}'`

	if [ ! "$NAME" == "$INFONAME" ]; then
		echo "${RED}Name field in ${BLUE}"$I"${RED} is incorrect.${NORMAL}"
		echo "Name: field is not valid in "$I"." >> /tmp/submitqc/wronginfofile
	fi


	echo "The following errors are found in "$I". No news is good news:"
	[ -z `awk '/Change-log:/ { print $2 }' "$I"` ] && echo "Change-log: field is not valid in "$I"." && echo "Change-log: field is not valid in "$I"." >> /tmp/submitqc/wronginfofile
	[ -z `awk '/Comments:/ { print $2 }' "$I"` ] && echo "Comments: field is not valid in "$I"." && echo "Comments: field is not valid in "$I"." >> /tmp/submitqc/wronginfofile
	[ -z `awk '/Original-site:/ { print $2 }' "$I"` ] && echo "Original-site: field is not valid in "$I"." && echo "Original-site: field is not valid in "$I"." >> /tmp/submitqc/wronginfofile
	[ -z `awk '/Author:/ { print $2 }' "$I"` ] && echo "Author: field is not valid in "$I"." && echo "Author: field is not valid in "$I"." >> /tmp/submitqc/wronginfofile
	[ -z `awk '/Title:/ { print $2 }' "$I"` ] && echo "Title: field is not valid in "$I"." && echo "Title: field is not valid in "$I"." >> /tmp/submitqc/wronginfofile
	[ -z `awk '/Description:/ { print $2 }' "$I"` ] && echo "Description: field is not valid in "$I"." && echo "Description: field is not valid in "$I"." >> /tmp/submitqc/wronginfofile
	[ -z `awk '/Version:/ { print $2 }' "$I"` ] && echo "Version: field is not valid in "$I"." && echo "Version: field is not valid in "$I"." >> /tmp/submitqc/wronginfofile
	[ -z `awk '/Copying-policy:/ { print $2 }' "$I"` ] && echo "Copying-policy: field is not valid in "$I"." && echo "Copying-policy: field is not valid in "$I"." >> /tmp/submitqc/wronginfofile
	[ -z `awk '/Extension_by:/ { print $2 }' "$I"` ] && echo "Extension_by: field is not valid in "$I"." && echo "Extension_by: field is not valid in "$I"." >> /tmp/submitqc/wronginfofile
	[ -z `awk '/Size:/ { print $2 }' "$I"` ] && echo "Size: field is not valid in "$I"." && echo "Size: field is not valid in "$I"." >> /tmp/submitqc/wronginfofile
	[ -z `awk '/Current:/ { print $2 }' "$I"` ] && echo "Current: field is not valid in "$I"." && echo "Current: field is not valid in "$I"." >> /tmp/submitqc/wronginfofile
	file "$I" | grep "CRLF" && dos2unix -u "$I" && echo "${YELLOW}Fixing CRLF line terminators in ${BLUE}"$I"${YELLOW}.  Please don't use Windows apps to edit Linux files.${NORMAL}" \
&& echo ""$I" has CRLF line terminators in it.  Please don't use Windows apps to edit Linux files." >> /tmp/submitqc/wronginfofile
		
	sleep 1
done
}



if [ ! -z "$1" ]; then

[ -f /tmp/submitqc/.info.lst ] && rm  /tmp/submitqc/.info.lst
wget -O /tmp/submitqc/.info.lst.gz "$MIRROR""$VERSION"/tcz/info.lst.gz > /dev/null 2>&1
gunzip /tmp/submitqc/.info.lst.gz
sed -i 's:.tcz::g' /tmp/submitqc/.info.lst


if [ "$1" == "checkdep" ]; then
[ -d /tmp/submitqc/missingdeps ] || mkdir -p /tmp/submitqc/missingdeps
checkdep
exit 0
fi

if [ "$1" == "checkinfo" ]; then
[ -d /tmp/submitqc ] || mkdir /tmp/submitqc
checkinfo
exit 0
fi

if [ "$1" == "checkmaintainer" ]; then
[ -d /tmp/submitqc ] || mkdir /tmp/submitqc
> /tmp/submitqc/tcemaintainer
for F in `ls *.tcz`; do
checkmaintainer
done
exit 0
fi

fi

[ -d /tmp/submitqc ] && rm -r /tmp/submitqc

mkdir -p /tmp/submitqc/missingdeps

[ -f /tmp/submitqc/.info.lst ] && rm  /tmp/submitqc/.info.lst
wget -O /tmp/submitqc/.info.lst.gz "$MIRROR""$VERSION"/tcz/info.lst.gz > /dev/null 2>&1
gunzip /tmp/submitqc/.info.lst.gz
sed -i 's:.tcz::g' /tmp/submitqc/.info.lst

> /tmp/submitqc/corrupttcz
> /tmp/submitqc/wrongblocksize
> /tmp/submitqc/wrongmd5
> /tmp/submitqc/tcemaintainer
> /tmp/submitqc/similarextensionshttp://forum.tinycorelinux.net/index.php/topic,2475.0.html
> /tmp/submitqc/appendeddata
> /tmp/submitqc/wrongstartscriptperms
> /tmp/submitqc/wrongstartscriptname
> /tmp/submitqc/wronginfofile
> /tmp/submitqc/baddirperms


for F in `ls | xargs file | grep ".tcz" | grep "Squashfs" | cut -f 1 -d :`; do
	TMP2=""$F".tmpdir12345678"
	if df | grep "$TMP2" > /dev/null 2>&1; then
		umount "$TMP2"
	fi
	[ -d "$TMP2" ] && rm -rf "$TMP2"
	mkdir "$TMP2"
	BASENAME=`basename "$F" .tcz`
       

	if `sudo busybox mount -o loop "$F" "$TMP2" > /dev/null 2>&1`; then
		checkappend
		checkstartup
		checkbasedirperm
		checkdirperms
    		if [ -f "$F".list ]; then
			checkdiff
		fi			
		if [ -f "$F".info ]; then
			checkmaintainer
		fi
		checkblock
		echo_green


		
		busybox umount -d "$TMP2"
		sleep 2
		rm -rf "$TMP2"
		echo " "
		echo ${GREEN}##############################################${NORMAL}
		echo ${GREEN}##############################################${NORMAL}
	else
		echo "${BLUE}"$F"${RED} is a corrupt tcz file, please remake.${NORMAL}"
		echo "$F" >> /tmp/submitqc/corrupttcz
		rm -rf "$TMP2"
	fi
   
	
done
echo " "
checkdep
echo " "
checkinfo
sudo chown tc:staff *.tcz*
sudo chmod 664 *.tcz*

if [ ! -z `cat /tmp/submitqc/corrupttcz` ]; then
	echo "${RED}YOU HAVE CORRUPT TCZ FILES. PLEASE REVIEW \
${GREEN}/tmp/submitqc/corrupttcz${NORMAL}"
fi
