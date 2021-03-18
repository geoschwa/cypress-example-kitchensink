#!/usr/bin/env bash
# generates test cases for jira xray import from cypress tests

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
tf_out_dir="${script_dir}/../_tf_out/"
wrk_dir="${script_dir}/../_wrk/"

SINGLEFILE=0
DEBUG=0
TEST=0
TESTCNT=0

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-f] -p param_value arg1 [arg2...]

Script description here.

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-D, --debug     Debug flag tmp files getting not deleted
-T, --test      just some testing of this skripts
-d, --directory Directory of Tests
-F, --file      Single file to genereate
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  #flag=0
  dparam=''
  fparam=''
  RUNFLAGS=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -D | --debug) 
        DEBUG=1
        RUNFLAGS="${RUNFLAGS} -D"
      ;; # DEBUG flag
    -T | --test) TEST=1 ;; # TEST flag
    -d | --directory) # where the testcases are found
        dparam="${2-}"
        shift
      ;;
    -F | --file)  # genereate testcases only from this specific file
        fparam="${2-}"
        shift
        SINGLEFILE=1
        RUNFLAGS="${RUNFLAGS} -F"
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")
  #echo ${#args[@]}

  # check required params and arguments
  [[ -z "${dparam-}" ]] && die "Missing required parameter: dparam"
  if [[ ${SINGLEFILE} -eq 1 ]]
  then
    [[ -z "${fparam-}" ]] && die "Missing required parameter: fparam"
  fi
  # [[ ${#args[@]} -eq 0 ]] && die "Missing script arguments"

  return 0
}

function parse_tf() {
    # $1 = file to parse
    if [[ ${DEBUG} -eq 1 ]]
    then
      msg "${PURPLE}debug:${1} ${NOFORMAT}"
    fi
    cur_tmp=$(mktemp -p ${wrk_dir})
    if [[ ${TEST} -eq 1 ]]
    then
        echo testcount ${TESTCNT}
        TESTCNT=$(((${TESTCNT}+1)))
        echo testcount ${TESTCNT}
        sed -e 's/^[[:space:]]*//' ${1} | egrep "^context|^describe|^specify|^it|should|expect" | while read line
        do
            echo "tba" >/dev/null 2>&1
        done > ${cur_tmp}
    else
        sed -e 's/^[[:space:]]*//' ${1} | egrep "^context|^describe|^specify|^it|should|expect" | egrep -v "^//"> ${cur_tmp}
    fi
    # write header in csv file
    echo "jira id;Testfallbezeichner;Pfad zum Testrepositorium;Zusammenfassung;\"Link \"\"Tests\"\"\";Lösungsversion;Beschreibung;Lösung;Autor;Status;Step Number;Schritt / Beschreibung (Design Steps);Testdaten;Erwartetes Ergebnis / Erwartet (Design Steps);Step-Attachments" > ${tf_out_dir}/tf_$(basename ${1}).csv
    ${script_dir}/parse.awk -v orgfile=${1} ${cur_tmp} >> ${tf_out_dir}/tf_$(basename ${1}).csv

    msg "${YELLOW}removing unwanted entries${NOFORMAT}"
    awk -F";" '{ print $12 }' ${tf_out_dir}/tf_$(basename ${1}).csv | sort -u > ${wrk_dir}/$(basename ${1}).steps
    awk -F";" '{ print $12 }' ${tf_out_dir}/tf_$(basename ${1}).csv | sort -u | while read step
    do
      if [[ $(grep -c ";${step}" ${tf_out_dir}/tf_$(basename ${1}).csv) -gt 1 ]]
      then
        if [[ ${DEBUG} -eq 1 ]]
        then
          echo "debug:${step}#"
        fi
        sed -i -e "/;${step};OK/d" ${tf_out_dir}/tf_$(basename ${1}).csv
      else
        continue
      fi
    done
    msg "${GREEN}testcases successfully created --> ${tf_out_dir}/tf_$(basename ${1}).csv"

    if [[ ${DEBUG} -eq 0 ]]
    then
        rm -f ${cur_tmp}
    fi
}

parse_params "$@"
setup_colors

# script logic here

msg "${RED}Read parameters:${NOFORMAT}"
# msg "- flag: ${flag}"
msg "- dparam: ${dparam}"
msg "- fparam: ${fparam}"
msg "- flags: ${RUNFLAGS}"
msg "- arguments: ${args[*]-}"

if [[ ! -d ${dparam} ]]
then
    die "directory ${dparam} not found or accessible" 1
fi

for dir in ${tf_out_dir} ${wrk_dir}
do
    if [[ ! -d ${dir} ]]
    then
        mkdir -p ${dir}
    fi
done


pushd ${dparam} >/dev/null 2>&1

if [[ ${SINGLEFILE} -eq 1 ]]
then
    files2parse="${fparam}"
else
    files2parse="$(find . -type f -name "*.spec.js")"
fi

for f in ${files2parse}
do
    msg "${YELLOW}parsing ${f} ${NOFORMAT}"
    parse_tf ${f}
done



exit 0