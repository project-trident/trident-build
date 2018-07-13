# trident-build
Simple build system for creating a TrueOS distribution

## Files:
### build-distro.sh
Primary script to run to perform builds.
Syntax:
 * `build-distro.sh <command> [JSON Manifest File]`
Commands:
   * all
   * clean
   * checkout
   * world
   * kernel
   * base
   * ports
   * release
   
Extra supported/required fields in the TrueOS JSON manifest:
   * "base-github-org" : (string) Name of the organization on GitHub (example: "trueos")
   * "base-github-repo" : (string) Name of the repository on GitHub (example: "trueos")
   * "base-github-tag" : (string) Tag name or commit ID to fetch from the GitHub org/repo
   * "iso-name" : (string) Base name of the ISO to create (example: "mydistro")
      * [Optional] Default value is the name of the JSON manifest file ("mydistro.json" -> "mydistro-<BuildDate>.iso")
