#!/bin/bash
set -ex

MOUNT_POINT="./mnt"
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

umount_sysfds
umount mnt/boot mnt
losetup -d $(losetup | grep 2018-04-18-raspbian-stretch.img | awk '{print $1}')
