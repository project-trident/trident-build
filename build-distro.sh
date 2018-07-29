#!/bin/sh
#---------------------------------------------------------
# Script for creating a TrueOS distribution
# Written by Ken Moore <ken@ixsystems.com> : July 12-13, 2018
# Available under the 2-clause BSD license
#---------------------------------------------------------

#==========================
# Optional Externally-set Environment variables
#==========================
# PKG_REPO_SIGNING_KEY : private key to use for signing packages
# PKGSIGNKEY: private key used to sign base packages
#    Only setting one of these key variables will automatically use it for both base/ports packages
# TRUEOS_MANIFEST: file path to the JSON manifest file
#    This may also be passed into the script as input #2 (build-distro.sh all "/path/to/my/manifest.json")
# MAX_THREADS: Number of threads to use when building base/packages (ports options in JSON manifest)
#    This is automatically set to the current number of CPU's (sysctl hw.ncpu) - 1 
#==========================


#Determine JSON Build Configuration File
if [ -z "${TRUEOS_MANIFEST}" ] ; then
  if [ -n "${2}" ] ; then
    TRUEOS_MANIFEST=${2}
  else
    echo "[ERROR] Unable to determine TrueOS Manifest file"
    return 1
  fi
fi
#Ensure the JSON manifest exists and is an absolute path
# - (since later stages of the build will be in different dirs)
if [ ! -f "${TRUEOS_MANIFEST}" ] ; then
  echo "[ERROR] Specified manifest cannot be found: ${TRUEOS_MANIFEST}"
fi
TRUEOS_MANIFEST=`realpath -q "${TRUEOS_MANIFEST}"`

#Build Server Settings (automatically determined: overwrite as needed)
if [ -z "${MAX_THREADS}" ] ; then
  SYS_CPU=`sysctl -n hw.ncpu`
  if [ ${SYS_CPU} -le 1 ] ; then
    #Only 1 CPU - cannot go lower than this
    MAX_THREADS=${SYS_CPU}
  else
    #Max-1 by default
    MAX_THREADS=`expr ${SYS_CPU} - 1`
  fi
fi

export POUDRIERE_BASE=`basename -s ".json" "${TRUEOS_MANIFEST}"`
export POUDRIERE_PORTS=`jq -r '."ports-branch"' "${TRUEOS_MANIFEST}"`

#NOTE: the "${WORKSPACE}" variable is set by jenkins as the prefix for the repo checkout
#  The "CURDIR" method below should automatically catch/include the workspace in the path
CURDIR=$(dirname $0)

#Other Paths (generally static)
BASEDIR="${CURDIR}/base"
POUD_PKG_DIR="/usr/local/poudriere/data/packages/${POUDRIERE_BASE}-${POUDRIERE_PORTS}"
INTERNAL_RELEASE_BASEDIR="/usr/obj${BASEDIR}"
INTERNAL_RELEASE_DIR="${INTERNAL_RELEASE_BASEDIR}/amd64.amd64/release"
INTERNAL_RELEASE_REPODIR="${INTERNAL_RELEASE_BASEDIR}/amd64.amd64/repo"

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
  GH_BASE_ORG=`jq -r '."base-github-org"' "${TRUEOS_MANIFEST}"`
  GH_BASE_REPO=`jq -r '."base-github-repo"' "${TRUEOS_MANIFEST}"`
  GH_BASE_TAG=`jq -r '."base-github-tag"' "${TRUEOS_MANIFEST}"`
  BASE_CACHE_DIR="/tmp/trueos-repo-cache"
  BASE_TAR="${BASE_CACHE_DIR}/${GH_BASE_ORG}_${GH_BASE_REPO}_${GH_BASE_TAG}.tgz"
  if [ ! -f "${BASE_TAR}" ] ; then
    if [ -d "${BASE_CACHE_DIR}" ] ; then
      #Got a different tag - clear the old files from the cache
      rm -f "${BASE_CACHE_DIR}/*.tgz"
    else
      mkdir -p "${BASE_CACHE_DIR}"
    fi
    BASE_URL="https://github.com/${GH_BASE_ORG}/${GH_BASE_REPO}/tarball/${GH_BASE_TAG}"
    #NOTE: Fetch works, but seems slower than using curl
    echo "[INFO] Downloading Base Repo..."
    fetch --retry -o "${BASE_TAR}" "${BASE_URL}"
    #curl -L "${base_url}" -o "${BASE_TAR}"
    if [ $? -ne 0 ] ; then
      echo "[ERROR] Could not download repository: ${BASE_URL}"
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
  echo "[INFO] Extracting base repo..."
  tar -xf "${BASE_TAR}" -C "${BASEDIR}" --strip-components 1
}

