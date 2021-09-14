#!/bin/bash
usage_exit() {
  echo "Usage: $0 [-h] openhsp_source_directory base_distro_iso_file" 1>&2
  echo "    openhsp_source_directory"
  echo "        the openhsp source path to be built in a raspberry pi. The dirname should be \`OpenHSP\`."
  echo ""
  echo "    base_distro_iso_file"
  echo "        the ISO file of raspbian or any other raspberry pi distributions on which openhsp is built."
  echo ""
  echo "Options:"
  echo "    -h"
  echo "        show this help."
  exit 1
}

while getopts h OPT
do
  case $OPT in
    h) usage_exit;
      ;;
    \?) usage_exit;
      ;;
  esac
done

shift $((OPTIND - 1))
if [ $# -ne 2 ]; then
  usage_exit;
fi

OPENHSP_SRC=$1
DISTRO_ISO_FILE=$2

set -u

if [ ${OPENHSP_SRC##*/} != OpenHSP/ ]; then
  OpenHSP source directory name should be `OpenHSP/`. Do not forget to put a slash `/`.
  usage_exit;
fi

set -x

truncate -s $((7800000000/512*512)) $DISTRO_ISO_FILE

MOUNT_POINT="./mnt"
LOOPDEV=$(losetup -f --show -P $DISTRO_ISO_FILE)

growpart $LOOPDEV 2

EXITCODE=$?
if [ $EXITCODE -ne 0 ] && [ $EXITCODE -ne 1 ]; then
  echo "growpart unexpectedly exited."
  exit $EXITCODE
fi

set -e

e2fsck -f ${LOOPDEV}p2 && resize2fs ${LOOPDEV}p2 

mkdir -p $MOUNT_POINT/boot
mount ${LOOPDEV}p1 $MOUNT_POINT/boot
mount ${LOOPDEV}p2 $MOUNT_POINT

# Copy OpenHSP source to raspbian fs
rm -rf $MOUNT_POINT/OpenHSP
cp -r $OPENHSP_SRC $MOUNT_POINT

MOUNT_SYSFD_TARGETS="$MOUNT_POINT/proc $MOUNT_POINT/sys $MOUNT_POINT/dev $MOUNT_POINT/dev/shm $MOUNT_POINT/dev/pts"
MOUNT_SYSFD_SRCS="proc sysfs devtmpfs tmpfs devpts"

umount_sysfds () {
  /bin/cp -f $MOUNT_POINT/etc/hosts.org $MOUNT_POINT/etc/hosts || /bin/true
  /bin/cp -f $MOUNT_POINT/etc/resolv.conf.org $MOUNT_POINT/etc/resolv.conf || /bin/true
  for i in $(echo $MOUNT_SYSFD_SRCS | wc -w); do
    SRC=$(echo $MOUNT_SYSFD_SRCS | cut -d " " -f $i)
    TARGET=$(echo $MOUNT_SYSFD_TARGETS | cut -d " " -f $i)
    umount $TARGET || /bin/true
  done
}

for i in $(echo $MOUNT_SYSFD_SRCS | wc -w); do
  SRC=$(echo $MOUNT_SYSFD_SRCS | cut -d " " -f $i)
  TARGET=$(echo $MOUNT_SYSFD_TARGETS | cut -d " " -f $i)
  mount -t $SRC $SRC $TARGET
done

cp -f $MOUNT_POINT/etc/hosts $MOUNT_POINT/etc/hosts.org
cp -f $MOUNT_POINT/etc/resolv.conf $MOUNT_POINT/etc/resolv.conf.org
cp -f /etc/hosts $MOUNT_POINT/etc/
cp -f /etc/resolv.conf $MOUNT_POINT/etc/resolv.conf
cp /usr/bin/qemu-arm-static $MOUNT_POINT/usr/bin/

LOCALE_CONF="LANG=ja_JP.UTF-8 LANGUAGE=ja_JP:en LC_CTYPE=ja_JP.UTF-8 LC_NUMERIC=ja_JP.UTF-8 LC_TIME=ja_JP.UTF-8 LC_COLLATE=ja_JP.UTF-8 LC_MONETARY=ja_JP.UTF-8 LC_MESSAGES=ja_JP.UTF-8 LC_PAPER=ja_JP.UTF-8 LC_NAME=ja_JP.UTF-8 LC_ADDRESS=ja_JP.UTF-8 LC_TELEPHONE=ja_JP.UTF-8 LC_MEASUREMENT=ja_JP.UTF-8 LC_IDENTIFICATION=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8"

if [ ! -e $MOUNT_POINT/initialized  ]; then
  chroot $MOUNT_POINT sh -c "$LOCALE_CONF apt update && $LOCALE_CONF apt install -y libgtk2.0-dev libglew-dev libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev libgles2-mesa-dev libegl1-mesa-dev"
  touch $MOUNT_POINT/initialized
fi

chroot $MOUNT_POINT sh -c "cd /OpenHSP; make clean; make -j$(nproc) -f makefile.raspbian"

umount_sysfds
umount mnt/boot mnt
losetup -d $LOOPDEV
