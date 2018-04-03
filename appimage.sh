#! /bin/bash

# Move blacklisted files to a special folder
move_blacklisted()
{
  mkdir -p ./usr/lib-blacklisted
  #BLACKLISTED_FILES=$(wget -q https://github.com/probonopd/AppImages/raw/master/excludelist -O - | sed '/^\s*$/d' | sed '/^#.*$/d')
  #BLACKLISTED_FILES=$(cat $APPIMAGEBASE/AppImages/excludelist | sed '/^\s*$/d' | sed '/^#.*$/d')
  BLACKLISTED_FILES=$(cat "$APPIMAGEBASE/excludelist" | sed '/^\s*$/d' | sed '/^#.*$/d')
  echo $BLACKLISTED_FILES
  for FILE in $BLACKLISTED_FILES ; do
    FOUND=$(find . -type f -name "${FILE}" 2>/dev/null)
    if [ ! -z "$FOUND" ] ; then
      echo "Deleting blacklisted ${FOUND}"
      #rm -f "${FOUND}"
      mv "${FOUND}" ./usr/lib-blacklisted
    fi
  done
}


wget -q https://github.com/probonopd/AppImages/raw/master/functions.sh -O ./functions.sh
. ./functions.sh

APP=luminance-hdr
APP_VERSION=0.5.0
LOWERAPP=${APP,,} 

UPDATE=1
REBUILD=1

rm -rf out $APP

source /opt/qt58/bin/qt58-env.sh


PREFIX=/zyx
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
export XDG_DATA_DIRS=$PREFIX/share:$XDG_DATA_DIRS
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH


#exit

cd $TRAVIS_BUILD_DIR

pwd
WD=$(pwd)
export APPIMAGEBASE=$(pwd)

ls

mkdir -p $APP/$APP.AppDir
cd $APP/$APP.AppDir
mkdir -p usr
cp -rL $PREFIX/* usr
mv usr/bin/$LOWERAPP usr/bin/$LOWERAPP.bin

#cp -a ../../$LOWERAPP.launcher usr/bin/$LOWERAPP
cat > usr/bin/$LOWERAPP <<\EOF
#! /bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "Input parameters: \"$@\""
echo ""
echo "Input File: $1"
ldd $HERE/LOWERAPP.bin
echo ""
echo "$HERE/LOWERAPP.bin -vv \"$@\""
$HERE/LOWERAPP.bin -vv "$@"
EOF
sed -i -e "s|LOWERAPP|$LOWERAPP|g" usr/bin/$LOWERAPP
chmod u+x usr/bin/$LOWERAPP

mkdir -p usr/share/icons
mkdir -p usr/share/applications

#cp ./usr/share/applications/$LOWERAPP.desktop .
#sed -i -e "s|gimp-2.9|$LOWERAPP|g" $LOWERAPP.desktop
#rm -rf ./usr/share/icons/48x48/apps || true
cp $PREFIX/share/icons/hicolor/48x48/apps/$LOWERAPP.png $LOWERAPP.png

cp $PREFIX/share/applications/$LOWERAPP.desktop ./$LOWERAPP.desktop



#get_apprun
cp -a $TRAVIS_BUILD_DIR/AppRun ./AppRun

mkdir -p usr/lib/qt5/plugins
#cp -a /usr/lib/x86_64-linux-gnu/qt5/plugins/* usr/lib/qt5/plugins
cp -a /opt/qt58/plugins/* usr/lib/qt5/plugins

# Copy in the indirect dependencies
copy_deps ; copy_deps ; copy_deps # Three runs to ensure we catch indirect ones

move_lib

echo ""
echo "ls usr/lib/x86_64-linux-gnu"
ls usr/lib/x86_64-linux-gnu
echo ""
cp -L usr/lib/x86_64-linux-gnu/* usr/lib
rm -rf usr/lib/x86_64-linux-gnu
cp -a opt/qt58/lib/* usr/lib
cp -a zyx/lib/* usr/lib
cp -a zyx/lib64/* usr/lib64
rm -rf zyx

echo ""
echo "ls usr/lib"
ls usr/lib

#exit

delete_blacklisted
#move_blacklisted


# patch_usr
# Patching only the executable files seems not to be enough for darktable
find usr/ -type f -exec sed -i -e "s|$PREFIX|././|g" {} \;
find usr/ -type f -exec sed -i -e "s|/usr|././|g" {} \;


# Workaround for:
# GLib-GIO-ERROR **: Settings schema 'org.gtk.Settings.FileChooser' is not installed
# when trying to use the file open dialog
# AppRun exports usr/share/glib-2.0/schemas/ which might be hurting us here
( mkdir -p usr/share/glib-2.0/schemas/ ; cd usr/share/glib-2.0/schemas/ ; ln -s /usr/share/glib-2.0/schemas/gschemas.compiled . )

# Workaround for:
# ImportError: /usr/lib/x86_64-linux-gnu/libgdk-x11-2.0.so.0: undefined symbol: XRRGetMonitors
cp $(ldconfig -p | grep libgdk-x11-2.0.so.0 | cut -d ">" -f 2 | xargs) ./usr/lib/
cp $(ldconfig -p | grep libgtk-x11-2.0.so.0 | cut -d ">" -f 2 | xargs) ./usr/lib/

GLIBC_NEEDED=$(glibc_needed)
export VERSION=git-$(date +%Y%m%d)
echo $VERSION

get_desktopintegration $LOWERAPP
#cp -a ../../desktopintegration ./usr/bin/$LOWERAPP.wrapper
#chmod a+x ./usr/bin/$LOWERAPP.wrapper
#sed -i -e "s|Exec=$LOWERAPP|Exec=$LOWERAPP.wrapper|g" $LOWERAPP.desktop

# Go out of AppImage
cd ..

mkdir -p ../out/
ARCH="x86_64"
generate_appimage

########################################################################
# Upload the AppDir
########################################################################

pwd
ls ../out/*
transfer ../out/*
echo ""
echo "AppImage has been uploaded to the URL above; use something like GitHub Releases for permanent storage"
