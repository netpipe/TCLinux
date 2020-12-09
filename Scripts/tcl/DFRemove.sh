#!/bin/bash
#Tecan
#Description: https://stackoverflow.com/questions/44016979/bash-find-and-remove-duplicate-files-from-different-folders
#https://unix.stackexchange.com/questions/421793/how-to-compare-two-directories-and-delete-duplicate-files

#find ./234 ./123 -type f -printf '%P\n' | sort | uniq -d | sed 's/^/.\/123\//g' | xargs rm
find /$1 -type f -printf "rm -f /$2/%P" | sh


dircmp -d dir1 dir2
