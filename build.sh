#!/bin/sh

set -e
set -u

if [ "`id -u`" = "0" ]; then
    echo "Please run this script as a regular user..."
    exit 1
fi

cd `dirname $0`
ENV_ROOT=`pwd`
. ./env.source

USAGE="Usage: `basename $0` [-h] -p NUM\n  -p NUM\t Set NUM jobs for make\n -h\t This help"

# Parse command line options.
while getopts hp: OPT; do
    case "$OPT" in
        h)
            echo $USAGE
            exit 0
            ;;
        v)
            echo "`basename $0` version 0.2"
            exit 0
            ;;
        p)
            JOBS=$OPTARG
            ;;
        \?)
            # getopts issues an error message
            echo $USAGE >&2
            exit 1
            ;;
    esac
done

# We want -p on our command line
if [ $# -eq 0 ]; then
    echo $USAGE >&2
    exit 1
fi


if [ -d $BUILD_DIR ]; then
    echo "*** STOP"
    echo "Remove $BUILD_DIR first..."
    exit 1
fi

if [ -d $TARGET_DIR ]; then
    echo "*** STOP"
    echo "Remove $TARGET_DIR first.."
    exit 1
fi

mkdir -p "$BUILD_DIR" "$TARGET_DIR"

# NOTE: this is a fetchurl parameter, nothing to do with the current script
#export TARGET_DIR_DIR="$BUILD_DIR"

echo "#### FFmpeg static build, by STVS SA / stone ####"
cd $BUILD_DIR
../fetchurl "http://www.tortall.net/projects/yasm/releases/yasm-1.2.0.tar.gz"
../fetchurl "http://www.imagemagick.org/download/delegates/zlib-1.2.5.tar.bz2"
../fetchurl "http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz"
../fetchurl "http://distfiles.macports.org/libpng/libpng-1.2.44.tar.bz2"
../fetchurl "http://downloads.xiph.org/releases/ogg/libogg-1.3.0.tar.gz"
../fetchurl "http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.2.tar.bz2"
../fetchurl "http://downloads.xiph.org/releases/theora/libtheora-1.1.1.tar.bz2"
../fetchurl "http://webm.googlecode.com/files/libvpx-v0.9.7-p1.tar.bz2"
../fetchurl "http://downloads.sourceforge.net/project/faac/faac-src/faac-1.28/faac-1.28.tar.bz2?use_mirror=auto"
../fetchurl "http://ftp.videolan.org/pub/x264/snapshots/x264-snapshot-20111108-2245-stable.tar.bz2"
../fetchurl "http://downloads.xvid.org/downloads/xvidcore-1.3.2.tar.gz"
../fetchurl "http://downloads.sourceforge.net/project/lame/lame/3.99/lame-3.99.1.tar.gz?use_mirror=auto"
../fetchurl "http://www.ffmpeg.org/releases/ffmpeg-0.8.6.tar.gz"


start_time=`date +%s`

echo "*** Building yasm ***"
cd "$BUILD_DIR/yasm-1.0.1"
./configure --prefix=$TARGET_DIR
make -j $JOBS && make install

echo "*** Building zlib ***"
cd "$BUILD_DIR/zlib-1.2.5"
./configure --prefix=$TARGET_DIR 
make -j $JOBS && make install

echo "*** Building bzip2 ***"
cd "$BUILD_DIR/bzip2-1.0.5"
make
make install PREFIX=$TARGET_DIR

echo "*** Building libpng ***"
cd "$BUILD_DIR/libpng-1.2.44"
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
make -j $JOBS && make install

# Ogg before vorbis
echo "*** Building libogg ***"
cd "$BUILD_DIR/libogg-1.2.0"
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
make -j $JOBS && make install

# Vorbis before theora
echo "*** Building libvorbis ***"
cd "$BUILD_DIR/libvorbis-1.3.1"
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
make -j $JOBS && make install

echo "*** Building libtheora ***"
cd "$BUILD_DIR/libtheora-1.1.1"
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
make -j $JOBS && make install

echo "*** Building livpx ***"
cd "$BUILD_DIR/libvpx-v0.9.7-p1"
./configure --prefix=$TARGET_DIR --disable-shared
make -j $JOBS && make install

echo "*** Building faac ***"
cd "$BUILD_DIR/faac-1.28"
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
# FIXME: gcc incompatibility, does not work with log()
sed -i -e "s|^char \*strcasestr.*|//\0|" common/mp4v2/mpeg4ip.h
make -j $JOBS && make install

echo "*** Building x264 ***"
cd "$BUILD_DIR/x264-snapshot-20111025-2245-stable"
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
make -j $JOBS && make install


echo "*** Building xvidcore ***"
cd "$BUILD_DIR/xvidcore/build/generic"
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
make -j $JOBS && make install
#rm $TARGET_DIR/lib/libxvidcore.so.*

echo "*** Building lame ***"
cd "$BUILD_DIR/lame-3.98.4"
./configure --prefix=$TARGET_DIR --enable-static --disable-shared
make -j $JOBS && make install

# FIXME: only OS-sepcific
rm -f "$TARGET_DIR/lib/*.dylib"
rm -f "$TARGET_DIR/lib/*.so"

# FFMpeg
echo "*** Building FFmpeg ***"
cd "$BUILD_DIR/ffmpeg-0.8"
./configure --prefix=${OUTPUT_DIR:-$TARGET_DIR} --extra-version=static --disable-debug --disable-shared --enable-static --extra-cflags=--static --disable-ffplay --disable-ffserver --disable-doc --enable-gpl --enable-pthreads --enable-postproc --enable-gray --enable-runtime-cpudetect --enable-libfaac --enable-libmp3lame --enable-libtheora --enable-libvorbis --enable-libx264 --enable-libxvid --enable-bzlib --enable-zlib --enable-nonfree --enable-version3 --enable-libvpx --disable-devices
make -j $JOBS && make install

end_time=`date +%s`

echo
echo "*****************************************"
echo "   Your \"static\" ffmpeg is now baked"
echo "          target/bin/ffmpeg"
echo "   execution time was `expr $end_time - $start_time` s."
echo "*****************************************"
echo
ldd $TARGET_DIR/bin/ffmpeg
echo
echo "*****************************************"
echo

