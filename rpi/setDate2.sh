#!/bin/bash
#raspberrypi zero version for tcl
#in=$(date) # check if date older than tmpdate in home
#in="$(wget -qS --max-redirect 0 http://bing.com/ 2>&1|grep -oiP 'Date: \K.+')"
#wget -qS --max-redirect 0 http://bing.com/ 2>&1|grep -oi 'Date: \K.+' > ~/.tmpdate
wget -qSO- --max-redirect=0 googl.com 2>&1 | grep Date: | cut -d" " -f5-8 > ~/.tmpdate
#echo "$in" > ~/.tmpdate
in=$(cat ~/.tmpdate)
if [ "$in" == '' ]; then
 echo "found"
else
#echo $in
#Thu, 03 Dec 2020 06:05:22 GMT
#day=echo $in | cut -f 0 -d ",";
monthnum=$(echo "$in" | cut -f 2 -d " ";)
daynum=$(echo "$in" | cut -f 1 -d " ";)
year=$(echo "$in" | cut -f 3 -d " ";)
time=$(echo "$in" | cut -f 4 -d " ";)
echo "$monthnum $daynum $time $year";
#sudo date -s "DEC 2 18:14:00 2020"
sudo date -s "$monthnum $daynum $time $year";
   # sudo date --set=\"$in\"
fi



