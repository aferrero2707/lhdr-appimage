#!/usr/bin/env bash

########################################################################
# Package the binaries built on Travis-CI as an AppImage
# By Simon Peter 2016
# For more information, see http://appimage.org/
# Report issues to https://github.com/Beep6581/RawTherapee/issues
########################################################################

# Fail handler
die () {
    printf '%s\n' "" "Aborting!" ""
    set +x
    exit 1
}

trap die HUP INT QUIT ABRT TERM

# Program name
APP="luminance-hdr"
LOWERAPP=${APP,,}


# PREFIX must be set to a 3-character string that represents the path where all compiled code,
# including RT, is installed. For example, if PREFIX=zyx it means that RT is installed under /zyx

# Prefix (without the leading "/") in which RawTherapee and its dependencies are installed:
export PREFIX="$AIPREFIX"
export AI_SCRIPTS_DIR="/sources/ci"

# Get the latest version of the AppImage helper functions,
# or use a fallback copy if not available:
if ! wget "https://github.com/probonopd/AppImages/raw/master/functions.sh" --output-document="./functions.sh"; then
    cp -a "${TRAVIS_BUILD_DIR}/ci/functions.sh" ./functions.sh || exit 1
fi

# Source the script:
. ./functions.sh

echo ""
echo "########################################################################"
echo ""
echo "AppImage configuration:"
echo "  APP: \"$APP\""
echo "  LOWERAPP: \"$LOWERAPP\""
echo "  PREFIX: \"$PREFIX\""
echo "  AI_SCRIPTS_DIR: \"${AI_SCRIPTS_DIR}\""
echo ""

########################################################################
# Additional helper functions:
########################################################################

# Delete blacklisted libraries
delete_blacklisted_custom()
{
    printf '%s\n' "APPIMAGEBASE: ${APPIMAGEBASE}"
    ls "${APPIMAGEBASE}"

    while IFS= read -r line; do
        find . -type f -name "${line}" -delete
    done < <(cat "$APPIMAGEBASE/excludelist" | sed '/^[[:space:]]*$/d' | sed '/^#.*$/d')
    # TODO Try this, its cleaner if it works:
    #done < "$APPIMAGEBASE/excludelist" | sed '/^[[:space:]]*$/d' | sed '/^#.*$/d'
}


# Remove debugging symbols from AppImage binaries and libraries
strip_binaries()
{
    chmod u+w -R "${APPDIR}"
    {
        find "${APPDIR}/usr" -type f -name "${LOWERAPP}*" -print0
        find "${APPDIR}" -type f -regex '.*\.so\(\.[0-9.]+\)?$' -print0
    } | xargs -0 --no-run-if-empty --verbose -n1 strip
}


echo ""
echo "########################################################################"
echo ""
echo "Checking commit hash"
echo ""
sudo apt-get -y update
sudo apt-get install -y wget git || exit 1
rm -f /tmp/commit-${GIT_BRANCH}.hash
wget https://github.com/aferrero2707/rt-appimage/releases/download/continuous/commit-${GIT_BRANCH}.hash -O /tmp/commit-${GIT_BRANCH}.hash

cd /sources
rm -f travis.cancel
if  [ -e /tmp/commit-${GIT_BRANCH}.hash ]; then
	git rev-parse --verify HEAD > /tmp/commit-${GIT_BRANCH}-new.hash
	echo -n "Old ${GIT_BRANCH} hash: "
	cat /tmp/commit-${GIT_BRANCH}.hash
	echo -n "New ${GIT_BRANCH} hash: "
	cat /tmp/commit-${GIT_BRANCH}-new.hash
	diff /tmp/commit-${GIT_BRANCH}-new.hash /tmp/commit-${GIT_BRANCH}.hash
	if [ $? -eq 0 ]; then 
		touch travis.cancel
		echo "No new commit to be processed, exiting"
		exit 0
	fi
fi
cp /tmp/commit-${GIT_BRANCH}-new.hash ./commit-${GIT_BRANCH}.hash

echo ""
echo "########################################################################"
echo ""
echo "Installing additional system packages"
echo ""

sudo add-apt-repository -y ppa:beineri/opt-qt58-trusty
sudo apt-get update
sudo apt-get install -y git wget g++ gettext intltool qt58base qt58svg qt58webengine qt58tools libtool autoconf automake make libexiv2-dev mesa-common-dev libalglib-dev libboost-all-dev libfftw3-dev libtiff5-dev libpng12-dev libopenexr-dev libgsl0-dev libcfitsio3-dev liblcms2-dev libeigen3-dev