clean_base(){
  echo "[INFO] Cleaning..."
  if [ -d "${BASEDIR}" ] ; then
    #Just remove the dir - running "make clean" in the source tree takes *forever*
    # - faster to just remove and re-create (checkout)
    rm -rf "${BASEDIR}"
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
  if [ $? -ne 0 ] ; then
    echo "[ERROR] Could not build TrueOS world"
    return 1
  fi
}

make_kernel(){
  echo "[INFO] Building kernel..."
  cd "${BASEDIR}"
  make -j${MAX_THREADS} buildkernel
  if [ $? -ne 0 ] ; then
    echo "[ERROR] Could not build TrueOS kernel"
    return 1
  fi
}

make_base_pkg(){
  #NOTE: This will use the PKGSIGNKEY environment variable to sign base packages
  echo "[INFO] Building base packages..."
  #Quick check for the *other* signing key variable
  if [ -z "${PKGSIGNKEY}" ] && [ -n "${PKG_REPO_SIGNING_KEY}" ] ; then
    PKGSIGNKEY="${PKG_REPO_SIGNING_KEY}"
  fi
  #Remove any old package repo dir
  if [ -d "${INTERNAL_RELEASE_REPODIR}" ] ; then
    rm -rf "${INTERNAL_RELEASE_REPODIR}"
  fi
  cd "${BASEDIR}"
  make -j${MAX_THREADS} packages
  if [ $? -ne 0 ] ; then
    echo "[ERROR] Could not build TrueOS base packages"
    return 1
  fi
}

make_ports(){
  #NOTE: This will use the PKG_REPO_SIGNING_KEY environment variable to sign packages
  #Quick check for the "other" signing key variable
  if [ -n "${PKGSIGNKEY}" ] && [ -z "${PKG_REPO_SIGNING_KEY}" ] ; then
    PKG_REPO_SIGNING_KEY="${PKGSIGNKEY}"
  fi
  echo "[INFO] Building ports..."
  cd "${BASEDIR}/release"
  make poudriere
  if [ $? -eq 0 ] && [ -n "${PKG_REPO_SIGNING_KEY}" ] ; then
    cd "${POUD_PKG_DIR}"
    echo "[INFO] Signing Packages..."
    pkg-static repo . "${PKG_REPO_SIGNING_KEY}"
    if [ $? -ne 0 ] ; then
      echo "[ERROR] Could not sign TrueOS packages"
      return 1
    fi
  else
    echo "[ERROR] Could not build TrueOS ports"
    return 1
  fi
}

