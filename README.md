# trident-build
Simple build system for creating a TrueOS distribution

## Directories/Scripts
* setup-build-server/setup.sh
   * Simple script to provision a TrueOS system as a build server for TrueOS distributions.
   * This will install jenkins, nginx, git, and rsync, and setup the nginx server for viewing the poudriere build logs
   * It will also provide a couple ZFS tuning options which require a reboot to apply.
   * **MAKE SURE YOU TWEAK THE SCRIPT VALUES BEFORE RUNNING**
* setup-package-server/setup.sh
   * Simple script to provision a FreeBSD/TrueOS system as a package server.
   * This will install nginx and set it up to serve a data directory (/data) 
   * **MAKE SURE YOU TWEAK THE SCRIPT VALUES BEFORE RUNNING**

## Files:
* trident-master.json
   * JSON manifest used to build Project Trident
* Jenkinsfile-trident-master
   * Pipeline script for Jenkins to manage the build of Project Trident and push files to a remote server.

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
   * **manifest** : Generate a manifest of all non-base packages ("artifacts/pkg.list")
   
#### Extra supported/required fields in the TrueOS JSON manifest:
   * "base-github-org" : [Required] (string) Name of the organization on GitHub (example: "trueos")
   * "base-github-repo" : [Required] (string) Name of the repository on GitHub (example: "trueos")
   * "base-github-tag" : [Required] (string) Tag name or commit ID to fetch from the GitHub org/repo
   * "iso-name" : (string) Base name of the ISO to create (example: "mydistro")
      * [Optional] Default value is the name of the JSON manifest file ("mydistro.json" -> "mydistro-[BuildDate].iso")

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

## General Notes about creating a TrueOS distribution

### Signing Packages
1. Create a private SSL Key: `openssl genrsa -out my_private_key.key [2048/4096/8192]`
2. Save the public version of that key: `openssl rsa -in my_private_key.key -pubout > my_public_key.key`
3. Copy the contents of the public key file into the JSON manifest ("pkg-repo" and "base-pkg-repo" sections - add the "pubkey" variable which contains an array of the lines of the public key file.

### Settings up Jenkins automation framework
1. You will need an SSH key to use when publishing files to a remote distribution server/system: 
   * To create one, run `ssh-keygen` and follow the prompts.
   * Then add the public key to the distribution system so it can be used for login authentication.
2. Add the SSH key and SSL private key to the Jenkins instance and get the credential ID number for each one.
3. Copy one of the "Jenkinsfile-*" examples from the trueos/trueos repository.
4. In the new jenkins file, adjust all the "credentials('*')" entries with the credential ID's for your keys.
5. In the "Publish" stage of the jenkins file, adjust the user, server, and directories as needed for your distribution system.

### Custom Branding at bootup
There are 3 files which need to be created to brand the boot menu:
1. (trueos repository): *stand/lua/brand-[distro].lua* (copy/modify the *brand-trueos.lua* file)
2. (trueos repository): *stand/lua/logo-[distro].lua* (copy/modify one of the other *logo-*.lua* files)
3. (trueos repository): Add the new files to the list in *stand/lua/Makefile*
4. (overlay file): Add the following entries to /boot/loader.conf.local (you may need to create this file):
```
loader_brand="[distro]"
loader_logo="[distro]"
loader_menu_title="Disto Title"
loader_color="[YES/NO]"
```
The trueos repository files (brand-*.lua, logo-*.lua) can be submitted upstream to the TrueOS repo to reduce the management overhead of alterations in the forked repository.
