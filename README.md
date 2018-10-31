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
   * **Ensure the package repo URLs match the package server setup**
* Jenkinsfile-trident-master
   * Pipeline script for Jenkins to manage the build of Project Trident and push files to a remote server.
   * **Ensure the publication dirs align with the package server setup**
* Jenkinsfile-trident-promote
   * Pipeline script for Jenkins to promote "staged" packages/iso on remote server to release.
   * **Ensure the remote directory structure aligns with the package server setup**

### build-distro.sh
Primary script to run to perform builds.
Syntax:
 * `build-distro.sh <command> [JSON Manifest File]`
**Note:** The JSON manifest file can also be supplied via the "TRUEOS_MANIFEST" environment variable. That manifest **must** be provided in order to perform the build.

#### Commands:
   * **all** : Perform the following stages (in-order): checkout, world, kernel, packages, release, manifest, sign_artifacts
   * **clean** : Cleanup any temporary working directories and output dirs/files 
      * *OPTIONAL* : The checkout phase will automatically clean source directories as needed based upon changes to the source/ports commit tags. This can be run manually to forcibly re-build the world/kernel as desired.
   * **checkout** : Fetch/extract the base/ports repositories (cached by tag - will only re-download if the tag changes)
   * **world** : Build FreeBSD world. Corresponds to "make buildworld". Will automatically re-use previous results as needed.
   * **kernel** : Build FreeBSD kernel. Corresponds to "make buildkernel". Will automatically re-use previous results as needed.
   * **base** (TrueOS 18.06 only): Build/sign base packages. Corresponds to "make packages". The "PKGSIGNKEY" or "PKG_REPO_SIGNING_KEY" environment variable must be set for this stage in order to sign the base packages.
   * **ports** (TrueOS 18.06 only): Build/sign ports packages. Corresponds to "cd release && make poudriere". The "PKGSIGNKEY" or "PKG_REPO_SIGNING_KEY" environment variable must be set for this stage in order to sign the packages.
   * **packages** (TrueOS 18.10+): Creates unified base+ports packages and repo. The "PKGSIGNKEY" or "PKG_REPO_SIGNING_KEY" environment variable must be set for this stage in order to sign the packages.
   * **release** : Build ISO files and artifacts. Corresponds to "cd release && make release".
   * **manifest** : Generate a manifest of all non-base packages ("artifacts/pkg.list")
   * **sign_artifacts** : Sign all the ISO files (if a key is provided), generate makesums, and generate a manifest.json file containing links/information about all the ISO artifact files.
   
#### Extra supported/required fields in the TrueOS JSON manifest:
**NOTE:** The macro "%%PWD%%" can be used anywhere in the JSON manifest to insert the path to the directory which contains the JSON manifest file. This is useful if an option in the manifest requires a full path (such as a "local" iso-overlay setting), but the location of the build repository might be programmatically generated via automation procedures.

