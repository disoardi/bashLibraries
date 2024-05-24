#!/usr/bin/env bash
#
# SCRIPT: Bash libraries
# AUTHOR: Davide Isoardi
#
# TODO: Completare funzione di recupero releas from git
#       UPDATE
# 12/12/2023    Add function to get release from private repo
# 27/11/2023    add existsInList to check if argument is in a list


fnGetProperties() {
  # example of usage
  # fnGetProperties <properties> <file.properties>
  if [ ! $# -eq 2 ]; then
      eerror "$FUNCNAME --> Errore: numero di parametri non corretto"
      exit 1
  fi
  if [ ! -f ${2} ]; then
      eerror "$FUNCNAME --> Errore: file.properties non trovato - ${${2}}"
      exit 1
  fi
  return $(grep "^${1}" "${2}"|cut -d'=' -f2)
}

fnExistsInList() {
  # example of usage
  # fnExistsInList <list> <delimiter> <value>
  LIST=$1
  DELIMITER=$2
  VALUE=$3
  [[ "$LIST" =~ ($DELIMITER|^)$VALUE($DELIMITER|$) ]]
}

fnWaitAnswer(){
  # example of usage
  # fnWaitAnswer <question>
  if [ ! $# -eq 1 ]; then
    ecrit "Errore: numero di parametri non corretto"
    ecrit "FUNCNAME si aspetta una domanda da porre!"
    exit 1
  fi
  
  read -p "${1} [y]/n " VAR
  if [[ ${VAR,,} == "n" ]]; then
    einfo "Interrrotto dall'utente."
    exit 1
  elif [[ ${VAR,,} == "y" ]]; then
    einfo "Continuo..."
    fnSleepProgress 3
  else
    ecrit "Risposta non contemplata!"
    ecrit "exit 1"
    exit 1
  fi
}

fnGitGetRelease() {
    # example of usage
    # ./get_gh_asset.sh :owner :repo :tag :name
    # Need file with git credential named .secrets

    CWD="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

    # Check dependencies.
    set -e
    type curl grep sed tr >&2
    xargs=$(which gxargs || which xargs)

    # Validate settings.
    [ -f ~/.secrets ] && source ~/.secrets
    [ "$GITHUB_API_TOKEN" ] || { ecrit "${FUNCNAME} - Error: Please define GITHUB_API_TOKEN variable." >&2; exit 1; }
    [ $# -ne 4 ] && { echo "Usage: $0 [owner] [repo] [tag] [name]"; exit 1; }
    [ "$TRACE" ] && set -x
    read owner repo tag name <<<$@

    # Define variables.
    GH_API="https://api.github.com"
    GH_REPO="$GH_API/repos/$owner/$repo"
    GH_TAGS="$GH_REPO/releases/tags/$tag"
    AUTH="Authorization: token $GITHUB_API_TOKEN"
    WGET_ARGS="--content-disposition --auth-no-challenge --no-cookie"
    CURL_ARGS="-LJO#"

    # Validate token.
    curl -o /dev/null -sH "$AUTH" $GH_REPO || { ecrit "${FUNCNAME} - Error: Invalid repo, token or network issue!";  exit 1; }

    # Read asset tags.
    response=$(curl -sH "$AUTH" $GH_TAGS)
    # Get ID of the asset based on given name.
    eval $(echo "$response" | grep -C3 "name.:.\+$name" | grep -w id | tr : = | tr -cd '[[:alnum:]]=')
    #id=$(echo "$response" | jq --arg name "$name" '.assets[] | select(.name == $name).id') # If jq is installed, this can be used instead. 
    [ "$id" ] || { ecrit "${FUNCNAME} - Error: Failed to get asset id, response: $response" | awk 'length($0)<100' >&2; exit 1; }
    GH_ASSET="$GH_REPO/releases/assets/$id"

    # Download asset file.
    echo "Downloading asset..." >&2
    curl $CURL_ARGS -H "Authorization: token $GITHUB_API_TOKEN" -H 'Accept: application/octet-stream' "$GH_ASSET"
    echo "$0 done." >&2
}

fnCheckCMD() {
    local cmd=$1
    if command -v "$cmd" &> /dev/null; then
        einfo "Command '$cmd' is installed."
        return 0
    else
        ecrit "Command '$cmd' is not installed."
        return 1
    fi
}

fnWaitYToContinue (){
    read -p "Continuo? [y]/n " VAR
    if [[ $VAR == "n" ]]; then
        einfo "Interrrotto dall'utente."
        exit 1
    else
        einfo "Continuo..."
        fnSleepProgress 3
    fi
}

fnPrintIfSet () {
    if [ -n "$1" ]; then
        einfo "$1"
    else
        ecrit "$0: Var is not set"
        exit 1
    fi
}

######################################
#           Simple Spinner           #
######################################
spinner_pid=

function fnStartSpinner {
    set +m
    echo -n "$1         "
    { while : ; do for X in '  •     ' '   •    ' '    •   ' '     •  ' '      • ' '     •  ' '    •   ' '   •    ' '  •     ' ' •      ' ; do echo -en "\b\b\b\b\b\b\b\b$X" ; sleep 0.1 ; done ; done & } 2>/dev/null
        spinner_pid=$!
    }

function fnStopSpinner {
    { kill -9 $spinner_pid && wait; } 2>/dev/null
        set -m
        echo -en "\033[2K\r"
    }

fnSleepProgress () {
    fnStartSpinner
    sleep $1
    fnStopSpinner

}

######################################


######################################
#          Complex Spinner           #
######################################
# clone from https://github.com/swelljoe/spinner 
# shellcheck disable=SC2034 disable=SC2039
# Config variables, set these after sourcing to change behavior.
SPINNER_COLORNUM=2 # What color? Irrelevent if COLORCYCLE=1.
SPINNER_COLORCYCLE=1 # Does the color cycle?
SPINNER_DONEFILE="stopspinning" # Path/name of file to exit on.
SPINNER_SYMBOLS="UNI_DOTS2" # Name of the variable containing the symbols.
SPINNER_CLEAR=1 # Blank the line when done.

# Handle signals
cleanup () {
    tput rc
    tput cnorm
    return 1
}
# This tries to catch any exit, to reset cursor
trap cleanup INT QUIT TERM

spinner () {
    # Safest option are one of these. Doesn't need Unicode, at all.
    local ASCII_PROPELLER="/ - \\ |"
    local ASCII_PLUS="x +"
    local ASCII_BLINK="o -"
    local ASCII_V="v < ^ >"
    local ASCII_INFLATE=". o O o"

  # Needs Unicode support in shell and terminal.
  # These are ordered most to least likely to be available, in my limited experience.
  local UNI_DOTS="⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏"
  local UNI_DOTS2="⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷"
  local UNI_DOTS3="⣷ ⣯ ⣟ ⡿ ⢿ ⣻ ⣽ ⣾"
  local UNI_DOTS4="⠋ ⠙ ⠚ ⠞ ⠖ ⠦ ⠴ ⠲ ⠳ ⠓"
  local UNI_DOTS5="⠄ ⠆ ⠇ ⠋ ⠙ ⠸ ⠰ ⠠ ⠰ ⠸ ⠙ ⠋ ⠇ ⠆"
  local UNI_DOTS6="⠋ ⠙ ⠚ ⠒ ⠂ ⠂ ⠒ ⠲ ⠴ ⠦ ⠖ ⠒ ⠐ ⠐ ⠒ ⠓ ⠋"
  local UNI_DOTS7="⠁ ⠉ ⠙ ⠚ ⠒ ⠂ ⠂ ⠒ ⠲ ⠴ ⠤ ⠄ ⠄ ⠤ ⠴ ⠲ ⠒ ⠂ ⠂ ⠒ ⠚ ⠙ ⠉ ⠁"
  local UNI_DOTS8="⠈ ⠉ ⠋ ⠓ ⠒ ⠐ ⠐ ⠒ ⠖ ⠦ ⠤ ⠠ ⠠ ⠤ ⠦ ⠖ ⠒ ⠐ ⠐ ⠒ ⠓ ⠋ ⠉ ⠈"
  local UNI_DOTS9="⠁ ⠁ ⠉ ⠙ ⠚ ⠒ ⠂ ⠂ ⠒ ⠲ ⠴ ⠤ ⠄ ⠄ ⠤ ⠠ ⠠ ⠤ ⠦ ⠖ ⠒ ⠐ ⠐ ⠒ ⠓ ⠋ ⠉ ⠈ ⠈"
  local UNI_DOTS10="⢹ ⢺ ⢼ ⣸ ⣇ ⡧ ⡗ ⡏"
  local UNI_DOTS11="⢄ ⢂ ⢁ ⡁ ⡈ ⡐ ⡠"
  local UNI_DOTS12="⠁ ⠂ ⠄ ⡀ ⢀ ⠠ ⠐ ⠈"
  local UNI_BOUNCE="⠁ ⠂ ⠄ ⠂"
  local UNI_PIPES="┤ ┘ ┴ └ ├ ┌ ┬ ┐"
  local UNI_HIPPIE="☮ ✌ ☺ ♥"
  local UNI_HANDS="☜ ☝ ☞ ☟"
  local UNI_ARROW_ROT="➫ ➭ ➬ ➭"
  local UNI_CARDS="♣ ♤ ♥ ♦"
  local UNI_TRIANGLE="◢ ◣ ◤ ◥"
  local UNI_SQUARE="◰ ◳ ◲ ◱"
  local UNI_BOX_BOUNCE="▖ ▘ ▝ ▗"
  local UNI_PIE="◴ ◷ ◶ ◵"
  local UNI_CIRCLE="◐ ◓ ◑ ◒"
  local UNI_QTR_CIRCLE="◜ ◝ ◞ ◟"

  # Bigger spinners and progress type bars; takes more space.
  local WIDE_ASCII_PROG="[>----] [=>---] [==>--] [===>-] [====>] [----<] [---<=] [--<==] [-<===] [<====]"
  local WIDE_ASCII_PROPELLER="[|####] [#/###] [##-##] [###\\#] [####|] [###\\#] [##-##] [#/###]"
      local WIDE_ASCII_SNEK="[>----] [~>---] [~~>--] [~~~>-] [~~~~>] [----<] [---<~] [--<~~] [-<~~~] [<~~~~]"
        local WIDE_UNI_GREYSCALE="░░░░░░░ ▒░░░░░░ ▒▒░░░░░ ▒▒▒░░░░ ▒▒▒▒░░░ ▒▒▒▒▒░░ ▒▒▒▒▒▒░ ▒▒▒▒▒▒▒ ▒▒▒▒▒▒░ ▒▒▒▒▒░░ ▒▒▒▒░░░ ▒▒▒░░░░ ▒▒░░░░░ ▒░░░░░░ ░░░░░░░"
        local WIDE_UNI_GREYSCALE2="░░░░░░░ ▒░░░░░░ ▒▒░░░░░ ▒▒▒░░░░ ▒▒▒▒░░░ ▒▒▒▒▒░░ ▒▒▒▒▒▒░ ▒▒▒▒▒▒▒ ░▒▒▒▒▒▒ ░░▒▒▒▒▒ ░░░▒▒▒▒ ░░░░▒▒▒ ░░░░░▒▒ ░░░░░░▒"

        local SPINNER_NORMAL
        SPINNER_NORMAL=$(tput sgr0)

        eval SYMBOLS=\$${SPINNER_SYMBOLS}

  # Get the parent PID
  SPINNER_PPID=$(ps -p "$$" -o ppid=)
  while :; do
      tput civis
      for c in ${SYMBOLS}; do
          if [ $SPINNER_COLORCYCLE -eq 1 ]; then
              if [ $SPINNER_COLORNUM -eq 7 ]; then
                  SPINNER_COLORNUM=1
              else
                  SPINNER_COLORNUM=$((SPINNER_COLORNUM+1))
              fi
          fi
          local COLOR
          COLOR=$(tput setaf ${SPINNER_COLORNUM})
          tput sc
          env printf "${COLOR}${c}${SPINNER_NORMAL}"
          tput rc
          if [ -f "${SPINNER_DONEFILE}" ]; then
              if [ ${SPINNER_CLEAR} -eq 1 ]; then
                  tput el
              fi
              rm ${SPINNER_DONEFILE}
              break 2
          fi
          # This is questionable. sleep with fractional seconds is not
          # always available, but seems to not break things, when not.
          env sleep .2
          # Check to be sure parent is still going; handles sighup/kill
          if [ ! -z "$SPINNER_PPID" ]; then
              # This is ridiculous. ps prepends a space in the ppid call, which breaks
              # this ps with a "garbage option" error.
              # XXX Potential gotcha if ps produces weird output.
              # shellcheck disable=SC2086
              SPINNER_PARENTUP=$(ps --no-headers $SPINNER_PPID)
              if [ -z "$SPINNER_PARENTUP" ]; then
                  break 2
              fi
          fi
      done
  done
  tput cnorm
  return 0
}

######################################
#          Complex Spinner           #
######################################
# cloned from https://github.com/swelljoe/run_ok
#TODO: da riadattae al log system generale

SPINNER_COLORCYCLE=0
SPINNER_COLORNUM=5
SPINNER_SYMBOLS="WIDE_UNI_GREYSCALE2"
#SPINNER_SYMBOLS="WIDE_ASCII_PROG"
SPINNER_CLEAR=0 # Don't blank the line, so our check/x can simply overwrite it.

# Some colors and formatting constants
# used in run_ok function.
if type 'tput' > /dev/null; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    REDBG=$(tput setab 1)
    GREENBG=$(tput setab 2)
    YELLOWBG=$(tput setab 3)
    NORMAL=$(tput sgr0)
else
    echo "tput not found, colorized output disabled."
    RED=''
    GREEN=''
    YELLOW=''
    REDBG=''
    GREENBG=''
    YELLOWBG=''
    NORMAL=''
fi

#RUN_LOG="test.log"
dtNow=$(date +"%Y-%m-%d_%H%M%S")
RUN_LOG="${dtNow}-run.log"


# Check for unicode support in the shell
# This is a weird function, but seems to work. Checks to see if a unicode char can be
# written to a file and can be read back.
shell_has_unicode () {
    # Write a unicode character to a file...read it back and see if it's handled right.
    env printf "\u2714"> unitest.txt

    read unitest < unitest.txt
    rm unitest.txt
    if [ ${#unitest} -le 3 ]; then
        return 0
    else
        return 1
    fi
}

# Perform an action, log it, and print a colorful checkmark or X if failed
# Returns 0 if successful, $? if failed.
run_ok () {
    # Shell is really clumsy with passing strings around.
    # This passes the unexpanded $1 and $2, so subsequent users get the
    # whole thing.
    local cmd="\${1}"
    local msg="${2}"
    local columns=$(tput cols)
    if [ $columns -ge 80 ]; then
        columns=80
    fi
    COL=$(( ${columns}-${#msg}+${#GREENBG}+${#NORMAL} ))

    printf "%s%${COL}s" "$2"
    # Make sure there some unicode action in the shell; there's no
    # way to check the terminal in a POSIX-compliant way, but terms
    # are mostly ahead of shells.
    # Unicode checkmark and x mark for run_ok function
    CHECK='\u2714'
    BALLOT_X='\u2718'
    (spinner &)
    eval ${cmd} >> ${RUN_LOG}
    local res=$?
    touch stopspinning
    while [ -f stopspinning ]; do
        sleep .2 # It's possible to have a race for stdout and spinner clobbering the next bit
    done
    # Log what we were supposed to be running
    printf "$msg: " >> ${RUN_LOG}
    if shell_has_unicode; then
        if [ $res -eq 0 ]; then
            printf "Success.\n" >> ${RUN_LOG}
            env printf "${GREENBG}[  ${CHECK}  ]${NORMAL}\n"
            return 0
        else
            printf "Failed with error: ${res}\n" >> ${RUN_LOG}
            env printf "${REDBG}[  ${BALLOT_X}  ]${NORMAL}\n"
            return $res
        fi
    else
        if [ $res -eq 0 ]; then
            printf "Success.\n" >> ${RUN_LOG}
            env printf "${GREENBG}[ OK! ]${NORMAL}\n"
            return 0
        else
            printf "Failed with error: ${res}\n" >> ${RUN_LOG}
            env printf "${REDBG}[ERROR]${NORMAL}\n"
            return $res
        fi
    fi
}
