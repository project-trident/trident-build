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

#NOTE: the "${WORKSPACE}" variable is set by jenkins as the prefix for the repo checkout
#  The "CURDIR" method below should automatically catch/include the workspace in the path
CURDIR=$(dirname $0)

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
  return 1
fi
export TRUEOS_MANIFEST=`realpath -q "${TRUEOS_MANIFEST}"`
_manifest_version=`jq -r '."version"' ${TRUEOS_MANIFEST}`
if [ -z "${_manifest_version}" ] ; then
  echo "[ERROR] Could not read build manifest! ${TRUEOS_MANIFEST}"
  return 1
fi
#Also set the TRUEOS_VERSION environment variable as needed
if [ "$(jq -r '."os_version" | length' ${TRUEOS_MANIFEST})" != "0" ] ; then
  export TRUEOS_VERSION=`jq -r '."os_version"' ${TRUEOS_MANIFEST}`
fi

#Perform any directory replacements in the manifest as needed
grep -q "%%PWD%%" "${TRUEOS_MANIFEST}"
if [ $? -eq 0 ] ; then
  echo "Replacing PWD paths in TrueOS Manifest..."
  cp "${TRUEOS_MANIFEST}" "${TRUEOS_MANIFEST}.orig"
  sed -i '' "s|%%PWD%%|${CURDIR}|g" "${TRUEOS_MANIFEST}"
fi

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
export POUDRIERE_PORTS="current"

#Other Paths (generally static)
BASEDIR="/usr/src_tmp"
PORTSDIR="/usr/ports_tmp"
POUD_PKG_DIR="/usr/local/poudriere/data/packages/${POUDRIERE_BASE}-${POUDRIERE_PORTS}"
INTERNAL_RELEASE_BASEDIR="/usr/obj${BASEDIR}"
INTERNAL_RELEASE_PKGDIR="${INTERNAL_RELEASE_BASEDIR}/pkgset"
INTERNAL_RELEASE_DIR="${INTERNAL_RELEASE_BASEDIR}/amd64.amd64/release"
INTERNAL_RELEASE_REPODIR="${INTERNAL_RELEASE_BASEDIR}/repo"
INTERNAL_RELEASE_OBJDIR="${INTERNAL_RELEASE_BASEDIR}/amd64.amd64"

if [ -n "${WORKSPACE}" ] ; then
  #Special dir for Jenkins artifacts
  ARTIFACTS_DIR="${WORKSPACE}/artifact-iso"
  PKG_RELEASE_PORTS="${WORKSPACE}/artifact-pkg"
  PKG_RELEASE_BASE="${WORKSPACE}/artifact-pkg-base"
else
  #Create/use an artifacts dir in the current dir
  if [ $CURDIR == "." ] ; then
      artifactDir=`readlink -f $CURDIR`
  else
      artifactDir="$CURDIR"	  
  fi 	  
  ARTIFACTS_DIR="${artifactDir}/artifact-iso"

  PKG_RELEASE_PORTS="${CURDIR}/artifact-pkg"
  PKG_RELEASE_BASE="${CURDIR}/artifact-pkg-base"
fi


# Signing key simplifications for using the same key for base/ports
# If only one key is specified, use it for the other as well
if [ -n "${PKGSIGNKEY}" ] && [ -z "${PKG_REPO_SIGNING_KEY}" ] ; then
  PKG_REPO_SIGNING_KEY="${PKGSIGNKEY}"
elif [ -z "${PKGSIGNKEY}" ] && [ -n "${PKG_REPO_SIGNING_KEY}" ] ; then
  PKGSIGNKEY="${PKG_REPO_SIGNING_KEY}"
fi

#Quick function for putting a variable/value combination into a JSON file
add_to_json_str(){
  #Inputs:
  # $1 : Variable name
  # $2 : Value (string)
  # $3 : json file
  if [ ! -e "${3}" ] ; then
    #touch "${3}"
    echo "{}" >> "${3}"
  fi
  val=$(echo $2 | sed 's|"||g'| xargs echo -n)
  jq '. += {"'${1}'": "'"${val}"'"}' "${3}" > "${3}.new"
  mv "${3}.new" "${3}"
}

