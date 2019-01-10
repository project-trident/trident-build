# Update Trains Configuration

## Files
* trains.json
   * Update Trains declarations
* trains.json.sha1
   * Signature file for trains.json
* sign-trains.sh
   * Script to generate the signature file for trains.json
   * Needs to be run every time the trains.json file is changed.

## Usage
After signing, the trains.json and trains.json.sha1 need to be uploaded to the package server where it can be fetched/verified as needed.
The URL to the trains file needs to be placed into the "/usr/local/etc/sysup/trains.json" configuration file, which has a syntax as follows:

```
{
  "bootstrap" : true,
  "bootstrapfatal" : false,
  "offlineupdatekey" : "/usr/share/keys/Trident.pub",
  "trainsurl" : "http://pkg.project-trident.org/trains/trident-trains.json"
}
```
