#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Script to compile the swf files using Flex without Grunt
#
# To compile the swf files, you have to download the Flex SDK version 4.6 (only needs to be done once)
#   Download the free flex sdk from http://sourceforge.net/adobe/flexsdk/wiki/Download%20Flex%204.6/
#   Unzip it to a directory on your local machine (eg: /usr/local/flex_sdk_4.6)
#   Create a symlink from the install location to this directory
#   (eg: ln -s /usr/local/flex_sdk_4.6)
#
# If you do not have the required player global swc file, you will have to download and add it in flex:
#   https://helpx.adobe.com/flash-player/kb/archived-flash-player-versions.html
#   The file must be placed in flex_sdk_4.6/frameworks/libs/player/10.1/playerglobal.swc
#
# To run flash in debug mode with Ubuntu:
#   download flash player with debug: http://www.adobe.com/support/flashplayer/downloads.html
#   sudo apt-get install nspluginwrapper
#   sudo cp ~/Downloads/libflashplayer.so /usr/lib/flashplugin-installer/
#   sudo nspluginwrapper -v -i /usr/lib/flashplugin-installer/libflashplayer.so
#   if libssl3.so is missing run: sudo apt-get install libnss3:i386

import sys
import subprocess

FLEX_PATH = './flex_sdk_4.6'
TARGET_VERSION = '10.1'
BUILDS = [
    {'params': 'CONFIG::allowCrossOrigin,true', 'dest': 'basicplayer-cross.swf'},
    {'params': 'CONFIG::allowCrossOrigin,false', 'dest': 'basicplayer.swf'},
]
BASE_CMD = '%(flex)s/bin/mxmlc -strict=true -compiler.debug -warnings=true BasicPlayer.as -define+=%(params)s -o build/%(dest)s -library-path+=%(flex)s/lib -include-libraries+=flashls.swc -use-network=true -source-path . -target-player %(version)s -headless-server -static-link-runtime-shared-libraries'


if __name__ == '__main__':
    for build in BUILDS:
        cmd = BASE_CMD % dict(flex=FLEX_PATH, version=TARGET_VERSION, **build)
        p = subprocess.Popen(cmd, stdin=sys.stdin, stdout=sys.stdout, stderr=sys.stderr, shell=True)
        p.communicate()
        if p.returncode != 0:
            break
