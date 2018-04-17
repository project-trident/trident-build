#!/bin/sh
####################################
# Script to fetch/build everything
# 
####################################

#Configuration knobs
base_repo="trueos/trueos"
base_branch_tag="trueos-master"
#  IMPORTANT: Make sure the key_files variable is pointing at the SSL keys to be used for signing all the packages
key_files=""


#Internal definitions
base_tarball="base.tgz"
base_dir="base"

###############
#  FUNCTIONS  #
###############
check_error(){
  #INPUTS: 1: return code ($?), 2: Text to be used if an error occured
  if [ $1 -ne 0 ] ; then
    echo "[ERROR] $2"
    exit 1
  fi
}

fetch_base(){
  base_url="https://github.com/${base_repo}/tarball/${base_branch_tag}"
  #NOTE: Fetch works, but is *much* slower than using curl
  #fetch --retry -o "${base_tarball}" "${base_url}"
  curl -L "${base_url}" -o "${base_tarball}"
}

extract_base(){
  if [ -d "${base_dir}" ] ; then
   rm -rf "${base_dir}"
  fi
  mkdir -p "${base_dir}"
  tar -xf "${base_tarball}" -C "${base_dir}"
}

build_base(){
  cd ${base_dir}
  make buildworld buildkernel
  make packages
  cd release && make release
}

###############
#  MAIN CODE  #
###############
tot=3 #total number of steps for the build routine

echo "[1/${tot}] Fetching base..."
fetch_base
check_error $? "Could not fetch base: ${base_repo}/${base_branch_tag}"

echo "[2/${tot}] Extracting base..."
extract_base
check_error $? "Could not extract base tarball"

echo "[3/${tot}] Building base..."
build_base
check_error $? "Could not build base"

echo "[SUCCESS]"
exit 0