validate_portcat_makefile(){
  #Inputs:
  # $1 : makefile directory
  origdir=`pwd`
  cd "$1"
  comment="`cat Makefile | grep 'COMMENT ='`"
  echo "# \$FreeBSD\$
#

$comment
" > Makefile.tmp

  for d in `ls`
  do
    if [ "$d" = ".." ]; then continue ; fi
    if [ "$d" = "." ]; then continue ; fi
    if [ "$d" = "Makefile" ]; then continue ; fi
    if [ ! -f "$d/Makefile" ]; then continue ; fi
    echo "    SUBDIR += $d" >> Makefile.tmp
  done
  echo "" >> Makefile.tmp
  echo ".include <bsd.port.subdir.mk>" >> Makefile.tmp
  mv Makefile.tmp Makefile

  cd "${origdir}"
}

validate_port_makefile(){
  #Inputs:
  # $1 : makefile directory
  # $2 : Name of new port category
  origdir=`pwd`
  cd "${PORTSDIR}"
  for d in `ls`
  do
    if [ "$d" = ".." ]; then continue ; fi
    if [ "$d" = "." ]; then continue ; fi
    if [ ! -f "$d/Makefile" ]; then continue ; fi
    grep -q "SUBDIR += ${d}" Makefile
    if [ $? -ne 0 ] && [ "${d}" != "${2}" ] ; then continue ; fi
    echo "SUBDIR += $d" >> Makefile.tmp
  done
  echo "" >> Makefile.tmp
  #Now strip out the subdir info from the original Makefile
  cp Makefile Makefile.skel
  sed -i '' "s|SUBDIR += lang|%%TMP%%|g" Makefile.skel
  cat Makefile.skel | grep -v "SUBDIR +=" > Makefile.skel.2
  mv Makefile.skel.2 Makefile.skel
  #Insert the new subdir list into the skeleton file and replace the original
  awk '/%%TMP%%/{system("cat Makefile.tmp");next}1' Makefile.skel > Makefile
  #Now cleanup the temporary files
  rm Makefile.tmp Makefile.skel
  cd "${origdir}"
}

add_cat_to_ports(){
  #Inputs:
  # $1 : category name
  # $2 : local path to dir
  echo "[INFO] Adding overlay category to ports tree: ${1}"
  #Copy the dir to the ports tree
  if [ -e "${PORTSDIR}/${1}" ] ; then
    rm -rf "${PORTSDIR}/${1}"
  fi
  cp -R "$2" "${PORTSDIR}/${1}"
  #Verify that the Makefile for the new category is accurate
  validate_portcat_makefile "${PORTSDIR}/${1}"
  #Enable the directory in the top-level Makefile
  validate_port_makefile "${1}"
}

add_port_to_ports(){
  #Inputs:
  # $1 : port (category/origin)
  # $2 : local path to dir
  echo "[INFO] Adding overlay port to ports tree: ${1}"
  #Copy the dir to the ports tree
  if [ -e "${PORTSDIR}/${1}" ] ; then
    rm -rf "${PORTSDIR}/${1}"
  fi
  cp -R "$2" "${PORTSDIR}/${1}"
  #Verify that the Makefile for the category includes the port
  validate_portcat_makefile "${PORTSDIR}/${1}/.."
}