make_release(){
  echo "[INFO] Building ISO..."
  #Determine the ISO name based on the JSON manifest
  local CURDATE. ISOBASE, ISONAME
  CURDATE=`date -j "+%Y%m%d_%H_%M"`
  if [ "$(jq -r '."iso-name" | length' ${TRUEOS_MANIFEST})" != "0" ] ; then
    ISOBASE=`jq -r '."iso-name"' ${TRUEOS_MANIFEST}`
  else
    ISOBASE=`basename -s ".json" "${TRUEOS_MANIFEST}"`
  fi
  ISONAME="${ISOBASE}-${CURDATE}"

  #Remove old artifacts (if any)
  if [ -d "${ARTIFACTS_DIR}" ] ; then
    rm -rf "${ARTIFACTS_DIR}"
  fi
  cd "${BASEDIR}/release"
  make release
  if [ $? -eq 0 ] ; then
    mkdir -p "${ARTIFACTS_DIR}"
    cp "${INTERNAL_RELEASE_DIR}/*.iso" "${ARTIFACTS_DIR}/."
    if [ $? -ne 0 ] ; then
      echo "[WARNING] ISO files not found in dir: ${INTERNAL_RELEASE_DIR}"
    fi
    cp "${INTERNAL_RELEASE_DIR}/*.txz" "${ARTIFACTS_DIR}/."
    if [ $? -ne 0 ] ; then
      echo "[WARNING] TXZ files not found in dir: ${INTERNAL_RELEASE_DIR}"
    fi
    cp "${INTERNAL_RELEASE_DIR}/MANIFEST" "${ARTIFACTS_DIR}/."
    if [ $? -ne 0 ] ; then
      echo "[WARNING] MANIFEST file not found in dir: ${INTERNAL_RELEASE_DIR}"
    fi
    if [ -f "${ARTIFACTS_DIR}/disc1.iso" ] ; then
      mv "${ARTIFACTS_DIR}/disc1.iso" "${ARTIFACTS_DIR}/${ISONAME}.iso"
    fi
    if [ "$(ls -A ${ARTIFACTS_DIR})" ] ; then
      #Got artifact files
      echo "[INFO] Artifact files located in: ${ARTIFACTS_DIR}"
    else
      #No artifact files
      echo "[ERROR] No files could be artifacted!"
      _tmp=`ls -l "${INTERNAL_RELEASE_DIR}"`
      echo "Internal Release Dir contents:\\n${_tmp}"
      return 1
    fi
  else
    echo "[ERROR] Could not build TrueOS ISO and other artifacts"
    return 1
  fi
}

make_pkg_manifest(){
  echo "[INFO] Creating package manifest..."
  #Note: This will **replace** the manifest info in the file!!
  _pkgdir="${POUD_PKG_DIR}/All"
  _pkgfile="${ARTIFACTS_DIR}/pkg.list"

  #Remove the old file if it exists
  if [ -e "${_pkgfile}" ] ; then
    rm "${_pkgfile}"
  fi
  
  for _line in `find "${_pkgdir}" -depth 1 -name "*.txz" | sort`
  do
    #Cleanup the individual line (directory, suffix)
    _line=$(echo ${_line} | rev | cut -d "/" -f 1| rev | sed "s|.txz||g")
    #Make sure it is a valid package name - otherwise skip it
    case "${_line}" in
	fbsd-distrib) continue ;;
	*-*) ;;
	*) continue ;;
    esac
    #Grab the version tag (ignore the first word - name might start with a number)
    _version=$(echo ${_line} | cut -d '-' -f 2-12 | rev | cut -d '-' -f 1-2 | rev)
    #check that the version string starts with a number, otherwise only use the last "-" section
    _tmp=$(echo ${_version} | egrep '^[0-9]+')
    if [ -z "${_tmp}" ] ; then
      _version=$(echo ${_line} | rev | cut -d '-' -f 1 | rev)
    fi
    _name=$(echo ${_line} | sed "s|-${_version}||g")
    echo "${_name} : ${_version}" >> ${_pkgfile}
    #echo "Name: ${_name}  : Version: ${_version}"
    #echo "  -raw line: ${line}"
  done
  #cleanup the temporary variables
  unset _pkgdir
  unset _pkgfile
  unset _line
  unset _name
  unset _version
  unset _tmp
}

make_all(){
  clean_base
  if [ $? -eq 0 ] ; then
    checkout
  else
    return 1; 
  fi
  if [ $? -eq 0 ] ; then
    make_world
  else
    return 1; 
  fi
  if [ $? -eq 0 ] ; then
    make_kernel
  else
    return 1; 
  fi
  if [ $? -eq 0 ] ; then
    make_base_pkg
  else
    return 1; 
  fi
  if [ $? -eq 0 ] ; then
    make_ports
  else
    return 1; 
  fi
  if [ $? -eq 0 ] ; then
    make_release
  else
    return 1; 
  fi
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
		make_base_pkg
		;;
	ports)
		make_ports
		;;
	release)
		make_release
		;;
	manifest)
		make_pkg_manifest
		;;
	*)
		echo "Unknown Option: $1"
		echo "Valid options: all, clean, checkout, world, kernel, base, ports, release, manifest"
		;;
esac
