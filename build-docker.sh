
DEPINST=0
BUILD=1
if [ x"$DEPINST" = "x1" ]; then

sudo add-apt-repository -y ppa:beineri/opt-qt58-trusty
sudo apt-get update
sudo apt-get install -y git wget g++ gettext intltool qt58base qt58svg qt58webengine qt58tools libtool autoconf automake make libexiv2-dev mesa-common-dev libalglib-dev libboost-all-dev libfftw3-dev libtiff5-dev libpng12-dev libopenexr-dev libgsl0-dev libcfitsio3-dev

fi

source /opt/qt58/bin/qt58-env.sh

if [ x"$BUILD" = "x1" ]; then

git clone https://github.com/LuminanceHDR/LuminanceHDR.git
cd LuminanceHDR
mkdir -p build
cd build
if [ ! -e LibRaw ]; then
export PKG_CONFIG_PATH=/zyx/lib/pkgconfig:${PKG_CONFIG_PATH}
export LD_LIBRARY_PATH=/zyx/lib:${LD_LIBRARY_PATH}
git clone https://github.com/LibRaw/LibRaw.git
cd LibRaw
autoreconf --install
./configure --prefix=/usr
make -j2 && sudo make install
cd ..
fi
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/zyx ..
make -j2 && sudo make install
cd ..

fi

#exit

mkdir -p appimage
cp /sources/appimage.sh appimage
export TRAVIS_BUILD_DIR=/sources
bash appimage/appimage.sh