apply_ports_overlay(){
  num=`jq -r '."ports-overlay" | length' "${TRUEOS_MANIFEST}"`
  if [ "${num}" = "null" ] || [ -z "${num}" ] ; then
    #nothing to do
    return 0
  fi
  i=0
  while [ ${i} -lt ${num} ]
  do
    _type=`jq -r '."ports-overlay"['${i}'].type' "${TRUEOS_MANIFEST}"`
    _name=`jq -r '."ports-overlay"['${i}'].name' "${TRUEOS_MANIFEST}"`
    _path=`jq -r '."ports-overlay"['${i}'].local_path' "${TRUEOS_MANIFEST}"`
    if [ "${_type}" = "category" ] ; then
      add_cat_to_ports "${_name}" "${_path}"
    elif [ "${_type}" = "port" ] ; then
      add_port_to_ports "${_name}" "${_path}"
    else
      echo "[WARNING] Unknown port overlay type: ${_type} (${_name})"
    fi
    i=`expr ${i} + 1`
  done
  return 0
}

check_github_tag(){
  #Inputs: 1: github tag to check
  LC_ALL="C" #Need C locale to get the right lower-case matching
  local _tag="${1}"
  #First do a quick check for non-valid characters in the tag name
  echo "${_tag}" | grep -qE '^[0-9a-z]+$'
  if [ $? -ne 0 ] ; then return 1; fi
  #Now check the length of the tag
  local _length=`echo "${_tag}" | wc -m | tr -d '[:space:]'`
  #echo "[INFO] Checking Github Tag Length: ${_tag} ${_length}"
  if [ ${_length} -eq 41 ] ; then
    #right length for a GitHub commit tag (40 characters + null)
    return 0
  fi
  return 1
}

compare_tar_files(){
  #INPUTS:
  # 1: path to file 1
  # 2: path to file 2
  local oldsha=`sha512 -q "${1}"`
  local newsha=`sha512 -q "${2}"`
  if [ "$oldsha" = "$newsha" ] ; then
    return 0
  fi
  return 1
}

# ======
#  STAGES
# ======
clean_base(){
  echo "[INFO] Cleaning..."
  if [ -d "${BASEDIR}" ] ; then
    #Now remove the source dir
    rm -rf "${BASEDIR}"
  fi
  if [ -d "${INTERNAL_RELEASE_OBJDIR}" ] ; then
    #Make sure we unmount any mountpoints still in the release dir (nullfs mountpoints tend to get left behind there)
    for mntpnt in `mount | grep "${INTERNAL_RELEASE_OBJDIR}" | cut -w -f 3`
    do
      umount "${mntpnt}"
    done
    #Now delete them
    chflags -R noschg "${INTERNAL_RELEASE_OBJDIR}"
    rm -rf "${INTERNAL_RELEASE_OBJDIR}"
  fi
  if [ -d "${ARTIFACTS_DIR}" ] ; then
    rm -rf "${ARTIFACTS_DIR}"
  fi
  #always return 0 for cleaning
  return 0
}

