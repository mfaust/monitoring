#!/bin/bash

#set -x

# export LC_ALL=en_US.UTF-8
# export LANG=en_US.UTF-8

# ----------------------------------------------------------------------------------------

SCRIPTNAME=$(basename $0 .sh)
VERSION="1.1.0"
VDATE="10.02.2016"

# ----------------------------------------------------------------------------------------

NRPE_DEFAULTS="/usr/lib/nagios/plugins/utils.sh"

[ -f "${NRPE_DEFAULTS}" ] && {
  . ${NRPE_DEFAULTS}
} || {
#   echo "nrpe defaults missing"

  STATE_OK=0
  STATE_WARNING=1
  STATE_CRITICAL=2
  STATE_UNKNOWN=3
  STATE_DEPENDENT=4
}

HOST=
JOB=
JOBLIST=
JOBS_CRIT=
JOBS_WARN=

# ----------------------------------------------------------------------------------------

version() {

  help_format_title="%-9s %s\n"

  echo ""
  printf  "$help_format_title" "HTTP Check"
  echo ""
  printf  "$help_format_title" " Version $VERSION ($VDATE)"
  echo ""
}

usage() {

  help_format_title="%-9s %s\n"
  help_format_desc="%-9s %-10s %s\n"
  help_format_example="%-9s %-30s %s\n"

  version

  printf  "$help_format_title" "Usage:" "$SCRIPTNAME [-h] [-v] [-H Host] [-P Port] [-s] [-S] [-u] [-g]"

  printf  "$help_format_desc"  ""       "-h" ": Show this help"
  printf  "$help_format_desc"  ""       "-v" ": Prints out the Version"
  printf  "$help_format_desc"  ""       "-H" ": Host name argument for servers using host headers"
  printf  "$help_format_desc"  ""       "-s" ": String to expect in the content"
  printf  "$help_format_desc"  ""       "-S" ": Connect via SSL (default false)"
  printf  "$help_format_desc"  ""       "-u" ": URL to GET (default: /)"
  printf  "$help_format_desc"  ""       "-g" ": check gziped Content (default false)"
}

# ----------------------------------------------------------------------------------------