# Set environment variables to allow finding the dependencies that are
# compiled from sources
source /opt/qt58/bin/qt58-env.sh
export PATH="/${PREFIX}/bin:/work/inst/bin:${PATH}"
export LD_LIBRARY_PATH="/${PREFIX}/lib:/work/inst/lib:${LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="/$PREFIX/share:$XDG_DATA_DIRS"
export PKG_CONFIG_PATH="/${PREFIX}/lib/pkgconfig:/work/inst/lib/pkgconfig:${PKG_CONFIG_PATH}"

locale-gen en_US.UTF-8
export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_ALL="en_US.UTF-8"




echo ""
echo "########################################################################"
echo ""
echo "Building and installing LuminanceHDR"
echo ""

# RawTherapee build and install
mkdir -p /sources/build/appimage
cd /sources/build/appimage || exit 1
if [ ! -e LibRaw ]; then
	(git clone https://github.com/LibRaw/LibRaw.git && \
	cd LibRaw && \
	autoreconf --install && \
	./configure --prefix=/usr && \
	make -j2 && sudo make install) || exit 1
fi
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/$PREFIX /sources || exit 1
make --jobs=2 || exit 1
sudo make install || exit 1



# Create a folder in the shared area where the AppImage structure will be copied
mkdir -p /sources/build/appimage
cd /sources/build/appimage || exit 1
cp "${AI_SCRIPTS_DIR}"/excludelist . || exit 1
export APPIMAGEBASE="$(pwd)"

# Remove old AppDir structure (if existing)
rm -rf "${APP}.AppDir"
mkdir -p "${APP}.AppDir/usr/"
cd "${APP}.AppDir" || exit 1
export APPDIR="$(pwd)"
echo "  APPIMAGEBASE: \"$APPIMAGEBASE\""
echo "  APPDIR: \"$APPDIR\""
echo ""

#sudo chown -R "$USER" "/${PREFIX}/"

echo ""
echo "########################################################################"
echo ""
echo "Copy executable"

# Copy main executable into $APPDIR/usr/bin/
mkdir -p ./usr/bin
echo "cp -a \"/${PREFIX}/bin/${LOWERAPP}\" \"./usr/bin/${LOWERAPP}\""
cp -a "/${PREFIX}/bin/${LOWERAPP}" "./usr/bin/${LOWERAPP}" || exit 1
echo ""


echo ""
echo "########################################################################"
echo ""
echo "Copy dependencies"
echo ""

