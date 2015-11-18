#!/usr/bin/env bash

# event.sh
# Copyright (C) 2015 D630, GNU GPLv3
# <https://github.com/D630/event.sh>

# -- DEBUGGING.

#printf '%s (%s)\n' "$BASH_VERSION" "${BASH_VERSINFO[5]}" && exit 0
#set -o xtrace
#exec 2>> ~/event.sh.log
#set -o verbose
#set -o noexec
#set -o errexit
#set -o nounset
#set -o pipefail
#trap '(read -p "[$BASH_SOURCE:$LINENO] $BASH_COMMAND?")' DEBUG

#declare vars_base=$(set -o posix ; set)
#fgrep -v -e "$vars_base" < <(set -o posix ; set) | \
#egrep -v -e "^BASH_REMATCH=" \
#         -e "^OPTIND=" \
#         -e "^REPLY=" \
#         -e "^BASH_LINENO=" \
#         -e "^BASH_SOURCE=" \
#         -e "^FUNCNAME=" | \
#less

# -- FUNCTIONS.

Event::CheckCoprocs ()
{
        typeset -i err=1

        if
                [[ -n ${Status[pid_loop_file_coproc]} ]]
        then
                Event::Status 95 "file" "${Status[pid_loop_file_coproc]}"
                err=11
        else
                err=10
        fi

        if
                [[ -n ${Status[pid_loop_period_coproc]} ]]
        then
                Event::Status 95 "period" "${Status[pid_loop_period_coproc]}"
                err=${err}1
        else
                err=${err}0
        fi

        return "$err"
}

Event::CreateLog ()
{
        Event::Status 93 "${Options[file_log]}"
        >> "${Options[file_log]}"
}

Event::Help ()
{
        { typeset h=$(</dev/fd/0) ; } <<'HELP'
Usage:
        events.sh <options> [<arguments>]

Options:
        -f                      Work with file events via inotifywait(1)
        -h                      Show this instruction
        -i <info>               Input for postprocessing the inotifywait(1) out
                                put. Used with option -f
        -k                      Kill any coprocess and purge the spool file
        -C                      Indicate to set up an event loop in a coprocess
                                Used with options -[fp]
        -p                      Work with time events having periods configured
        -v                      Print version

Arguments:
        <info>                  See Manpage of inotifywait(1):
                                %w|%:e|%f

Environment variables:
        EVENT_LOG_FILE          ${XDG_DATA_HOME}/event/event.log
        EVENT_RC_FILE           ${XDG_CONFIG_HOME}/event/event.rc
        EVENT_SPOOL_FILE        ${XDG_DATA_HOME}/event/event.spool

Configs:
        Events[<int>_command]   Command list. Executed via setsid(1)
        Events[<int>_exclude]   BRE used with grep(1) to select non-matching
                                files in a watched folder. Delimiter: semicolon
                                (;)
        Events[<int>_file]      Watched filenames. Delimiter: pipe (|)
        Events[<int>_name]      Name of the connected subscripts
        Events[<int>_period]    Period in seconds
        Events[<int>_symbol]    Names of the inotify events. Delimiter: colon
                                (:)
        Options[delay]          Delay of the time loop in seconds
        Options[file_log]       Logfile
        Options[file_spool]     Spoolfile
HELP

        printf '%s\n' "$h"
}

Event::Kill ()
{
        [[ -n ${Status[file_spool]} ]] && {
                Event::Status 89 "${Status[file_spool]}"
                command sed -i '/^Status\[/d' "${Status[file_spool]}" 2>/dev/null
        }

        typeset p
        for p in ${Status[pid_loop_file_coproc]} ${Status[pid_loop_period_coproc]}
        do
                Event::Status 90 "$p"
                command pkill -TERM -P "$p"
        done
}

