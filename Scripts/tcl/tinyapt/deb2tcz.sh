#!/bin/sh
dir="$PWD"
d="$(mktemp -d)"
deb="$d/i.deb"
cp "$1" $deb || exit
cd $d

dpkg-deb --control $deb $d || exit
package=$(cat control | grep '^Package: ' | sed 's/^Package: \(.*\)$/\1/g')

alien -tc $deb || exit
tgz=$(find $d -name '*.tgz')

mkdir $d/tgz
cd $d/tgz
tar -xvzf "$tgz"
cd $d

if [ -d $d/tgz/install ] ;then
	mv $d/tgz/install $d/install
	mkdir -p $d/tgz/usr/local/tce.installed
	cp $d/install/doinst.sh $d/tgz/usr/local/tce.installed/$package
fi

cd "$dir"
mksquashfs $d/tgz/* $package.tcz

rm -fr "$d"