checkout(){
  if [ "$1" = "base" ] ; then
    GH_BASE_ORG=`jq -r '."base-github-org"' "${TRUEOS_MANIFEST}"`
    GH_BASE_REPO=`jq -r '."base-github-repo"' "${TRUEOS_MANIFEST}"`
    GH_BASE_TAG=`jq -r '."base-github-tag"' "${TRUEOS_MANIFEST}"`
    SRCDIR="${BASEDIR}"
    echo "[INFO] Check out base repository"
    if [ -z "${GH_BASE_ORG}" ] ; then
      echo "[ERROR] Could not read base-github-org from JSON manifest!"
      return 1
    fi
  elif [ "$1" = "ports" ] ; then
    GH_BASE_ORG=`jq -r '."ports-github-org"' "${TRUEOS_MANIFEST}"`
    GH_BASE_REPO=`jq -r '."ports-github-repo"' "${TRUEOS_MANIFEST}"`
    GH_BASE_TAG=`jq -r '."ports-github-tag"' "${TRUEOS_MANIFEST}"`
    SRCDIR="${PORTSDIR}"
    if [ -z "${GH_BASE_ORG}" ] || [ "null" = "${GH_BASE_ORG}" ] ; then
      #This is optional - just skip it if not set/used in the manifest
      return 0
    fi
    echo "[INFO] Check out ports repository"
  fi
  #If a branch name was specified
  GH_BASE_BRANCH="${GH_BASE_TAG}"
  check_github_tag "${GH_BASE_TAG}"
  if [ $? -ne 0 ] && [ -e "/usr/local/bin/git" ] ; then
    # Get the latest commit on this branch and use that as the commit tag (prevents constantly downloading a branch to check checksums)  
    GH_BASE_TAG=`git ls-remote "https://github.com/${GH_BASE_ORG}/${GH_BASE_REPO}" "${GH_BASE_TAG}" | cut -w -f 1`
  fi
  BASE_CACHE_DIR="/tmp/trueos-repo-cache"
  BASE_TAR="${BASE_CACHE_DIR}/${GH_BASE_ORG}_${GH_BASE_REPO}_${GH_BASE_TAG}.tgz"
  local _skip=1
  if [ -d "${BASE_CACHE_DIR}" ] ; then
    if [ -e "${BASE_TAR}" ] ; then
      # This tag was previously fetched
      # If a commit tag - just re-use it (nothing changed)
      #  if is it a branch name, need to re-download and check for differences
      check_github_tag "${GH_BASE_TAG}"
      if [ $? -ne 0 ] ; then
        #Got a branch name - need to re-download the tarball to check
        # Note: This is only a fallback for when "git" is not installed on the build server
        #   if git is installed the branch names were turned into tags earlier
        mv "${BASE_TAR}" "${BASE_TAR}.prev"
      else
        #Got a commit tag - skip re-downloading/extracting it
        _skip=0
      fi
    else
      #Got a different tag - clear the old files from the cache
      rm -f ${BASE_CACHE_DIR}/${GH_BASE_ORG}_${GH_BASE_REPO}_*.tgz
    fi
  else
    mkdir -p "${BASE_CACHE_DIR}"
  fi
  BASE_URL="https://github.com/${GH_BASE_ORG}/${GH_BASE_REPO}/tarball/${GH_BASE_BRANCH}"
  #NOTE: Fetch works, but seems slower than using curl
  if [ ${_skip} -ne 0 ] ; then
    echo "[INFO] Downloading Repo..."
    fetch --retry -o "${BASE_TAR}" "${BASE_URL}"
    #curl -L "${base_url}" -o "${BASE_TAR}"
    if [ $? -ne 0 ] ; then
      echo "[ERROR] Could not download repository: ${BASE_URL}"
      return 1
    fi
  fi
  # Now that we have the tarball, lets extract it to the base dir
  if [ -e "${BASE_TAR}.prev" ] ; then
    compare_tar_files "${BASE_TAR}" "${BASE_TAR}.prev"
    if [ $? -eq 0 ] ; then
      _skip=0
    fi
    rm "${BASE_TAR}.prev"
  fi
  if [ -d "${SRCDIR}" ] && [ 0 -ne "${_skip}" ] ; then
    if [ "$1" = "base" ] ; then clean_base ; fi
    rm -rf "${SRCDIR}"
  fi
  if [ ! -d "${SRCDIR}" ] ; then
    mkdir -p "${SRCDIR}"
    #Note: GitHub archives always have things inside a single subdirectory in the archive (org-repo-tag)
    #  - need to ignore that dir path when extracting
    if [ -e "${BASE_TAR}" ] ; then
      echo "[INFO] Extracting ${1} repo..."
      tar -xf "${BASE_TAR}" -C "${SRCDIR}" --strip-components 1
      echo "[INFO] Done: ${SRCDIR}"
    else
      echo "[ERROR] Could not find source repo tarfile: ${BASE_TAR}"
      return 1
    fi
  else
    echo "[INFO] Re-using existing source tree: ${SRCDIR}"
  fi
  # =====
  # Ports Tree Overlay
  # =====
  if [ "$1" = "ports" ] ; then
    apply_ports_overlay
    #symlink the distfiles dir into the temporary source tree if it exists
    if [ -d "/usr/ports/distfiles" ] ; then
      if [ ! -h "${SRCDIR}/distfiles" ] ; then
        if [ -e "${SRCDIR}/distfiles" ] ; then
          rm  -r "${SRCDIR}/distfiles"
        fi
        ln -s "/usr/ports/distfiles" "${SRCDIR}/distfiles"
      fi
    fi
  fi
}

