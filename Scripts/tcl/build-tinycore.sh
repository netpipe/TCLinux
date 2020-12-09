# create a tinycorelinux fs with custom .tcz packages
# prerequisites: apt-get install squashfs-tools, npm i nugget -g

# dl release + packages (add your packages here)
nugget http://tinycorelinux.net/6.x/x86_64/release/CorePure64-6.3.iso http://tinycorelinux.net/6.x/x86_64/tcz/{pkg-config,make,gcc,gcc_base-dev,gcc_libs-dev,gcc_libs,glibc_base-dev,linux-3.16.2_api_headers,fuse}.tcz -c

# to support compiling addons
unsquashfs -f pkg-config.tcz
unsquashfs -f make.tcz
unsquashfs -f gcc.tcz
unsquashfs -f gcc_base-dev.tcz
unsquashfs -f gcc_libs-dev.tcz
unsquashfs -f gcc_libs.tcz
unsquashfs -f glibc_base-dev.tcz
unsquashfs -f linux-3.16.2_api_headers.tcz

# custom packages (add yours here)
unsquashfs -f fuse.tcz

# extract kernel, fs files from iso
sudo mkdir -p /mnt/tmp
sudo mount CorePure64-6.3.iso /mnt/tmp -o loop,ro
cp /mnt/tmp/boot/vmlinuz64 vmlinuz
cp /mnt/tmp/boot/corepure64.gz core.gz
sudo umount /mnt/tmp
sudo rm -rf /mnt/tmp

# extract core
mkdir -p core
( cd core ; zcat ../core.gz | sudo cpio -idm )

# copy extracted packages into fs
sudo cp -Rp squashfs-root/usr/ core/

# enables terminal (i think, blindly copied from xhyve example)
sudo sed -i '/^# ttyS0$/s#^..##' core/etc/securetty
sudo sed -i '/^tty1:/s#tty1#ttyS0#g' core/etc/inittab

# repackage core into output.gz
( cd core ; find | sudo cpio -o -H newc ) | gzip -c > output.gz

# cleanup
sudo rm -rf squashfs-root/ core/
# now boot vmlinuz and output.gz like this https://github.com/mist64/xhyve/blob/cd782515fff03bd4b80da60e29108f6b33476bf5/xhyverun.sh
