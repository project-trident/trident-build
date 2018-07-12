#!/bin/sh
#---------------------------------------------------------
# Script for creating a TrueOS distribution
# Written by Ken Moore <ken@ixsystems.com> : July 12, 2018
# Available under the 2-clause BSD license
#---------------------------------------------------------

#==========================
# Externally-set Environment variables
#==========================
# PKG_REPO_SIGNING_KEY : private key to use for signing packages
# PKGSIGNKEY: private key used to sign base packages
# -- Only setting one of these key variables will automatically use it for both base/ports packages
#==========================


#NOTE: the "${WORKSPACE}" variable is set by jenkins as the prefix for the repo checkout
#  The "CURDIR" method below should automatically catch/include the workspace in the path
CURDIR=$(dirname $0)

#Build Configuration
TRUEOS_MANIFEST=${CURDIR}/trident-master.json
CURDATE=`date -j "+%Y%m%d_%H_%M"`
ISONAME="trident-${CURDATE}"

#GitHub ports to use for build
GH_BASE_ORG="trueos"
GH_BASE_REPO="trueos"
GH_BASE_TAG="f85aa1c3b7c623b30642b8f53f49e3bfd1a614be"
#Note: The GitHub repo to fetch the ports tree from are set in the JSON manifest

#Build Server Settings (automatically determined: overwrite as needed)
SYS_CPU=`sysctl -n hw.ncpu`
MAX_THREADS=`expr ${SYS_CPU} - 1`
POUDRIERE_BASE=`basename -s ".json" "${TRUEOS_MANIFEST}"`
POUDRIERE_PORTS="trueos-mk-ports"

#Other Paths (generally static)
BASEDIR="${CURDIR}/base"
POUD_PKG_DIR="/usr/local/poudriere/data/packages/${POUDRIERE_BASE}-${POUDRIERE_PORTS}"
INTERNAL_RELEASE_BASEDIR="/usr/obj${WORKSPACE}"
INTERNAL_RELEASE_DIR="${INTERNAL_RELEASE_BASEDIR}/amd64.amd64/release"
if [ -n "${WORKSPACE}" ] ; then
  #Special dir for Jenkins artifacts
  ARTIFACTS_DIR="${WORKSPACE}/artifacts"
else
  #Create/use an artifacts dir in the current dir
  ARTIFACTS_DIR="${CURDIR}/artifacts"
fi


# Signing key simplifications for using the same key for base/ports
# If only one key is specified, use it for the other as well
if [ -n "${PKGSIGNKEY}" ] && [ -z "${PKG_REPO_SIGNING_KEY}" ] ; then
  PKG_REPO_SIGNING_KEY="${PKGSIGNKEY}"
elif [ -z "${PKGSIGNKEY}" ] && [ -n "${PKG_REPO_SIGNING_KEY}" ] ; then
  PKGSIGNKEY="${PKG_REPO_SIGNING_KEY}"
fi

#STAGES
checkout(){
  BASE_CACHE_DIR="/tmp/trueos-repo-cache"
  BASE_TAR="${BASE_CACHE_DIR}/${GH_BASE_ORG}_${GH_BASE_REPO}_${GH_BASE_TAG}.tgz"
  if [ ! -f "${BASE_TAR}" ] ; then
    if [ -d "${BASE_CACHE_DIR}" ] ; then
      #Got a different tag - clear the old files from the cache
      rm -f "${BASE_CACHE_DIR}/*.tgz"
    else
      mkdir -p "${BASE_CACHE_DIR}"
    fi
    base_url="https://github.com/${GH_BASE_ORG}/${GH_BASE_REPO}/tarball/${GH_BASE_TAG}"
    #NOTE: Fetch works, but seems slower than using curl
    echo "[INFO] Downloading Base Repo..."
    fetch --retry -o "${BASE_TAR}" "${base_url}"
    #curl -L "${base_url}" -o "${BASE_TAR}"
    if [ $? -ne 0 ] ; then
      echo "[ERROR] Could not download repository: ${base_url}"
      return 1
    fi
  fi

  # Now that we have the tarball, lets extract it to the base dir
  if [ -d "${BASEDIR}" ] ; then
   rm -rf "${BASEDIR}"
  fi
  mkdir -p "${BASEDIR}"
  #Note: GitHub archives always have things inside a single subdirectory in the archive (org-repo-tag)
  #  - need to ignore that dir path when extracting
  exho "[INFO] Extracting base repo..."
  tar -xf "${BASE_TAR}" -C "${BASEDIR}" --strip-components 1
}

