# stats-scan Utility
This is a simple go utility written to scan an NGINX access log and generate a JSON file of unique results:

## To Build
1. Install the "go" package
2. Run `go build stats-scan.go` to create the "stats-scan" binary

## To Run
Usage: `stats-scan <logfile1> <logfile2> ...`

This will print all the JSON to the terminal, so if you want to save the results to a file instead you will want to pipe it into a file:
`stats-scan <logfile1> > results.json`
