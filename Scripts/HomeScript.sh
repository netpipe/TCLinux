#!/bin/bash
#add this to your .xsession file at the bottom $HOME/HomeScript.sh
pcmanfm --desktop &
#beaver &
tce-load -i firefox
synergy-core --client -n tcl 10.0.2.2

