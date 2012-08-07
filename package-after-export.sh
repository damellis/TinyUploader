#!/bin/sh
#
#
#
# Use rsync instead of cp -r so we can exclude the .svn stuff
#

rsync -arvz --exclude=.svn tools application.macosx/TinyUploader.app/Contents/Resources/Java/

rsync -arvz --exclude=.svn tools application.windows32
# also need USB driver for some reason, rxtx dll given to us
cp tools/bin-windows/libusb0.dll application.windows32

rsync -arvz --exclude=.svn tools application.windows64
# also need USB driver for some reason, rxtx dll given to us
cp tools/bin-windows/libusb0.dll application.windows64

#rsync -arvz --exclude=.svn tools application.linux/lib

# package up

mv application.macosx/TinyUploader.app .
zip -r TinyUploader-macosx.zip TinyUploader.app

mv application.windows32 TinyUploader-windows32
zip -r TinyUploader-windows32.zip TinyUploader-windows32

mv application.windows64 TinyUploader-windows64
zip -r TinyUploader-windows64.zip TinyUploader-windows64