make_world(){
  if [ -d "${INTERNAL_RELEASE_OBJDIR}" ] ; then
    echo "[INFO] Base World Unchanged: Re-using base packages"
  else
    echo "[INFO] Building world..."
    cd "${BASEDIR}"
    make -j${MAX_THREADS} buildworld
    if [ $? -ne 0 ] ; then
      echo "[ERROR] Could not build TrueOS world"
      return 1
    fi
  fi
}

make_kernel(){
  if [ -e "${INTERNAL_RELEASE_OBJDIR}/sys/GENERIC/kernel" ] ; then
    echo "[INFO] Base Kernel Unchanged: Re-using base packages"
  else
    echo "[INFO] Building kernel..."
    cd "${BASEDIR}"
    make -j${MAX_THREADS} buildkernel
    if [ $? -ne 0 ] ; then
      echo "[ERROR] Could not build TrueOS kernel"
      return 1
    fi
  fi
}

make_base_pkg(){
  #NOTE: This will use the PKGSIGNKEY environment variable to sign base packages
  echo "[INFO] Building base packages..."
  #Quick check for the *other* signing key variable
  if [ -z "${PKGSIGNKEY}" ] && [ -n "${PKG_REPO_SIGNING_KEY}" ] ; then
    PKGSIGNKEY="${PKG_REPO_SIGNING_KEY}"
  fi
  cd "${BASEDIR}"
  make -j${MAX_THREADS} packages
  if [ $? -ne 0 ] ; then
    echo "[ERROR] Could not build TrueOS base packages"
    return 1
  fi
  #Now make a symlink to the final package directories
  # Do not copy them! This dir is large!
  if [ -e "${PKG_RELEASE_BASE}" ] ; then
    rm "${PKG_RELEASE_BASE}"
  fi
  if [ -e "${INTERNAL_RELEASE_PKGDIR}" ] ; then
    echo "[INFO] Linking base package dir: ${INTERNAL_RELEASE_PKGDIR} -> ${PKG_RELEASE_BASE}"
    ln -sf "${INTERNAL_RELEASE_PKGDIR}" "${PKG_RELEASE_BASE}"
  else
    echo "[INFO] Linking base package dir: ${INTERNAL_RELEASE_REPODIR} -> ${PKG_RELEASE_BASE}"
    ln -sf "${INTERNAL_RELEASE_REPODIR}" "${PKG_RELEASE_BASE}"
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
  if [ $? -ne 0 ] ; then
    echo "[ERROR] Could not build TrueOS ports"
    return 1
  fi
  if [ -n "${PKG_REPO_SIGNING_KEY}" ] ; then
    cd "${POUD_PKG_DIR}"
    echo "[INFO] Signing Packages..."
    pkg-static repo . "${PKG_REPO_SIGNING_KEY}"
    if [ $? -ne 0 ] ; then
      echo "[ERROR] Could not sign TrueOS packages"
      return 1
    fi
  fi
  #Now make a symlink to the final package directories
  # Do not copy them! This dir is massive!
  if [ -e "${PKG_RELEASE_PORTS}" ] ; then
    rm "${PKG_RELEASE_PORTS}"
  fi
  echo "[INFO] Linking package dir: ${POUD_PKG_DIR} -> ${PKG_RELEASE_PORTS}"
  ln -sf "${POUD_PKG_DIR}" "${PKG_RELEASE_PORTS}"
}

