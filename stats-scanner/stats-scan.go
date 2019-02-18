package main

import (
	"fmt"
	"bufio"
	"os"
	"os/exec"
	S "strings"
	"regexp"
	"strconv"
	"net/url"
)

func exit_error(e error) {
  if e != nil {
    panic(e)
  }
}

func read_file(path string, hash map[string]string) {
  tmpfile := ""
  if S.HasSuffix(path, "bz2") {
    tmpfile = S.TrimSuffix(path, "bz2")
    cmd := exec.Command("bunzip2", "-k", path)
    if cmd.Run() != nil { 
      if _, err := os.Stat(tmpfile); os.IsNotExist(err) {
        fmt.Println("Could not unzip file:", path)
        return
      }
    }
    path = tmpfile
  }

  file, err := os.Open(path)
  exit_error(err)
  reader := bufio.NewReader(file)
  scanner := bufio.NewScanner(reader)
  for scanner.Scan() {
    elem := parse_line(scanner.Text())
    /* Ignore invalid lines or scans by bots */
    if elem[0] == "" || S.Contains( S.ToLower(elem[3]), "bot") { continue }
    /* Now add this entry into the hash */
    add_to_hash(elem, hash)
  }
  file.Close()
  if tmpfile != "" {
    os.Remove(tmpfile)
  }
}

func parse_line(text string) []string {
  /* Function to parse an nginx access log line into: */
  /* IP, Date, Path, Method */
  line := make([]string, 4)
  if S.Contains(text, " - - [") {
   words := regexp.MustCompile(`[^\s"']+|"([^"]*)"|'([^']*)`).FindAllString(text, -1)
   /* Pull out the IP */
    line[0] = S.Split(text, " ")[0]
  /* Pull out the date */
    line[1] = S.Split(text, "[")[1]
    line[1] = S.Split(line[1], ":")[0]
  /* Pull out the path */
    line[2] = S.Split(words[5], " ")[1]
      tmp, _ := url.Parse(line[2])
      line[2] = tmp.EscapedPath()
    line[2] = S.ToLower(line[2])
  /* Pull out the method */
    line[3] = S.Replace(words[9],"\"", "", -1)
  }
  return line
}

func add_to_hash( elem []string, hash map[string]string) {
  /* Daily index first */
  combo := elem[1]+","+elem[2]
  if ! S.Contains(hash[combo], elem[0]) {
    hash[combo] =S.Join( append(S.Split(hash[combo],","), elem[0]), ",")
  }
  /* Now Monthly index */
  combo = S.Replace(elem[1], S.Split(elem[1],"/")[0]+"/", "", 1) + ","+elem[2]
  if ! S.Contains(hash[combo], elem[0]) {
    hash[combo] =S.Join( append(S.Split(hash[combo],","), elem[0]), ",")
  }
}

func print_hash(hash map[string]string){
  fmt.Println("{")
  first := true
  val := ""
  for key := range hash {
    val = ""
    if first != true { 
      val = ","
    } else { 
      first = false
    }
    val = val+"\""+key+"\" : "+ strconv.Itoa( num_unique_items( S.Split(hash[key],",") ) )
    fmt.Println(val)
  }
  fmt.Println("}")
}

func num_unique_items(s []string) int {
	seen := make(map[string]struct{}, len(s))
	j := 0
	for _, v := range s {
		if v == "" { continue }
		if _, ok := seen[v]; ok {
			continue
		}
		seen[v] = struct{}{}
		s[j] = v
		j++
	}
	return len(s[:j])
}

func main() {
  hash := make(map[string]string)
  args := os.Args[1:]
  for _, path := range args {
    read_file(path, hash)
  }
  print_hash(hash)
}
