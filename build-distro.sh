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
BASEDIR="/usr/src_tmp"
PORTSDIR="/usr/ports_tmp"
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
  jq '. += {"'${1}'": "'${val}'"}' "${3}" > "${3}.new"
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

# ======
#  STAGES
# ======
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
    if [ -z "${GH_BASE_ORG}" ] ; then
      #This is optional - just skip it if not set/used in the manifest
      return 0
    fi
    echo "[INFO] Check out ports repository"
  fi

  BASE_CACHE_DIR="/tmp/trueos-repo-cache"
  BASE_TAR="${BASE_CACHE_DIR}/${GH_BASE_ORG}_${GH_BASE_REPO}_${GH_BASE_TAG}.tgz"
  if [ ! -f "${BASE_TAR}" ] ; then
    if [ -d "${BASE_CACHE_DIR}" ] ; then
      #Got a different tag - clear the old files from the cache
      rm -f ${BASE_CACHE_DIR}/${GH_BASE_ORG}_${GH_BASE_REPO}_*.tgz
    else
      mkdir -p "${BASE_CACHE_DIR}"
    fi
    BASE_URL="https://github.com/${GH_BASE_ORG}/${GH_BASE_REPO}/tarball/${GH_BASE_TAG}"
    #NOTE: Fetch works, but seems slower than using curl
    echo "[INFO] Downloading Repo..."
    fetch --retry -o "${BASE_TAR}" "${BASE_URL}"
    #curl -L "${base_url}" -o "${BASE_TAR}"
    if [ $? -ne 0 ] ; then
      echo "[ERROR] Could not download repository: ${BASE_URL}"
      return 1
    fi
  fi

  # Now that we have the tarball, lets extract it to the base dir
  if [ -d "${SRCDIR}" ] ; then
   rm -rf "${SRCDIR}"
  fi
  mkdir -p "${SRCDIR}"
  #Note: GitHub archives always have things inside a single subdirectory in the archive (org-repo-tag)
  #  - need to ignore that dir path when extracting
  if [ -e "${BASE_TAR}" ] ; then
    echo "[INFO] Extracting ${1} repo..."
    tar -xf "${BASE_TAR}" -C "${SRCDIR}" --strip-components 1
  else
    echo "[ERROR] Could not find source repo tarfile: ${BASE_TAR}"
    return 1
  fi
  # =====
  # Ports Tree Overlay
  # =====
  if [ "$1" = "ports" ] ; then
    apply_ports_overlay
  fi
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
  if [ -e "${ARTIFACTS_DIR}" ] ; then
    rm -rf "${ARTIFACTS_DIR}"
  fi
  mkdir -p "${ARTIFACTS_DIR}/tar"
  cd "${BASEDIR}/release"
  make release
  if [ $? -eq 0 ] ; then
    cd "${INTERNAL_RELEASE_DIR}"
    cp *.iso "${ARTIFACTS_DIR}/"
    if [ $? -ne 0 ] ; then
      echo "[WARNING] ISO files not found in dir: ${INTERNAL_RELEASE_DIR}"
    fi
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

  done

  #Make sure we delete any temporary private key file
  if [ "${keyfile}" = "priv.key" ] ; then
    rm "${keyfile}"
  fi
  echo "[DONE] Manifest of artifacts available: ${manifest}"
}

make_all(){
  clean_base
  if [ $? -eq 0 ] ; then
    checkout base
  else
    return 1
  fi
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