make_release(){
  echo "[INFO] Building ISO..."
  #Determine the ISO name based on the JSON manifest
  local ISOBASE
  local CURDATE=`date -j "+%Y%m%d_%H_%M"`
  if [ "$(jq -r '."iso-name" | length' ${TRUEOS_MANIFEST})" != "0" ] ; then
    ISOBASE=`jq -r '."iso-name"' ${TRUEOS_MANIFEST}`
  else
    ISOBASE=`basename -s ".json" "${TRUEOS_MANIFEST}"`
  fi

  local ISONAME="${ISOBASE}-${CURDATE}"

  #Remove old artifacts (if any)
  if [ -e "${ARTIFACTS_DIR}" ] ; then
    rm -rf "${ARTIFACTS_DIR}"
  fi
  mkdir -p "${ARTIFACTS_DIR}/tar"
  #Remove old build stage (if it exists)
  if [ -e "${INTERNAL_RELEASE_BASEDIR}/disc1" ] ; then
    rm -rf "${INTERNAL_RELEASE_BASEDIR}/disc1"
  fi
  #Remove any ISOs from previous builds
  if [ -e "${INTERNAL_RELEASE_DIR}" ] ; then
    cd "${INTERNAL_RELEASE_DIR}"
    rm *.iso
    rm *.img
  fi
  cd "${BASEDIR}/release"
  make clean
  make release
  if [ $? -eq 0 ] ; then
    cd "${INTERNAL_RELEASE_DIR}"
    cp *.iso "${ARTIFACTS_DIR}/"
    if [ $? -ne 0 ] ; then
      echo "[WARNING] ISO files not found in dir: ${INTERNAL_RELEASE_DIR}"
    fi
    #Optional offline update image file (if it exists)
    cp *.img "${ARTIFACTS_DIR}/" 2>/dev/null
    cp *.txz "${ARTIFACTS_DIR}/tar/"
    if [ $? -ne 0 ] ; then
      echo "[WARNING] TXZ files not found in dir: ${INTERNAL_RELEASE_DIR}"
    fi
    cp MANIFEST "${ARTIFACTS_DIR}/tar/"
    if [ $? -ne 0 ] ; then
      echo "[WARNING] MANIFEST file not found in dir: ${INTERNAL_RELEASE_DIR}"
    fi
    if [ -f "${ARTIFACTS_DIR}/disc1.iso" ] ; then
      echo "[INFO] Renaming disc1.iso to ${ISONAME}.iso"
      mv "${ARTIFACTS_DIR}/disc1.iso" "${ARTIFACTS_DIR}/${ISONAME}.iso"
    fi
    num_files=`ls -Ap1 "${ARTIFACTS_DIR}" | wc -l`
    if [ ${num_files} -gt 1 ] ; then
      #Got artifact files
      echo "[INFO] Artifact files located in: ${ARTIFACTS_DIR}"
      return 0
    else
      #No artifact files
      echo "[ERROR] No files could be artifacted!"
      _tmp=`ls -l "${INTERNAL_RELEASE_DIR}"`
      echo "Internal Release Dir contents:\n${_tmp}"
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
  if [ -e "${INTERNAL_RELEASE_PKGDIR}" ] ; then
    _pkgdir="${INTERNAL_RELEASE_PKGDIR}/All"
  else
    _pkgdir="${POUD_PKG_DIR}/All"
  fi
  _pkgfile="${ARTIFACTS_DIR}/pkg.list"

  #Remove the old file if it exists
  if [ -e "${_pkgfile}" ] ; then
    rm "${_pkgfile}"
  fi
  
  for _path in `find "${_pkgdir}" -depth 1 -name "*.txz" | sort`
  do
    #Cleanup the individual line (directory, suffix)
    _line=$(basename ${_path} | sed "s|.txz||g")
    #Make sure it is a valid package name - otherwise skip it
    case "${_line}" in
	fbsd-distrib) continue ;;
	*-*) ;;
	*) continue ;;
    esac
    #Read off the name/version of the package file and put it into the manifest
    pkg query -F "${_path}" "%n : %v" >> ${_pkgfile}
  done
  #cleanup the temporary variables
  unset _pkgdir
  unset _pkgfile
  unset _path
}