mkdir -p usr/lib/qt5/plugins
#cp -a /usr/lib/x86_64-linux-gnu/qt5/plugins/* usr/lib/qt5/plugins
cp -a /opt/qt58/plugins/* usr/lib/qt5/plugins

# Copy in the dependencies that cannot be assumed to be available
# on all target systems
copy_deps; copy_deps; copy_deps;

cp -L ./lib/x86_64-linux-gnu/*.* ./usr/lib
rm -rf ./lib/x86_64-linux-gnu

cp -L ./lib/*.* ./usr/lib
rm -rf ./lib

cp -L ./usr/lib/x86_64-linux-gnu/*.* ./usr/lib
rm -rf ./usr/lib/x86_64-linux-gnu

cp -L "./$PREFIX/lib/x86_64-linux-gnu/"*.* ./usr/lib
rm -rf "./$PREFIX/lib/x86_64-linux-gnu"

cp -L "./$PREFIX/lib/"*.* ./usr/lib
rm -rf "./$PREFIX/lib"

cp -L opt/qt58/lib/* usr/lib


echo ""
echo "########################################################################"
echo ""
echo 'Move all libraries into $APPDIR/usr/lib'
echo ""

# Move all libraries into $APPDIR/usr/lib
move_lib


echo ""
echo "########################################################################"
echo ""
echo "Delete blacklisted libraries"
echo ""

# Delete dangerous libraries; see
# https://github.com/probonopd/AppImages/blob/master/excludelist
delete_blacklisted_custom


echo ""
echo "########################################################################"
echo ""
echo "Copy libstdc++.so.6 and libgomp.so.1 into the AppImage"
echo ""

# Copy libstdc++.so.6 and libgomp.so.1 into the AppImage
# They will be used if they are newer than those of the host
# system in which the AppImage will be executed
stdcxxlib="$(ldconfig -p | grep 'libstdc++.so.6 (libc6,x86-64)'| awk 'NR==1{print $NF}')"
echo "stdcxxlib: $stdcxxlib"
if [[ x"$stdcxxlib" != "x" ]]; then
    mkdir -p usr/optional/libstdc++
    cp -L "$stdcxxlib" usr/optional/libstdc++ || exit 1
fi

gomplib="$(ldconfig -p | grep 'libgomp.so.1 (libc6,x86-64)'| awk 'NR==1{print $NF}')"
echo "gomplib: $gomplib"
if [[ x"$gomplib" != "x" ]]; then
    mkdir -p usr/optional/libstdc++
    cp -L "$gomplib" usr/optional/libstdc++ || exit 1
fi


echo ""
echo "########################################################################"
echo ""
echo "Patch away absolute paths"
echo ""

# Patch away absolute paths; it would be nice if they were relative
find usr/ -type f -exec sed -i -e 's|/usr/|././/|g' {} \; -exec echo -n "Patched /usr in " \; -exec echo {} \; >& patch1.log
find usr/ -type f -exec sed -i -e "s|/${PREFIX}/|././/|g" {} \; -exec echo -n "Patched /${PREFIX} in " \; -exec echo {} \; >& patch2.log


echo ""
echo "########################################################################"
echo ""
echo "Copy desktop file and application icon"

# Copy desktop and icon file to AppDir for AppRun to pick them up
mkdir -p usr/share/applications/ || exit 1
echo "cp \"/${PREFIX}/share/applications/net.sourceforge.qtpfsgui.LuminanceHDR.desktop\" \"usr/share/applications\""
cp "/${PREFIX}/share/applications/net.sourceforge.qtpfsgui.LuminanceHDR.desktop" "usr/share/applications" || exit 1

# Copy hicolor icon theme
mkdir -p usr/share/icons
echo "cp -r \"/${PREFIX}/share/icons/hicolor\" \"usr/share/icons\""
cp -r "/${PREFIX}/share/icons/hicolor" "usr/share/icons" || exit 1
echo ""


echo ""
echo "########################################################################"
echo ""
echo "Creating top-level desktop and icon files, and application launcher"
echo ""

#cp /$PREFIX/share/icons/hicolor/48x48/apps/$LOWERAPP.png $LOWERAPP.png
#cp /$PREFIX/share/applications/$LOWERAPP.desktop ./$LOWERAPP.desktop
# TODO Might want to "|| exit 1" these, and generate_status
#get_apprun || exit 1
cp -a "${AI_SCRIPTS_DIR}/AppRun" . || exit 1
#get_desktop || exit 1
cp "/${PREFIX}/share/applications/net.sourceforge.qtpfsgui.LuminanceHDR.desktop" ./$LOWERAPP.desktop || exit 1
get_icon || exit 1
mkdir -p "./usr/share/metainfo/" || exit 1
cp "/${PREFIX}/share/appdata/net.sourceforge.qtpfsgui.LuminanceHDR.appdata.xml" "./usr/share/metainfo/${LOWERAPP}.appdata.xml" || exit 1


echo ""
echo "########################################################################"
echo ""
echo "Copy fonts configuration"
echo ""

# The fonts configuration should not be patched, copy back original one
if [[ -e /$PREFIX/etc/fonts/fonts.conf ]]; then
    mkdir -p usr/etc/fonts
    cp "/$PREFIX/etc/fonts/fonts.conf" usr/etc/fonts/fonts.conf || exit 1
elif [[ -e /usr/etc/fonts/fonts.conf ]]; then
    mkdir -p usr/etc/fonts
    cp /usr/etc/fonts/fonts.conf usr/etc/fonts/fonts.conf || exit 1
fi


echo ""
echo "########################################################################"
echo ""
echo "Run get_desktopintegration"
echo ""

# desktopintegration asks the user on first run to install a menu item
get_desktopintegration "$LOWERAPP"


# Workaround for:
# ImportError: /usr/lib/x86_64-linux-gnu/libgdk-x11-2.0.so.0: undefined symbol: XRRGetMonitors
cp "$(ldconfig -p | grep libgdk-x11-2.0.so.0 | cut -d ">" -f 2 | xargs)" ./usr/lib/
cp "$(ldconfig -p | grep libgtk-x11-2.0.so.0 | cut -d ">" -f 2 | xargs)" ./usr/lib/


echo ""
echo "########################################################################"
echo ""
echo "Stripping binaries"
echo ""

# Strip binaries.
strip_binaries

# AppDir complete
# Packaging it as an AppImage cannot be done within a Docker container
exit 0
