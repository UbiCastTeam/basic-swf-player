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

flex_path="./flex_sdk_4.6"
target_version="10.1"
builds[0]="-define+=CONFIG::allowCrossOrigin,true -o build/basicplayer-cross.swf"
builds[1]="-define+=CONFIG::allowCrossOrigin,false -o build/basicplayer.swf"

for i in 0 1; do
	$flex_path/bin/mxmlc -strict=true -compiler.debug -warnings=true BasicPlayer.as ${builds[i]} -library-path+=$flex_path/lib -include-libraries+=flashls.swc -use-network=true -source-path . -target-player $target_version -headless-server -static-link-runtime-shared-libraries
	if [[ $? != 0 ]]; then
		break
	fi
done