make_sign_artifacts(){
  #NOTE: This will use the PKGSIGNKEY environment variable to sign ISO files
  echo "[INFO] Organizing Artifacts..."
  #Quick check for the *other* signing key variable
  if [ -z "${PKGSIGNKEY}" ] && [ -n "${PKG_REPO_SIGNING_KEY}" ] ; then
    PKGSIGNKEY="${PKG_REPO_SIGNING_KEY}"
  fi
  cd "${ARTIFACTS_DIR}"
  manifest="manifest.json"
  if [ -e "${PKGSIGNKEY}" ] ; then
    keyfile="${PKGSIGNKEY}"
  else
    keyfile="priv.key"
    echo "${PKGSIGNKEY}" > "${keyfile}"
  fi

  #Note: There should only be 1 ISO in the artifacts dir typically
  for iso in `ls *.iso`
  do
    add_to_json_str "iso" "${iso}" "${manifest}"
    size=`ls -lh "${iso}" | cut -w -f 5`
    add_to_json_str "iso_size" "${size}" "${manifest}"
    if [ -n "${PKGSIGNKEY}" ] ; then
      echo "[INFO] Signing ISO: ${iso}"
      openssl dgst -sha512 -sign "${PKGSIGNKEY}" -out "${iso}.sha512" "${iso}"
      add_to_json_str "iso_signature" "${iso}.sha512" "${manifest}"
      echo "[INFO] Creating public key for verification later"
      openssl rsa -in "${keyfile}" -pubout -out "${POUDRIERE_BASE}.pubkey"
      add_to_json_str "iso_pubkey" "${POUDRIERE_BASE}.pubkey" "${manifest}"
    fi
    echo "[INFO] Generating MD5: ${iso}"
    md5 "${iso}" | cut -d = -f 2 | tr -d '[:space:]' > "${iso}.md5"
    add_to_json_str "iso_md5" "${iso}.md5" "${manifest}"  
    _tmp=`cat ${iso}.md5`
    add_to_json_str "iso_md5_raw" "${_tmp}" "${manifest}"
  done
  _date=`date -ju "+%Y_%m_%d %H:%M %Z"`
  _date_secs=`date -j +%s`
  add_to_json_str "build_date" "${_date}" "${manifest}"
  add_to_json_str "build_date_time_t" "${_date_secs}" "${manifest}"  
  #Make sure we delete any temporary private key file
  if [ "${keyfile}" = "priv.key" ] ; then
    rm "${keyfile}"
  fi
  echo "[DONE] Manifest of artifacts available: ${manifest}"
}

make_all(){
  checkout base
  if [ $? -eq 0 ] ; then
    checkout ports
  else
    return 1
  fi
  if [ $? -eq 0 ] ; then
    make_world
  else
    return 1
  fi

  if [ $? -eq 0 ] ; then
    make_kernel
  else
    return 1
  fi

  if [ $? -eq 0 ] ; then
    make_base_pkg
  else
    return 1
  fi

  if [ $? -eq 0 ] ; then
    make_ports
  else
    return 1
  fi

  if [ $? -eq 0 ] ; then
    make_release
  else
    return 1
  fi

  if [ $? -eq 0 ] ; then
    make_pkg_manifest
  else
    return 1
  fi

  if [ $? -eq 0 ] ; then
    make_sign_artifacts
  else
    return 1
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
		checkout base
		if [ $? -eq 0 ] ; then
		  checkout ports
		fi
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
	sign_artifacts)
		make_sign_artifacts
		;;
	*)
		echo "Unknown Option: $1"
		echo "Valid options: all, clean, checkout, world, kernel, base, ports, release, manifest, sign_artifacts"
		;;
esac
#Save the return code for a moment
ret=$?
#Do any post-process cleanup
if [ -e "${TRUEOS_MANIFEST}.orig" ] ; then
  #Put the original manifest file back in place
  mv "${TRUEOS_MANIFEST}.orig" "${TRUEOS_MANIFEST}"
fi

#Now return the proper error/success code
return ${ret}
