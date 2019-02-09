#!/bin/sh

#NGINX logs scaper to determine unique visitors per day/month for a particular file
_action="$1"

_cache="/tmp/.statcache"
LC_ALL="C" #make grep go a little bit faster without UTF8

show_usage(){
  echo "stats_analyze.sh Usage: 
  \"--scan <nginx logfile> <filename regex>\" : Analyze the logfile for the designated filename(s)
  \"--results [results.json]\" : Scan the cache to generate a JSON object with all the results.
  \"--clean\" : Delete the cache directory
  "
}

add_to_cache(){
  local _date=$(echo "${1}" | sed "s|\/|_|g")
  local _month=$(echo "${_date}" | cut -d _ -f 2-3)
  local _systemID="$2"
  local _filename=`echo "$3" | sed "s|\/|_|g" | tr '[:upper:]' '[:lower:]'`

  local _tmpcache="${_cache}/${_filename}"
  if [ ! -d "${_tmpcache}" ] ; then
    mkdir -p "${_tmpcache}"
  fi
  #Now add this to the day/month files
  if [ ! -e "${_tmpcache}/${_date}" ] ; then
    echo "Starting Day: ${_date} : File: ${_filename}"
  fi
  grep -qsF "${_systemID}\\n" "${_tmpcache}/${_date}"
  if [ $? -ne 0 ] ; then 
    echo "${_systemID}" >> "${_tmpcache}/${_date}"
  fi
  grep -qsF "${_systemID}\\n" "${_tmpcache}/${_month}"
  if [ $? -ne 0 ] ; then 
    echo "${_systemID}" >> "${_tmpcache}/${_month}"
  fi
}

#Read the nginx logfile
scan_logfile(){
  local _log="$1"
  local _fileregex="$2"

  echo "Starting to read logfile: ${_log}"
  while read -r line ; do
    echo "${line}" | grep -qE "( - - \\[)"
    if [ $? -ne 0 ] ; then continue ; fi #not a valid nginx access entry (internal logging for nginx - skip it)
    if [ -n "${_fileregex}" ] ; then
      echo "${line}" | grep -qE "${_fileregex}"
      if [ $? -ne 0 ] ; then continue ; fi #not a file we were asked to track
    fi
    #Pull out all the important pieces of the log
    _ip=$(echo "${line}" | cut -w -f 1) #IP address from entry
    _date=$(echo "${line}" | cut -d "[" -f 2 | cut -d : -f 1) #Date from entry: 01/Jan/2019
    _path=$(echo "${line}" | cut -d '"' -f 2 | cut -w -f 2)
    _method=$(echo "${line}" | cut -d '"' -f 6)
    #echo "IP: ${_ip} DATE: ${_date} FILE: ${_path} METHOD: ${_method}"
    #break
    add_to_cache "${_date}" "${_ip}" "${_path}"
  done < "${_log}"
  echo " - done"
}

create_json_from_cache(){
  local jsfile="$1"
  if [ -z "${jsfile}" ] ; then jsfile="results.json" ; fi
  if [ -d "${_cache}" ] ; then
    #Assemble the JSON output from the cache files
    local _json="{"
    found=0
    for dir in `ls "${_cache}"`
    do
      if [ ${found} -ne 1 ] ; then
        found=1 ; 
      else
        _json="${_json}," #need a comma between fields
      fi
      _json="${_json} \"${dir}\" : {"
      dtfound=0
      for dt in `ls "${_cache}/${dir}"`
      do
        if [ ${dtfound} -ne 1 ] ; then
          dtfound=1 ; 
        else
          _json="${_json}," #need a comma between fields
        fi
        count=`wc -l "${_cache}/${dir}/${dt}" | cut -w -f 2`
        _json="${_json} \"${dt}\" : ${count}"
        #echo "Got File Stats: ${dir} : ${dt} : ${count}"
      done #end loop over dt
      _json="${_json}}"
    done #end loop over dir
    #Delete the cache files
    _json="${_json}}"
  echo "${_json}" > "${jsfile}"
  echo "Results available: ${jsfile}"
  fi
}

clear_cache(){
  rm -r "${_cache}"
}

case ${_action} in
	--clean)
	  	clear_cache
	  	;;
	--scan)
		scan_logfile "$2" "$3"
		;;
	--results)
		create_json_from_cache "$2"
		;;
	*)
		show_usage
		;;
esac
exit $?
