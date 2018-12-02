#!/bin/bash
#run as tc user

#not ready yet
exit

#check if first run or successfully installed to hd already
#Install to HD
tce-load -wi tcinstaller-gui.tcz

#AutoSetup - made for qemu and virtualbox
tce-load -wi tcinstaller.tcz


#copyPackages
#factor5.sh copy

#startupModifiers
home=/mnt/sda1
TCE=$(tce-setdrive | cut -d "," -f 2)
#cp ./Packages/* "$home/tce/optional"
echo "$HOME/HomeScript.sh" >> ~/.xsession
cp ./HomeScript.sh ~/HomeScript.sh

#install sudo fix to make system more secure
tce-load -wo sudo.tcz
cp ./Scripts/sudo.sh /opt/bootlocal
echo "/opt/sudo.sh" >> /opt/bootlocal.sh

#sudo chown root /mnt/sda1/opt -R
#sudo chown root /mnt/sda1/