Event::CoprocFile ()
{
        Event::Prepare || return 1

        typeset -a \
                events_names \
                excludes \
                files \
                filter \
                input;

        typeset \
                job \
                info;

        shopt -s extglob

        events_names=( ${!Events[@]} )
        files=(
                ${events_names[@]//+([0-9])_@(command|exclude|name|period|symbol|time_last)/}
        )
        excludes=(
                ${events_names[@]//+([0-9])_@(command|file|name|period|symbol|time_last)/}
        )

        shopt -u extglob

        if
                (( ${#files[@]} ))
        then
                while
                        IFS='_' read -r event_number _
                do
                        filter+=(
                                ${Events[${event_number}_exclude]//;/$'\n'}
                        )
                        input+=(
                                ${Events[${event_number}_file]//|/ }
                        )
                done < <(
                        printf '%s\n' "${files[@]}"
                )
                Event::Postpare
                coproc _loop_file {
                        #trap 'Event::Kill' INT TERM QUIT EXIT
                        if
                                [[ -n ${Events[${excludes[0]}]} ]]
                        then
                                printf '%s\n' "${input[@]}" \
                                | command grep -vf <(
                                        printf '%s\n' "${filter[@]}"
                                )
                        else
                                printf '%s\n' "${input[@]}"
                        fi \
                        | tee >(Event::Status 88 $(</dev/fd/0)) \
                        | exec inotifywait -qm --format '%w|%:e|%f' --fromfile - \
                        | {
                                while
                                        read -r
                                do
                                        "${BASH_SOURCE[0]}" -fi "$REPLY"
                                        err=$?
                                        (( err == 100 )) && {
                                                source "${Status[file_spool]}" 2>/dev/null
                                                ( exec "${BASH_SOURCE[0]}" -Cfp & )
                                                Event::Kill
                                        }
                                done
                        }
                }
                Status[pid_loop_file_coproc]=$_loop_file_PID
                Event::Status 96 "file" "$_loop_file_PID"
                printf 'Status[pid_loop_file_coproc]=%s\n' "$_loop_file_PID" >> "${Status[file_spool]}"
        else
                Event::Status 83
        fi
}

Event::CoprocPeriod ()
{
        Event::Prepare || return 1
        Event::Postpare

        coproc _loop_period {
                #trap 'Event::Kill' INT TERM QUIT EXIT
                while
                        command sleep "${Options[delay]}"
                do
                        "${BASH_SOURCE[0]}" -p
                done
        }

        Status[pid_loop_period_coproc]=$_loop_period_PID
        Event::Status 96 "period" "$_loop_period_PID"
        printf 'Status[pid_loop_period_coproc]=%d\n' "$_loop_period_PID" >> "${Status[file_spool]}"
}

Event::Main ()
{
        typeset -i time_curr
        printf -v time_curr '%(%s)T' -1

        (( $# )) || Event::Status 79

        typeset -x +i LC_COLLATE=C

        typeset -A \
                Events \
                Functions \
                Options \
                Status;

        if
                [[ -n $EVENT_RC_FILE ]]
        then
                if
                        [[ -f $EVENT_RC_FILE ]]
                then
                        source "${Options[file_rc]:=${EVENT_RC_FILE}}"
                        #unset -v EVENT_RC_FILE
                else
                        Event::Status 91 "$EVENT_RC_FILE"
                fi
        else
                if
                        [[ -f ${Options[file_rc]:=${XDG_CONFIG_HOME}/event/event.rc} ]]
                then
                        source "${Options[file_rc]}"
                else
                        Event::Status 91 "${Options[file_rc]}"
                fi
        fi

        if
                [[ -n $EVENT_LOG_FILE ]]
        then
                Options[file_log]=$EVENT_LOG_FILE
                #unset -v EVENT_LOG_FILE
        else
                Options[file_log]=${Options[file_log]:-${XDG_DATA_HOME}/event/event.log}
        fi

        if
                [[ -n $EVENT_SPOOL_FILE ]]
        then
                Options[file_spool]=$EVENT_SPOOL_FILE
                #unset -v EVENT_SPOOL_FILE
        else
                Options[file_spool]=${Options[file_spool]:-${XDG_DATA_HOME}/event/event.spool}
        fi

        command mkdir -vp -- \
                "${Options[file_log]%/*}" \
                "${Options[file_spool]%/*}";

        Options[delay]=${Options[delay]:-60}

        typeset \
                opt \
                opts=:Cfhi:kpv;

        typeset -i j="$# - 1"

        while
                getopts $opts opt
        do
                case $opt in
                f)
                        Functions[f]=$(( j++ ))
                ;;
                i)
                        if
                                [[ $OPTARG == -* ]]
                        then
                                Event::Status 86 "$opt"
                        elif
                                [[ $OPTARG == [${opts//:/}] ]]
                        then
                                Event::Status 87 "$OPTARG"
                        else
                                Functions[i]=$OPTARG
                        fi
                ;;
                h)
                        Event::Help
                        exit $?
                ;;
                k)
                        Functions[k]=$(( j++ ))
                ;;
                C)
                        Functions[C]=$(( j++ ))
                ;;
                p)
                        Functions[p]=$(( j++ ))
                ;;
                v)
                        Event::Version
                        exit $?
                ;;
                :)
                        Event::Status 86 "$OPTARG"
                ;;
                \?)
                        Event::Status 80 "$OPTARG"
                esac
        done

        Functions[${Functions[f]:--}]=Event::Files
        Functions[${Functions[k]:--}]=Event::Kill
        Functions[${Functions[C]:--}]=Event::Coproc
        Functions[${Functions[p]:--}]=Event::Periods

        source "${Options[file_spool]}" 2>/dev/null

        typeset -i err=

        if
                [[ -n ${Functions[C]} && -z ${Functions[f]}${Functions[p]} ]]
        then
                Event::Status 84
        elif
                [[ -n ${Functions[k]} ]]
        then
                Functions=()
                Functions[0]=Event::Kill
        elif
                [[
                        -n ${Functions[C]} &&
                        -n ${Functions[f]} &&
                        -n ${Functions[p]}
                ]]
        then
                Event::CheckCoprocs
                err=$?
                if
                        (( err == 100 ))
                then
                        Functions=()
                        Functions[0]=Event::CoprocPeriod
                        Functions[1]=Event::CoprocFile
                else
                        exit 95
                fi
        elif
                [[ -n ${Functions[C]} && -n ${Functions[f]} ]]
        then
                Event::CheckCoprocs
                err=$?
                if
                        (( err == 110 || err == 111 ))
                then
                        exit 95
                else
                        Functions=()
                        Functions[0]=Event::CoprocFile
                fi
        elif
                [[ -n ${Functions[C]} && -n ${Functions[p]} ]]
        then
                Event::CheckCoprocs
                err=$?
                if
                        (( err == 101 || err == 111 ))
                then
                        exit 95
                else
                        Functions=()
                        Functions[0]=Event::CoprocPeriod
                fi
        elif
                [[
                        ( -n ${Functions[f]} && -n ${Functions[p]} ) ||
                        -n ${Functions[f]}
                ]]
        then
                Options[noloop]=noloop
                if
                        [[ -n ${Functions[i]} ]]
                then
                        Functions[${Functions[f]}]="Event::Files ${Functions[i]}"
                else
                        Event::Status 85
                fi
        elif
                [[ -n ${Functions[p]} ]]
        then
                Options[noloop]=noloop
        fi

        unset -v \
                Functions[--] \
                Functions[f] \
                Functions[i] \
                Functions[k] \
                Functions[C] \
                Functions[p];

        exec >>"${Options[file_log]}" 2>&1

        for (( opt=0 ; opt < $j ; opt++ ))
        do
                [[ -n ${Functions[$opt]} ]] && ${Functions[$opt]}
        done
}

Event::Postpare ()
{
        if
                (( ${#spool[@]} ))
        then
                printf '%s\n' "${spool[@]}" > "${Options[file_spool]}"
        else
                command sed -i '/^Status\[/d' "${Status[file_spool]}" 2>/dev/null
        fi

        Status[file_rc]=${Status[file_rc]:-${Options[file_rc]}}
        Status[file_spool]=${Status[file_spool]:-${Options[file_spool]}}

        typeset e
        for e in "${!Status[@]}"
        do
                printf 'Status[%s]=%s\n' "$e" "${Status[$e]}"
        done >> "${Status[file_spool]}"
}

Event::Prepare ()
{
        Status[file_spool]=${Options[file_spool]}

        if
                [[ -z ${Options[noloop]} ]]
        then
                Event::CreateLog
        fi
}

Event::Status ()
{
        typeset s

        case $1 in
        79) printf -v s '%s %s:Error:%s: No command specified\n' "$time_curr" "${BASH_SOURCE[0]}" "$1"                                                  ;;
        80) printf -v s '%s %s:Error:%s: Unknown flag: -%s\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "$2"                                                ;;
        81) printf -v s '%s %s:Error:%s: Config file missing\n' "$time_curr" "${BASH_SOURCE[0]}" "$1"                                                   ;;
        82) printf -v s '%s %s:Error:%s: Anacronistic commands missing\n' "$time_curr" "${BASH_SOURCE[0]}" "$1"                                         ;;
        83) printf      '%s %s:Error:%s: Inotify filenames missing\n' "$time_curr" "${BASH_SOURCE[0]}" "$1"                                             ;;
        84) printf -v s '%s %s:Error:%s: No loop specified\n' "$time_curr" "${BASH_SOURCE[0]}" "$1"                                                     ;;
        85) printf -v s '%s %s:Error:%s: No event information specified\n' "$time_curr" "${BASH_SOURCE[0]}" "$1"                                        ;;
        86) printf -v s '%s %s:Error:%s: Option -%s requires an argument\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "$2"                                  ;;
        87) printf -v s '%s %s:Error:%s: Wrong argument: %s\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "$2"                                               ;;
        88) printf      '%s %s:Info:%s: Watching: %s\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "${*:2}"                                                  ;;
        89) printf      '%s %s:Info:%s: Removing status information in spool: %s\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "$2"                          ;;
        90) printf      '%s %s:Info:%s: Killing pid: %s\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "$2"                                                   ;;
        91) printf -v s '%s %s:Error:%s: Conf File does not exist or is not a regular file: %s\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "$2"            ;;
        93) printf      '%s %s:Info:%s: Creating new logs in: %s\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "$2"                                          ;;
        94) printf      '%s %s:Info:%s: Processing command %s: %s\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "$2" "$3"                                    ;;
        95) printf      '%s %s:Info:%s: Coproc (%s) has already been started with pid: %s\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "$2" "$3"            ;;
        96) printf      '%s %s:Info:%s: Creating coproc (%s) with pid: %s\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "$2" "$3"                            ;;
        97) printf      '%s %s:Error:%s: Job is unknown: %s\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "$2"                                               ;;
        99) printf -v s '%s %s:Info:%s: Restarting coproc (file) with pid: %s\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "$2"                             ;;
        100) printf -v s '%s %s:Info:%s: Restarting coprocs (file, period) with pids: %s, %s\n' "$time_curr" "${BASH_SOURCE[0]}" "$1" "$2" "$3"         ;;
        102) printf -v s '%s %s:Error:%s: Event symbols missing\n' "$time_curr" "${BASH_SOURCE[0]}" "$1"                                                ;;
        esac 1>&2

        [[ -z $s ]] || {
                printf '%s' "$s" 1>&2
                exit "$1"
        }
}

