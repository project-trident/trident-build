# trident-build
Simple build system for creating a TrueOS distribution

## Directories/Scripts
* iso-overlay
   * 1:1 mapping of files to add/replace on the default TrueOS ISO during it's creation.
* ports-overlay
   * Custom ports that are added/replaced in the TrueOS ports tree by Project Trident
   * NOTE: For a port to get added via overlay, an entry in the build manifest needs to be added for it.

## Files:
* trident-stable.json
   * JSON manifest used to build Project Trident
* Jenkinsfile-tridentbuild-stable
   * Pipeline script for Jenkins to manage the build of Project Trident and push files to a remote server.
* Jenkinsfile-trident-promote
   * Pipeline script for Jenkins to promote "stage" packages/iso on remote server to "release".
* Jenkinsfile-trident-uploadTrain
   * Pipeline script for Jenkins to sync the repo-trains manifest in this repo with the upstream distribution server.
