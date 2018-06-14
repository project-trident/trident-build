# Setup guide for creating a TrueOS distribution

## Initial Setup
1. Fork the trueos/trueos Github repository
2. Copy/edit the release/
3. 

## Signing Packages
1. Create a private SSL Key: `openssl genrsa -out my_private_key.key [2048/4096/8192]`
2. Save the public version of that key: `openssl rsa -in my_private_key.key -pubout > my_public_key.key`
3. Copy the contents of the public key file into the JSON manifest ("pkg-repo" and "base-pkg-repo" sections - add the "pubkey" variable which contains an array of the lines of the public key file.

## Settings up Jenkins automation framework
1. Create an SSH key to use when publishing files to a remote distribution server/system: Run `ssh-keygen` and follow the prompts.
2. Add the SSH key and SSL private key to the Jenkins instance and get the credential ID number for each one.
3. Copy one of the "Jenkinsfile-*" examples from the trueos/trueos repository.
4. In the new jenkins file, adjust all the "credentials('*')" entries with the credential ID's for your keys.
5. In the "Publish" stage of the jenkins file, adjust the 

## Custom Branding at bootup
There are 3 files which need to be created to brand the boot menu:
1. (trueos repository): stand/lua/brand-[distro].lua (copy/modify the brand-trueos.lua file)
2. (trueos repository): stand/lua/logo-[distro].lua (copy/modify one of the other logo-*.lua files)
3. (trueos repository): Add the new files to the list in stand/lua/Makefile
4. (overlay file): /boot/loader.conf.local
Add the following entries to it:
```
loader_brand="[distro]"
loader_logo="[distro]"
loader_menu_title="Disto Title"
loader_color="[YES/NO]"
```
The trueos repository files (brand-*.lua, logo-*.lua) can be submitted upstream to the TrueOS repo to reduce the management overhead of alterations in the forked repository.