clean_base(){
  echo "[INFO] Cleaning..."
  if [ -d "${BASEDIR}" ] ; then
    cd "${BASEDIR}"
    make clean > /dev/null
    cd release
    make clean > /dev/null
  fi
  if [ -d "${INTERNAL_RELEASE_BASEDIR}" ] ; then
    rm -rf "${INTERNAL_RELEASE_BASEDIR}"
  fi
  #always return 0 for cleaning
  return 0
}

make_world(){
  echo "[INFO] Building world..."
  cd "${BASEDIR}"
  make -j${MAX_THREADS} buildworld
}

make_kernel(){
  echo "[INFO] Building kernel..."
  cd "${BASEDIR}"
  make -j${MAX_THREADS} buildkernel
}

make_base_pkg(){
  #NOTE: This will use the PKGSIGNKEY environment variable to sign base packages
  echo "[INFO] Building base packages..."
  cd "${BASEDIR}"
  make -j${MAX_THREADS} packages
}

make_ports(){
  GH_PORTS="https://github.com/${GH_PORTS_ORG}/${GH_PORTS_REPO}"
  #NOTE: This will use the PKG_REPO_SIGNING_KEY environment variable to sign packages
  echo "[INFO] Building ports..."
  cd "${BASEDIR}/release"
  make poudriere
  if [$? -eq 0 ] && [ -n "${PKG_REPO_SIGNING_KEY}" ] ; then
    cd "${POUD_PKG_DIR}"
    echo "[INFO] Signing Packages..."
    pkg-static repo . "${PKG_REPO_SIGNING_KEY}"
  fi
}

make_release(){
  echo "[INFO] Building ISO..."
  #Remove old artifacts (if any)
  if [ -d "${ARTIFACTS_DIR}" ] ; then
    rm -rf "${ARTIFACTS_DIR}"
  fi
  cd "${BASEDIR}/release"
  make release
  if [ $? -eq 0 ] ; then
    mkdir -p "${ARTIFACTS_DIR}/repo"
    cp "${INTERNAL_RELEASE_DIR}/*.iso" "${ARTIFACTS_DIR}"
    cp "${INTERNAL_RELEASE_DIR}/*.txz" "${ARTIFACTS_DIR}"
    cp "${INTERNAL_RELEASE_DIR}/MANIFEST" "${ARTIFACTS_DIR}"
    if [ -f "${ARTIFACTS_DIR}/disk1.iso" ] ; then
      mv "${ARTIFACTS_DIR}/disk1.iso" "${ARTIFACTS_DIR}/${ISONAME}.iso"
    fi
    echo "[INFO] Artifact files located in: ${ARTIFACTS_DIR}"
  fi
}

make_all(){
  clean_base
  checkout
  make_world
  make_kernel
  make_base_pkg
  make_ports
  make_release
}

#===================
#  MAIN CODE
#===================

case $1 in
	all)
		make_all
		;;
	clean)
		clean_base
		;;
	checkout)
		checkout
		;;
	world)
		make_world
		;;
	kernel)
		make_kernel
		;;
	base)
		make_base
		;;
	ports)
		make_ports
		;;
	release)
		make_release
		;;
	*)
		echo "Unknown Option: $1"
		echo "Valid options: all, clean, checkout, world, kernel, base, ports, release"
		;;
esac
