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



# Print some info:
printf '%s\n' "" "Current directory:"
pwd
printf '%s\n' "" "ls:"
ls
printf '%s\n' "" "ls -lh build:"
ls -lh build
printf '%s\n' "" "ls -lh build/appimage:"
ls -lh build/appimage

# Go into the folder created when running the Docker container:
printf '%s\n' "" "sudo chown -R $USER build"
#chown -R "$USER" build || exit 1
cd build/appimage || exit 1

export APPIMAGEBASE="$(pwd)"
export APPDIR="$(pwd)/${APP}.AppDir"

# Get the latest version of the AppImage helper functions,
# or use a fallback copy if not available:
if ! wget "https://github.com/probonopd/AppImages/raw/master/functions.sh" --output-document="./functions.sh"; then
    cp -a "${TRAVIS_BUILD_DIR}/ci/functions.sh" ./functions.sh || exit 1
fi

# Source the script:
. ./functions.sh

ver="git-$(date '+%Y%m%d_%H%M')"
ARCH="x86_64"
VERSION="${ver}"
mkdir -p ../out/ || exit 1
generate_appimage || exit 1
#generate_type2_appimage

pwd
ls ../out/*

# Upload the AppDir
transfer ../out/*

printf '%s\n' "" "The AppImage has been uploaded to the URL above." ""
