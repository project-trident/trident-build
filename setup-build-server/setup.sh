#!/bin/sh
# Script for setting up a server to run TrueOS distro builds
# ===============================
# NOTE: This does not setup the user account for jenkins to access the system
#     ** You will need to setup that manually **
# ===============================

if [ `id -u`-ne 0 ] ; then
  echo "[ERROR] This script needs to run with root permissions"
  return 1
fi

# PACKAGES
req_pkg="jenkins rsync git"
for _pkg in ${req_pkg}
do
  pkg info -e ${_pkg}
  if [ $? -ne 0 ] ; then
  need_pkg="${need_pkg} ${_pkg}"
  fi
done

if [ -n "${need_pkg}" ] ; then
  pkg install -y ${need_pkg}
fi

# TUNING
# vfs.zfs.arc_max : Set this to a few GB (<10GB typically) so the cache is used most of the time for builds
# vfs.zfs.vdev.cache.size : Set this to a few MB (<1GB typically) so there is an extra (small) memory cache
#                                        - This small cache seems to speed up the large port builds considerably
tuning="vfs.zfs.arc_max=\"8G\" vfs.zfs.vdev.cache.size=\"512M\""
for _tune in ${tuning}
do
  grep -q '${_tune}' /boot/loader.conf
  if [ $? -ne 0 ] ; then
    echo ${_tune} >> /boot/loader.conf
done
