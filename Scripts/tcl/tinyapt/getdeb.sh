#!/bin/sh
dir="$PWD"
d="$(mktemp -d)"
cd "$d"
apt download $1 || exit
mv *.deb o.deb
cd "$dir"
mv $d/o.deb $1.deb
rm -fr "$d"
