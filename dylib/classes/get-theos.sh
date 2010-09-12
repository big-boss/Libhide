#!/bin/bash

if [ ! -d framework ]; then
    svn co http://svn.howett.net/svn/theos/trunk framework
else
    echo "The Theos \"framework\" directory already exists."
fi
