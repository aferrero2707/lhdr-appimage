#!/usr/bin/env bash

rm -rf LuminanceHDR
git clone https://github.com/LuminanceHDR/LuminanceHDR.git
rm -rf LuminanceHDR/ci
cp -a ci LuminanceHDR
cd LuminanceHDR
docker run -it -v $(pwd):/sources -e "GIT_BRANCH=master" photoflow/docker-trusty-appimage-base bash #/sources/ci/appimage.sh