Event::Files ()
{
        typeset \
                event_number \
                file \
                path \
                s \
                symbol;

        typeset -a \
                commands \
                events_names \
                files \
                symbols;

        IFS='|' read -r path symbol file <<< "$@"

        [[ $symbol == DELETE_SELF ]] && {
                if
                        [[
                                -n ${Status[pid_loop_file_coproc]} ||
                                -n ${Status[pid_loop_period_coproc]}
                        ]]
                then
                        Event::Status 100 "${Status[pid_loop_file_coproc]}" "${Status[pid_loop_period_coproc]}"
                else
                        Event::Kill
                        if
                                [[ -n ${Status[pid_loop_period]} ]]
                        then
                                Event::Status 100 "${Status[pid_loop_file]}" "${Status[pid_loop_period]}"
                        else
                                Event::Status 99 "${Status[pid_loop_file]}"
                        fi
                fi
        }

        shopt -s extglob

        events_names=( ${!Events[@]} )
        files=(
                ${events_names[@]//+([0-9])_@(command|exclude|name|period|symbol|time_last)/}
        )
        symbols=(
                ${events_names[@]//+([0-9])_@(command|exclude|file|name|period|time_last)/}
        )
        commands=(
                ${events_names[@]//+([0-9])_@(exclude|file|name|period|symbol|time_last)/}
        )

        shopt -u extglob

        if
                (( ${#files[@]} == 0 ))
        then
                Event::Status 83
        elif
                (( ${#commands[@]} == 0 ))
        then
                Event::Status 82
        elif
                (( ${#symbols[@]} == 0 ))
        then
                Event::Status 102
        else
                Status[time_run_last_file]=$time_curr
                while
                        IFS='_' read -r event_number _
                do
                        [[ ${Events[${event_number}_file]} =~ $path ]] && {
                                for s in ${Events[${event_number}_symbol]//:/ }
                                do
                                        [[ $symbol == $s ]] && {
                                                Event::Status 94 "${Events[${event_number}_name]}" "${Events[${event_number}_command]}"
                                                ( command setsid "${Events[${event_number}_command]}" & )
                                                break
                                        }
                                done
                                s=
                        }
                done < <(
                        printf '%s\n' "${files[@]}"
                )
                Event::Postpare
        fi
}

Event::Periods ()
{
        typeset -a \
                commands \
                spool;

        typeset -i \
                event_number \
                time_diff;

        shopt -s extglob

        commands=( ${!Events[@]} )
        commands=(
                ${commands[@]//+([0-9])_@(exclude|file|name|period|symbol|time_last)/}
        )

        (( ${#commands[@]} )) ||  Event::Status 82

        shopt -u extglob

        while
                IFS='_' read -r event_number _
        do
                time_diff="time_curr - ${Events[${event_number}_time_last]:-0}"
                if
                        (( ${Events[${event_number}_period]} ))
                then
                        Status[time_run_last_period]=$time_curr
                        if
                                (( time_diff >= ${Events[${event_number}_period]} ))
                        then
                                Event::Status 94 "${Events[${event_number}_name]}" "${Events[${event_number}_command]}"
                                ( command setsid "${Events[${event_number}_command]}" & )
                                spool+=(
                                        "Events[${event_number}_time_last]=${time_curr}"
                                )
                        else
                                spool+=(
                                        "Events[${event_number}_time_last]=${Events[${event_number}_time_last]}"
                                )
                        fi
                else
                        continue
                fi
        done < <(
                printf '%s\n' "${commands[@]}" \
                | sort -n
        )

        Event::Postpare
}

Event::Version ()
{
        printf 'v%s\n' "0.1.7"
}

# -- MAIN.

Event::Main "$@"

# vim: set ts=8 sw=8 tw=0 et :
