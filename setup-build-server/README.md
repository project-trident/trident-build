# Notes about setting up a build server for Project Trident (or any TrueOS-based distribution)

### OS Branch: trueos-stable-XXXX
1. Install the latest TrueOS release (server image) and install it onto system
2. Install the "git" package (if not already installed): `pkg install git`
3. Fetch this repository with git: `git clone https://github.com/project-trident/trident-build.git`
4. Run the build server setup script: `trident-build/setup-build-server/setup.sh`
   * This will install a few other packages like: poudriere, uclcmd, llvm60, jenkins, and more.
   * This will also setup/start an nginx server to provide access to the poudriere logs via a web interface.
   
### OS Branch: trueos-master (any version newer than a TrueOS "release" version)
First follow the instructions for the "stable" branch above, then follow these steps to update the system to a newer version of TrueOS.
1. Edit the pkg repository configuration file (most likely /etc/pkg/TrueOS.conf or /usr/local/etc/pkg/TrueOS.conf)
   1. Disable all the other package repositories that are setup on your system (set the "enabled" option to "no" or "false")
   2. Add the following entry to the config file:
```
TrueOS-snapshots: {
  url: "https://pkg.trueos.org/pkg/snapshot/${ABI}/latest",
  signature_type: "pubkey",
  pubkey: "/usr/share/keys/pkg/trueos.pub",
  enabled: yes
}
```
2. Run `pkg update -f` to tell pkg about the new repo/settings
3. Run `trueos-update check` and `trueos-update upgrade` to upgrade the system to the latest TrueOS snapshot.

### Done!
Now you can run the "build-distro.sh" script as desired (via Jenkins or manually running the script) to start doing builds!
   * Reminder, you will want to copy/edit the trident-master.json file to setup your own particular build configuration before starting builds.
