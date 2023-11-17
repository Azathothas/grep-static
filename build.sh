#!/bin/bash
set -e
export MAKEFLAGS="-j$(nproc)"

# WITH_UPX=1

grep_version="latest"

platform="$(uname -s)"
platform_arch="$(uname -m)"

if [ -x "$(which apt 2>/dev/null)" ]
    then
        apt update && apt install -y \
            build-essential clang pkg-config git autoconf libtool \
            gettext autopoint po4a libpcre2-dev
fi

[ "$grep_version" == "latest" ] && \
  grep_version="$(curl -s https://ftp.gnu.org/gnu/grep/|tac|\
                       grep -om1 'grep-.*\.tar\.xz'|cut -d'>' -f2|sed 's|grep-||g;s|.tar.xz||g')"

if [ -d build ]
    then
        echo "= removing previous build directory"
        rm -rf build
fi

if [ -d release ]
    then
        echo "= removing previous release directory"
        rm -rf release
fi

# create build and release directory
mkdir build
mkdir release
pushd build

# download tarballs
echo "= downloading grep v${grep_version}"
curl -LO https://ftp.gnu.org/gnu/grep/grep-${grep_version}.tar.gz

echo "= extracting grep"
tar -xf grep-${grep_version}.tar.gz

if [ "$platform" == "Linux" ]
    then
        export CFLAGS="-static"
        export LDFLAGS='--static'
    else
        echo "= WARNING: your platform does not support static binaries."
        echo "= (This is mainly due to non-static libc availability.)"
fi

echo "= building grep"
pushd grep-${grep_version}
env CFLAGS="$CFLAGS -g -O2 -Os -ffunction-sections -fdata-sections" \
    LDFLAGS="$LDFLAGS -Wl,--gc-sections" ./configure --enable-perl-regexp
make DESTDIR="$(pwd)/install" install
popd # grep-${grep_version}

popd # build

shopt -s extglob

echo "= extracting grep binary"
mv build/grep-${grep_version}/install/usr/local/bin/* release 2>/dev/null

echo "= striptease"
strip -s -R .comment -R .gnu.version --strip-unneeded release/grep 2>/dev/null

if [[ "$WITH_UPX" == 1 && -x "$(which upx 2>/dev/null)" ]]
    then
        echo "= upx compressing"
        for file in release/*
          do
              upx -9 --best "$file" 2>/dev/null
        done
fi

echo "= create release tar.xz"
[ -n "$(ls -A release/ 2>/dev/null)" ] && \
tar --xz -acf grep-static-v${grep_version}-${platform_arch}.tar.xz release
# cp grep-static-*.tar.xz /root 2>/dev/null

if [ "$NO_CLEANUP" != 1 ]
    then
        echo "= cleanup"
        rm -rf release build
fi

echo "= grep v${grep_version} done"
