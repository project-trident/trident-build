# trident-build
Simple build system for creating a TrueOS distribution

## Files:
### build-distro.sh
Primary script to run to perform builds.
Syntax:
 * `build-distro.sh <command> [JSON Manifest File]`
**Note:** The JSON manifest file can also be supplied via the "TRUEOS_MANIFEST" environment variable. That manifest **must** be provided in order to perform the build.

#### Commands:
   * **all** : Perform the following stages (in-order): clean, checkout, world, kernel, base, ports, release
   * **clean** : Cleanup any temporary working directories and output dirs/files
   * **checkout** : Fetch/extract the base repository (cached by tag - will only re-download if the tag changes)
   * **world** : Build FreeBSD world. Corresponds to "make buildworld"
   * **kernel** : Build FreeBSD kernel. Corresponds to "make buildkernel"
   * **base** : Build/sign base packages. Corresponds to "make packages". The "PKGSIGNKEY" or "PKG_REPO_SIGNING_KEY" environment variable must be set for this stage in order to sign the base packages.
   * **ports** : Build/sign ports packages. Corresponds to "cd release && make poudriere". The "PKGSIGNKEY" or "PKG_REPO_SIGNING_KEY" environment variable must be set for this stage in order to sign the packages.
   * **release** : Build ISO files and artifacts. Corresponds to "cd release && make release".
   
#### Extra supported/required fields in the TrueOS JSON manifest:
   * "base-github-org" : [Required] (string) Name of the organization on GitHub (example: "trueos")
   * "base-github-repo" : [Required] (string) Name of the repository on GitHub (example: "trueos")
   * "base-github-tag" : [Required] (string) Tag name or commit ID to fetch from the GitHub org/repo
   * "iso-name" : (string) Base name of the ISO to create (example: "mydistro")
      * [Optional] Default value is the name of the JSON manifest file ("mydistro.json" -> "mydistro-<BuildDate>.iso")

#### Supported environment variables (inputs/overrides)
* "PKGSIGNKEY" or "PKG_REPO_SIGNING_KEY" [optional]
   * Format: String with the contents of the private SSL key to use when signing the packages.
   * PKGSIGNKEY: Used during the "base" process to sign FreeBSD base packages.
   * PKG_REPO_SIGNING_KEY: Used during the "ports" process to sign FreeBSD ports packages
   * Note: If only one of these variables is set, it will automatically copy/use it for the other as well.
* "MAX_THREADS" [optional]
   * Format: Integer (number of threads to use, 1 or higher)
   * This is passed via the "-j[number]" flag to the build procedures to speed up the compilation processes.
   * Default value: One less than the detected number of CPU's on the system (sysctl -n hw.ncpu): Example: An 8-core system will result in MAX_THREADS getting automatically set to 7.

### Output Files
 * Build artifacts (ISO, MANIFEST, various *.tgz) will be placed in a new "artifacts/" subdirectory relative to the location of the build-distro.sh script.
* "Ports" Package Files are located in "/usr/local/poudriere/data/packages/<manifest-name>-<ports-branch>"
   * Example: For a manifest called "trident.json" with a ports-branch entry of "trueos-master" the directory will be "/usr/local/poudriere/data/packages/trident-trueos-master"
   * This directory is *not* cleaned when the "clean" command is run. This allows port builds to be iterative in order to save a lot of time when doing regular builds. Instead, the build system is smart enough to automatically clean the ports dir as needed (such as when a base ABI change is detected).
* "Base" Package Files are located in "/usr/obj${WORKSPACE}/base/repo/${ABI}/latest"
