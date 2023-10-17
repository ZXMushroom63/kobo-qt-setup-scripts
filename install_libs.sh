#!/bin/bash
set -e

LIBDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# path to cross tools root; another popular path is ${HOME}/x-tools
CROSS_TC_PATH=${SYSROOT:=${HOME}/x-tools}

CROSS_TC=${CROSS_TC:=arm-kobo-linux-gnueabihf}

SYSROOT=${SYSROOT:=${CROSS_TC_PATH}/${CROSS_TC}/${CROSS_TC}/sysroot}
CROSS=${CROSS:=${CROSS_TC_PATH}/${CROSS_TC}/bin/${CROSS_TC}}
PREFIX=${PREFIX:=${SYSROOT}/usr}

PARALLEL_JOBS=$(($(getconf _NPROCESSORS_ONLN 2> /dev/null || sysctl -n hw.ncpu 2> /dev/null || echo 0) + 1))

sudo echo "==="

export AR=${CROSS}-ar
export AS=${CROSS}-as
export CC=${CROSS}-gcc
export CXX=${CROSS}-g++
export LD=${CROSS}-ld
export RANLIB=${CROSS}-ranlib

export PKG_CONFIG_PATH=""
export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig"
export PKG_CONFIG="pkg-config"


CFLAGS_BASE="-O3 -march=armv7-a -mtune=cortex-a8 -mfpu=neon -mfloat-abi=hard -mthumb -pipe -D__arm__ -D__ARM_NEON__ -fPIC -fpie -pie -fno-omit-frame-pointer -funwind-tables -Wl,--no-merge-exidx-entries"

CFLAGS_OPT1="${CFLAGS_BASE} -ftree-vectorize -ffast-math -frename-registers -funroll-loops "

CFLAGS_LTO="${CFLAGS_OPT1} -fdevirtualize-at-ltrans -flto=5"

get_clean_repo()
{
    mkdir -p ${LIBDIR}/libs
    cd ${LIBDIR}/libs
    git clone $REPO $LOCALREPO || git -C $LOCALREPO pull
    cd ${LIBDIR}/libs/${LOCALREPO}
    git reset --hard
    git clean -fdx
    if test -f ${LIBDIR}/patches/${LOCALREPO}.patch; then
        git apply ${LIBDIR}/patches/${LOCALREPO}.patch
    fi
}

get_zlib_ng_repo()
{
    mkdir -p ${LIBDIR}/libs
    cd ${LIBDIR}/libs
    git clone -b "2.1.x" $REPO $LOCALREPO || git -C $LOCALREPO pull
    cd ${LIBDIR}/libs/${LOCALREPO}
    git reset --hard
    git clean -fdx
    if test -f ${LIBDIR}/patches/${LOCALREPO}.patch; then
        git apply ${LIBDIR}/patches/${LOCALREPO}.patch
    fi
}

# build zlib-ng without LTO
export CFLAGS=$CFLAGS_OPT1

#zlib-ng
#patch: zlib configure line 314: ARCH=armv7-a
REPO=https://github.com/zlib-ng/zlib-ng
LOCALREPO=zlib-ng
get_zlib_ng_repo

sudo ./configure --prefix=${PREFIX} --zlib-compat
sudo make -j$PARALLEL_JOBS && sudo make install

export CFLAGS=$CFLAGS_LTO


#libb2
REPO=https://github.com/BLAKE2/libb2
LOCALREPO=libb2
get_clean_repo
sh autogen.sh --prefix=${PREFIX} --host=${CROSS_TC}
sudo ./configure --prefix=${PREFIX} --host=${CROSS_TC}
sudo make -j$PARALLEL_JOBS && sudo make install


#zstd
REPO=https://github.com/facebook/zstd
LOCALREPO=zstd
get_clean_repo