**TrueOS supported JSON manifest fields**
The details for the TrueOS build system can be seen on their [github readme](https://github.com/trueos/trueos/blob/trueos-master/release/README.md)


**Additional JSON manifest fields**
   * "base-github-org" : [Required] (string) Name of the organization on GitHub (example: "trueos")
   * "base-github-repo" : [Required] (string) Name of the repository on GitHub (example: "trueos")
   * "base-github-tag" : [Required] (string) Tag name or commit ID to fetch from the GitHub org/repo
   * "ports-github-org" : [Optional] (string) Name of the organization on GitHub (example: "trueos")
   * "ports-github-repo" : [Optional] (string) Name of the repository on GitHub (example: "trueos")
   * "ports-github-tag" : [Optional] (string) Tag name or commit ID to fetch from the GitHub org/repo
   * "os_version" : [Optional] (string) User-defined version tag - gets set as the "TRUEOS_VERSION" environment variable and can be automatically inserted into the ISO file name as needed with the "%%TRUEOS_VERSION%%" format code.
   * "iso-name" : (string) Base name of the ISO to create (example: "mydistro")
      * [Optional] Default value is the name of the JSON manifest file ("mydistro.json" -> "mydistro-[BuildDate].iso")
      * This option is mainly provided for the 18.06 builds. For 18.10+ it is recommended to use the ISO naming flags in the TrueOS JSON manifest options.
   * "ports-overlay" : [Optional] (Array of JSON objects) paths to directories to add/replace items in the ports tree
      * ***[WARNING]*** This is only possible if the "ports-github-*" mechanism is used to fetch the ports repository.
      * Syntax for objects within the array:
         * "type" : (string) Either "category" (adding a new category to the ports tree) or "port" (adding a single port to the tree)
         * "name" : (string) Category name ("mydistro") or port origin ("devel/myport") depending on the type of overlay.
         * "local_path" : (string) path to the local directory which will be used as the overlay.
         * Example:
```
"ports-overlay" : [
  {
    "type" : "category",
    "name" : "mydistro",
    "local_path" : "overlay/mydistro"
  },
  {
    "type" : "port",
    "name" : "devel/myport",
    "local_path" : "overlay/devel/myport"
  }
]
```

***[WARNING]*** If you use the "ports-github-*" manifest options, you need to ensure to set the TrueOS ports type to "local" and the url to "/usr/ports_tmp". Those options allow checking out specific tags/commits, and bypass the built-in ports repo checkout procedures within TrueOS. If you want to use a standard tarball or git branch, enable the standard TrueOS port options and remove the "ports-github-*" options from the manifest.

#### Supported environment variables (inputs/overrides)
* "PKGSIGNKEY" or "PKG_REPO_SIGNING_KEY" [optional]
   * Format: String with the contents of the private SSL key to use when signing the packages.
   * PKGSIGNKEY: Used during the "base" process to sign FreeBSD base packages in addition to the "sign_artifacts" process to sign the ISO file.
   * PKG_REPO_SIGNING_KEY: Used during the "ports" process to sign FreeBSD ports packages
   * Note: If only one of these variables is set, it will automatically copy/use it for the other as well.
* "MAX_THREADS" [optional]
   * Format: Integer (number of threads to use, 1 or higher)
   * This is passed via the "-j[number]" flag to the build procedures to speed up the compilation processes.
   * Default value: One less than the detected number of CPU's on the system (sysctl -n hw.ncpu): Example: An 8-core system will result in MAX_THREADS getting automatically set to 7.

### Output Files
 * ISO Build artifacts (ISO, MANIFEST, various *.tgz) will be placed in a new "artifact-iso/" subdirectory relative to the location of the build-distro.sh script.
* (TrueOS 18.06 only) "Ports" Package Files will be linked to a new "artifact-pkg/" subdirectory relative to the location of the build-distro.sh script (symlink to the actual poudriere dir on disk).
* "Base" Package Files will be linked to a new "artifact-pkg-base/" subdirectory relative to the location of the build-distro.sh script (symlink to the actual base-package dir on disk).
   * **NOTE:** With TrueOS 18.10+, a "unified" repository is created for all base+ports packages. This artifact dir contains all packages for these kinds of builds.

## General Notes about creating a TrueOS distribution
### Tuning Build Server
There are a few options in the JSON manifest that are essential to change for the hardware that you will be using to perform builds:
1. "poudriere-conf"
   * "PARALLEL_JOBS=[Number]" : Number of concurrent packages to build
   * "PREPARE_PARALLEL_JOBS=[Number]" : Number of CPU's to use when setting up poudriere (Recommended: Max CPU number - 1)
   * "USE_TMPFS=[all, yes, wrkdir, data, localbase, no]" : How much of the port builds should be performed in memory (Recommended: Start with "no" and then if you find you have memory to spare, bump it up to the next option until you are *almost* out of space).
   * "ALLOW_MAKE_JOBS=[yes, no]" : Allow building ports with multiple CPU's
2. "ports" -> "make.conf"
   * "MAKE_JOBS_NUMBER_LIMIT=[Number]" : Number of CPU's to use for each port build.
   
For best results, we have found that it tends to be better/faster to use fewer parallel jobs with more CPU's per job. It also helps to leave a little bit of overhead on the system for other services that might be getting run on the system (such as nginx providing access to the build logs, or ssh access to the system if you are remotely-managing the build).
Example: For an 80-core system, using 20 parallel jobs at 4 cores per job would max the system (20 * 4 = 80). Changing it to 16 jobs at 5 cores per job would also max the system but tends to be "faster" at finishing builds since the limiting factor tends to be long-build-time ports rather then the number of small ports total.

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
