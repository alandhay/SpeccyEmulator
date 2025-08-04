#!/usr/bin/env bash

echo "Installing ZEsarUX under /usr ..."

mkdir -p /usr
mkdir -p /usr/bin
mkdir -p /usr/share/zesarux/

COMMONFILES="ACKNOWLEDGEMENTS LICENSE LICENSES_info licenses Changelog Cambios TODO* README HISTORY FEATURES FEATURES_es EXCLUSIVEFEATURES INSTALL INSTALLWINDOWS IN_MEMORIAM* ALTERNATEROMS INCLUDEDTAPES DONATE DONORS FAQ *.odt mantransfev3.bin *.rom zxuno.flash tbblue.mmc pcw_8x_boot*dsk speech_filters text_image_filters my_soft copiers docs zesarux.mp3 zesarux.xcf editionnamegame.tzx* bin_sprite_to_c.sh keyboards alternate_roms z88_shortcuts.bmp zesarux.pdf"

# -f to force overwrite already existing share files which are set to 444
cp -f -a $COMMONFILES /usr/share/zesarux/

cp zesarux /usr/bin/


# Default permissions for files: read only
find /usr/share/zesarux/ -type f -print0| xargs -0 chmod 444

#set permissions to all writable for disk images
chmod 666 /usr/share/zesarux/zxuno.flash
chmod 666 /usr/share/zesarux/tbblue.mmc

# Speech filters can be run
chmod +x /usr/share/zesarux/speech_filters/*

echo "Install done"