mkdir -p ${LIBDIR}/libs/${LOCALREPO}/build/cmake/build
cd ${LIBDIR}/libs/${LOCALREPO}/build/cmake/build
cmake -D ADDITIONAL_CXX_FLAGS="-lrt" -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_TOOLCHAIN_FILE=${LIBDIR}/${CROSS_TC}.cmake -DENABLE_NEON=ON -DNEON_INTRINSICS=ON ..
sudo make -j$PARALLEL_JOBS && sudo make install


#openssl
REPO="--single-branch --branch openssl-3.0 https://github.com/openssl/openssl"
LOCALREPO=openssl-3.0
get_clean_repo

sudo ./Configure linux-elf no-comp no-tests no-asm shared --prefix=${PREFIX} --openssldir=${PREFIX}
sudo make -j$PARALLEL_JOBS && sudo make install_sw

#pnglib
REPO=git://git.code.sf.net/p/libpng/code
LOCALREPO=pnglib
get_clean_repo

sudo ./configure --prefix=${PREFIX} --host=${CROSS_TC} --enable-arm-neon=yes
sudo make -j$PARALLEL_JOBS && sudo make install


#libjpeg-turbo
#needed: toolchain.cmake
REPO=https://github.com/libjpeg-turbo/libjpeg-turbo
LOCALREPO=libjpeg-turbo
get_clean_repo

mkdir -p ${LIBDIR}/libs/${LOCALREPO}/build
cd ${LIBDIR}/libs/${LOCALREPO}/build
sudo cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_TOOLCHAIN_FILE=${LIBDIR}/${CROSS_TC}.cmake -DENABLE_NEON=ON -DNEON_INTRINSICS=ON ..
sudo make -j$PARALLEL_JOBS && sudo make install

#expat
REPO=https://github.com/libexpat/libexpat
LOCALREPO=expat
get_clean_repo

cd ${LIBDIR}/libs/${LOCALREPO}/expat
./buildconf.sh
sudo ./configure --prefix=${PREFIX} --host=${CROSS_TC}
sudo make -j$PARALLEL_JOBS && sudo make install

#pcre
REPO=https://github.com/rurban/pcre
LOCALREPO=pcre
get_clean_repo

./autogen.sh
sudo ./configure --prefix=${PREFIX} --host=${CROSS_TC} --enable-pcre2-16 --enable-jit --with-sysroot=${SYSROOT}
sudo make -j$PARALLEL_JOBS && sudo make install


#libfreetype without harfbuzz
REPO=https://github.com/freetype/freetype
LOCALREPO=freetype
get_clean_repo

sh autogen.sh
sudo ./configure --prefix=${PREFIX} --host=${CROSS_TC} --enable-shared=yes --enable-static=yes --without-bzip2 --without-brotli --without-harfbuzz --without-png --disable-freetype-config
sudo make -j$PARALLEL_JOBS && sudo make install


#harfbuzz
REPO=https://github.com/harfbuzz/harfbuzz
LOCALREPO=harfbuzz
get_clean_repo

sh autogen.sh --prefix=${PREFIX} --host=${CROSS_TC} --enable-shared=yes --enable-static=yes --without-coretext --without-fontconfig --without-uniscribe --without-cairo --without-glib  --without-gobject --without-graphite2 --without-icu --disable-introspection --with-freetype
#./configure --prefix=${PREFIX} --host=${CROSS_TC} --enable-shared=yes --enable-static=yes --without-coretext --without-fontconfig --without-uniscribe --without-cairo --without-glib  --without-gobject --without-graphite2 --without-icu --disable-introspection --with-freetype
sudo make -j$PARALLEL_JOBS && sudo make install


#libfreetype with harfbuzz
REPO=https://github.com/freetype/freetype
LOCALREPO=freetype
get_clean_repo

sh autogen.sh 
sudo ./configure --prefix=${PREFIX} --host=${CROSS_TC} --enable-shared=yes --enable-static=yes --without-bzip2 --without-brotli --with-harfbuzz --with-png --disable-freetype-config
sudo make -j$PARALLEL_JOBS && sudo make install
