#!/bin/ash

install jwm,bash,pcmanfm,wbar

#check for file exists
touch ~/startup.sh
chmod +x ~/startup.sh
echo "#!/bin/ash" > startup.sh
#echo 
echo "pcmanfm --desktop" > startup.sh
echo "sleep 5" > startup.sh
echo "wbar --above-desk --pos bottom" >> startup.sh
echo "$HOME/starup.sh" >> ~/.xsession


filetool.sh -b