buildUrl() {

  local job="${1}"

  STR_ARRAY=($(echo ${job} | sed -e 's|/|\n|g'))

#  echo ${#STR_ARRAY[@]}

  if [ ${#STR_ARRAY[@]} -gt 1 ]
  then
    # Can the match and replacement strings be parameterized?
    match=${STR_ARRAY[0]}
    repl=${STR_ARRAY[0]}/job

    url=${job/${match}/${repl}}

  else
    url="${job}"
  fi

  echo ${url}
}


check() {

  color=$(curl ${curl_opts} https://${HOST}/job/${url}/api/json?pretty=true 2> /dev/null | jq --raw-output '.color')

  echo "${color}"
#
# #  echo $result
#
#   if [ "${color}" == "blue" ]
#   then
#     status="OKAY"
#     result=${STATE_OK}
#   elif [ "${color}" == "red" ]
#   then
#     status="CRITICAL"
#     result=${STATE_CRITICAL}
#   elif [[ ${color} =~ .*_anime$ ]]
#   then
#     status="RUNNING"
#     result=${STATE_OK}
#   else
#     status="unknown"
#     result=${STATE_UNKNOWN}
#   fi
#
#   echo "${status} Job ${JOB} (${color})"
#   exit ${result}
}

final() {

  local output="${1}"

  if [ "${output}" == "blue" ]
  then
    status="OKAY"
#     result=${STATE_OK}
  elif [ "${output}" == "red" ]
  then
    status="CRITICAL"
#     result=${STATE_CRITICAL}
    JOBS_CRIT="${JOBS_CRIT} ${JOB}"
  elif [[ ${color} =~ .*_anime$ ]]
  then
    status="RUNNING"
#     result=${STATE_OK}
  else
    status="unknown"
#     result=${STATE_UNKNOWN}
    JOBS_WARN="${JOBS_WARN} ${JOB}"
  fi

  echo "${JOB} (${status})"
}

# ----------------------------------------------------------------------------------------

run() {

  local curl_opts="--connect-timeout 10 --max-time 20 --verbose --location"

  local countFull=1
  local countOKAY=0
  local countCRITICAL=0
  local countUNKNOWN=0

  if [ ! -z ${JOB} ]
  then
    url=$(buildUrl ${JOB})
    result=$(check ${url})
    msg=$(final ${result})
  fi

  if [ ! -z ${JOBLIST} ]
  then
    # wandle den String in ein Array
    array=(${JOBLIST//,/ })

    for job in "${array[@]}"
    do
      JOB=${job}
      url=$(buildUrl ${job})
      result=$(check ${url})
      msg="${msg} $(final ${result}), "
    done
    msg=${msg::-2}

    countFull=${#array[@]}

#     $message="${countOKAY} OKAY, ${countFull} Jenkins Jobs
  fi

  countOKAY=$(echo "${msg}" | grep "OKAY" | wc -l )
  countCRITICAL=$(echo "${msg}" | grep "CRITICAL" | wc -l )
  countUNKNOWN=$(echo "${msg}" | grep "unknown" | wc -l )

  if [ ${countCRITICAL} -gt 0 ]
  then
    status="CRITICAL"
    result=${STATE_CRITICAL}
  elif [ ${countUNKNOWN} -gt 0 ]
  then
    status="WARNING"
    result=${STATE_WARNING}
  else
    status="OK"
    result=${STATE_OK}
  fi

#  echo "${JOB} => https://${HOST}/job/${url}/api/json?pretty=true"

  echo "${status}  ${countFull} Jenkins Job(s)  (${msg})"
  exit ${result}

}

# ----------------------------------------------------------------------------------------

# Parse parameters
while [ $# -gt 0 ]
do
  case "${1}" in
    -h|--help) shift
      usage;
      exit 0
      ;;
    -v|--version) shift
      version;
      exit 0
      ;;
    -H|--host)
      shift
      HOST="${1}"
      ;;
    -j|--job)
      shift
      JOB="${1}"
      ;;
    -l|--joblist)
      shift
      JOBLIST="${1}"
      ;;
    *)
      echo "Unknown argument: '${1}'"
      exit $STATE_UNKNOWN
      ;;
  esac
shift
done

# Check that required argument (metric) was specified
[ -z "${HOST}" ] && {
  echo "Usage error: 'host' parameter missing"
  usage
  exit ${STATE_UNKNOWN}
}

( [ -z "${JOB}" ] && [ -z "${JOBLIST}" ] ) && {
  echo "Usage error: 'job' or 'joblist' parameter missing"
  usage
  exit ${STATE_UNKNOWN}
}

#----------------------------------------------------------------------------------------

run

exit 0

# EOF

# for j in 7.0-release_windows-test-system seed; do  ~/bin/check_ci_jobs.sh  -H release-ci.coremedia.com -j $j; done
# for j in seed license-builder-7.0 license-builder-7.1 license-builder-7.5; do ~/bin/check_ci_jobs.sh  -H cm7-ci.coremedia.com -j $j; done
# for j in seed cookbooks/coremedia-zookeeper-cookbook job-node-stalker-plugin vsphere-reports cms-master-7.0-docker cms-master-7.1-docker cms-master-7.5-docker packer/moebius-packer-ephemeral-ami packer/moebius-packer-minimal-centos7-vmware-iso packer/moebius-packer-minimal-vmware-iso packer/moebius-packer-oracle-12  packer/moebius-packer-wcs-fep6-ci packer/moebius-packer-wcs-fep7-ci packer/moebius-packer-wcs-fep8-ci packer/moebius-packer-windows_2008_r2-vmware-iso packer/moebius-packer-windows_2012_r2-vmware-iso packer/moebius-packer-windows_7-vmware-iso packer/unused-files; do ~/bin/check_ci_jobs.sh  -H pc-ci.coremedia.com -j $j; done

# ~/bin/check_ci_jobs.sh  -H release-ci.coremedia.com -l seed,7.0-release_windows-test-system
# ~/bin/check_ci_jobs.sh  -H cm7-ci.coremedia.com -l license-builder-7.5,license-builder-7.1,license-builder-7.0,seed
# ~/bin/check_ci_jobs.sh  -H pc-ci.coremedia.com -l seed,cookbooks/coremedia-zookeeper-cookbook,job-node-stalker-plugin,vsphere-reports,cms-master-7.0-docker,cms-master-7.1-docker,cms-master-7.5-docker,packer/moebius-packer-ephemeral-ami,packer/moebius-packer-minimal-centos7-vmware-iso,packer/moebius-packer-minimal-vmware-iso,packer/moebius-packer-oracle-12,packer/moebius-packer-wcs-fep6-ci,packer/moebius-packer-wcs-fep7-ci,packer/moebius-packer-wcs-fep8-ci,packer/moebius-packer-windows_2008_r2-vmware-iso,packer/moebius-packer-windows_2012_r2-vmware-iso,packer/moebius-packer-windows_7-vmware-iso,packer/unused-files


# https://pc-ci.coremedia.com/job/seed
# https://pc-ci.coremedia.com/job/cookbooks/job/coremedia-zookeeper-cookbook
# https://pc-ci.coremedia.com/job/job-node-stalker-plugin
# https://pc-ci.coremedia.com/job/vsphere-reports
# https://pc-ci.coremedia.com/job/cms-master-7.0-docker
# https://pc-ci.coremedia.com/job/cms-master-7.1-docker
# https://pc-ci.coremedia.com/job/cms-master-7.5-docker
# https://pc-ci.coremedia.com/job/packer/job/moebius-packer-ephemeral-ami
# https://pc-ci.coremedia.com/job/packer/job/moebius-packer-minimal-centos7-vmware-iso
# https://pc-ci.coremedia.com/job/packer/job/moebius-packer-minimal-vmware-iso
# https://pc-ci.coremedia.com/job/packer/job/moebius-packer-oracle-12moebius-packer-oracle-12
# https://pc-ci.coremedia.com/job/packer/job/moebius-packer-wcs-fep6-ci
# https://pc-ci.coremedia.com/job/packer/job/moebius-packer-wcs-fep7-ci
# https://pc-ci.coremedia.com/job/packer/job/moebius-packer-wcs-fep8-ci
# https://pc-ci.coremedia.com/job/packer/job/moebius-packer-windows_2008_r2-vmware-iso
# https://pc-ci.coremedia.com/job/packer/job/moebius-packer-windows_2012_r2-vmware-iso
# https://pc-ci.coremedia.com/job/packer/job/moebius-packer-windows_7-vmware-iso
# https://pc-ci.coremedia.com/job/packer/job/unused-files
# https://cm7-ci.coremedia.com/job/seed
# https://cm7-ci.coremedia.com/job/license-builder-7.5
# https://cm7-ci.coremedia.com/job/license-builder-7.0
# https://cm7-ci.coremedia.com/job/license-builder-7.1
# https://release-ci.coremedia.com/job/seed
# https://release-ci.coremedia.com/job/7.0-release_windows-test-system
