#!/bin/bash
set -e

LIBDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

CROSS_TC=${CROSS_TC:=arm-kobo-linux-gnueabihf}

SYSROOT=${SYSROOT:=/home/${USER}/x-tools/${CROSS_TC}/${CROSS_TC}/sysroot}

GDBDIR=${LIBDIR}/libs/gdb-10.2

URL=http://ftp.gnu.org/gnu/gdb/gdb-10.2.tar.xz

mkdir -p ${LIBDIR}/libs
wget -c ${URL} -O - | tar -xJ -C ${LIBDIR}/libs

#gdb
cd ${GDBDIR}
mkdir -p build-gdb
cd build-gdb
rm -rf ./*
../configure --prefix=/home/${USER}/x-tools/${CROSS_TC} --target=${CROSS_TC}
make -j5 && make install


#gdb-server
export CFLAGS="-O3 -march=armv7-a -mtune=cortex-a8 -mfpu=neon -mfloat-abi=hard -mthumb -pipe -D__arm__ -D__ARM_NEON__ -fPIC -fno-omit-frame-pointer -funwind-tables -Wl,--no-merge-exidx-entries"
export LDFLAGS="-static-libstdc++ -static-libgcc"

cd ${GDBDIR}
mkdir -p build-gdbserver
cd build-gdbserver
rm -rf ./*

../configure --prefix=${SYSROOT}/usr --enable-gdbserver --host=${CROSS_TC} --disable-inprocess-agent  --disable-gdb
make all-gdbserver
make install-gdbserver
