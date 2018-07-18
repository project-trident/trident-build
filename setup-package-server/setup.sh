#!/bin/sh
# Script for setting up a server to distribute package files
# ==================================
# NOTE: This does not setup the user account to access the system
#     ** You will need to setup that manually beforehand**
# ==================================

if [ `id -u`-ne 0 ] ; then
  echo "[ERROR] This script needs to run with root permissions"
  return 1
fi

#setup the base dirs that you want to use
data_dir="/data"
data_user="poseidon"
site_name="pkg.project-trident.org"

#Setup the data directory (ZFS)
if [ ! -d "${data_dir}" ] ; then
  #Get the zfs pool
  _pool=`zpool list -H | cut -w -f 1`
  #Make a dataset for this dir
  zfs create -o atime=off -o compression=on -o mountpoint="${data_dir}" ${_pool}${data_dir}
  chown ${data_user}:${data_user} "${data_dir}"
fi

# PACKAGES
req_pkg="nginx"
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

# nginx config
curdir=`dirname $0`
cp "${curdir}/pkg-nginx.conf" "/usr/local/etc/pkg-nginx.conf"
sed -i "" "s|%%SITE_NAME%%|${site_name}|g" /usr/local/etc/pkg-nginx.conf
sed -i "" "s|%%DATA_DIR%%|${data_dir}|g" /usr/local/etc/pkg-nginx.conf
sysrc "nginx_config=/usr/local/etc/pkg-nginx.conf"

# nginx service
if [ -e /sbin/rc-update ] ; then
  #TrueOS system (OpenRC)
  rc-update add nginx
else
  #FreeBSD system (rc.d)
  sysrc nginx_enable=yes"
fi
service nginx start
