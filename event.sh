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

__event_check_loops ()
{
    declare -i err=1

    [[ ${options[file_queue]} == ${status[file_queue]} && ${status[pid_loop_fifo]} ]] && __event_status 95 "${options[file_queue]}" "${status[pid_loop_fifo]}"

    if [[ ${status[pid_loop_file]} ]]
    then
        __event_status 95 "file" "${status[pid_loop_file]}"
        err=11
    else
        err=10
    fi

    if [[ ${status[pid_loop_period]} ]]
    then
        __event_status 95 "period" "${status[pid_loop_period]}"
        err=${err}1
    else
        err=${err}0
    fi

    return "$err"
}

__event_create_file_log ()
{
    command cp -bvf -- "${options[file_log]}" "${options[file_log]}"
    __event_status 93 "${options[file_log]}"
    > "${options[file_log]}"
}

__event_help ()
{
    { declare h=$(</dev/fd/0) ; } <<-HELP
event.sh $(__event_version)

Usage:
    events.sh <options> [<arguments>]

Options:
    -c                      Do not use a fifo queue, instead work with
                            coprocesses.
    -f                      Work with file events
    -h                      Show this instruction
    -i <info>               Input for postprocessing the inotifywait file
                            loop with -f.
    -k                      Kill any loop and purge the spool file
    -l                      Indicate to set up an event loop. Used with
                            options -[fp]
    -n                      Do not use a fifo queue, when initiating an
                            event loop
    -p                      Work with time events having periods
                            configured
    -v                      Print version

Arguments:
    <info>                  See Manpage of inotifywait(1)
                            If feeding to the fifo loop:
                                FILE %w|%:e|%f
                            or
                                PERIOD %w|%:e|%f
                            In a another case only:
                                %w|%:e|%f

Environment variables:
    EVENT_LOG_FILE          \${XDG_DATA_HOME}/event.log
    EVENT_QUEUE_FILE        \${TMPDIR:-/tmp}/event.queue
    EVENT_RC_FILE           \${XDG_CONFIG_HOME}/event.rc
    EVENT_SPOOL_FILE        \${XDG_DATA_HOME}/event.spool

Configs:
    events[<int>_command]   Command list. Executed via eval
    events[<int>_exclude]   BRE used with grep(1) to skip files inside
                            the watched path. Delimiter: semicolon
    events[<int>_file]      Watched filenames. Delimiter: colon
    events[<int>_name]      Name of the connected subscripts
    events[<int>_period]    Period in seconds
    events[<int>_symbol]    Names of the inotify events. Delimiter: colon
    options[coproc]         Like option -c
    options[delay]          Delay of the time loop in seconds
    options[file_log]       Logfile
    options[file_queue]     Queuefile (fifo)
    options[file_spool]     Spoolfile
    options[nofifo]         Like option -n
HELP

    printf '%s\n' "$h"
}

__event_kill ()
{
    [[ -p ${status[file_queue]} ]] && {
        __event_status 88 "${status[file_queue]}"
        command rm -v -- "${status[file_queue]}"
    }

    [[ ${status[file_spool]} ]] && {
        __event_status 89 "${status[file_spool]}"
        command sed -i '/^status\[/d' "${status[file_spool]}"
    }

    declare -i p=
    for p in ${status[pid_loop_file_coproc]} ${status[pid_loop_period_coproc]} ${status[pid_loop_file]} ${status[pid_loop_period]} ${status[pid_loop_queue]}
    do
        __event_status 90 "$p"
        command pkill -TERM -P "$p"
    done
}

__event_loop_coproc ()
{
    exec 4> \
    >( \
        declare \
            job= \
            info=

        declare -i err=

        while read -r job info
        do
            if [[ $job == PERIOD ]]
            then
                event.sh -p
            elif [[ $job == FILE ]]
            then
                event.sh -fi "$info"
                err=$?
                ((err == 100)) && {
                    source "${status[file_spool]}"
                    (exec event.sh -lfpc &)
                    __event_kill
                }
            else
                printf '%s\n' "$(date +%s) ${0}:Error:97: Job is unknown: '${job}'"
            fi
        done
        unset -v \
            job \
            info
    )
}

__event_loop_fifo ()
{
    __event_status 92 "${options[file_queue]}"
    [[ -p ${options[file_queue]} || -f ${options[file_queue]} ]] && command rm -v -- "${options[file_queue]}"
    command mkfifo "${options[file_queue]}"
    status[file_queue]=${options[file_queue]}
    (exec event-fifo.sh "$time_curr" "${options[file_log]}" "${options[file_spool]}" "${status[file_queue]}" &)
}

__event_loop_file ()
{
    trap '__event_kill' EXIT

    __event_prepare

    declare -a \
        events_names=() \
        excludes=() \
        files=() \
        filter=() \
        input=()

    declare \
        job= \
        info=

    shopt -s extglob

    events_names=(${!events[@]})
    files=(${events_names[@]//+([0-9])_@(command|exclude|name|period|symbol|time_last)/})
    excludes=(${events_names[@]//+([0-9])_@(command|file|name|period|symbol|time_last)/})

    shopt -u extglob

    if ((${#files[@]} == 0))
    then
        __event_status 83
    else
        while IFS='_' read -r event_number _
        do
            filter+=($(printf '%s\n' "${events[${event_number}_exclude]//;/$'\n'}"))
            input+=($(printf '%s\n' "${events[${event_number}_file]//:/$'\n'}"))
        done < <(printf '%s\n' "${files[@]}")
        status[pid_loop_file]=$$
        __event_postpare
        __event_status 96 "file (inotifywait)" "$$"
        #(exec event-loop-file.sh "${status[file_spool]}" "${status[file_queue]}" &) < <(printf '%s\n' "${input[@]}" | grep -f <(printf '%s\n' "${filter[@]}"))
        if [[ ${options[nofifo]} == nofifo ]]
        then
            if [[ ${events[${excludes[0]}]} ]]
            then
                printf '%s\n' "${input[@]}" | \
                command grep -vf <(printf '%s\n' "${filter[@]}") | \
                command inotifywait -qm --format 'FILE %w|%:e|%f' --fromfile - | \
                while read -r job info
                do
                    event.sh -fi "$info"
                    (($? == 99)) && exec event.sh -lf
                done
            else
                printf '%s\n' "${input[@]}" | \
                command inotifywait -qm --format 'FILE %w|%:e|%f' --fromfile - | \
                while read -r job info
                do
                    event.sh -fi "$info"
                    (($? == 99)) && exec event.sh -lf
                done
            fi
        elif [[ ${options[coproc]} == coproc ]]
        then
            {
                coproc _loop_file {
                    if [[ ${events[${excludes[0]}]} ]]
                    then
                        printf '%s\n' "${input[@]}" | \
                        command grep -vf <(printf '%s\n' "${filter[@]}") | \
                        exec inotifywait -qm --format 'FILE %w|%:e|%f' --fromfile - | \
                        while read -r
                        do
                            printf '%s\n' "$REPLY"
                        done
                    else
                        printf '%s\n' "${input[@]}" | \
                        exec inotifywait -qm --format 'FILE %w|%:e|%f' --fromfile - |\
                        while read -r
                        do
                            printf '%s\n' "$REPLY"
                        done
                    fi
                } 1>&3 2>&1
            } 3>&4
            status[pid_loop_file_coproc]=$_loop_file_PID
            __event_status 96 "file (coproc)" "$_loop_file_PID"
            printf '%s\n' "status[pid_loop_file_coproc]=$_loop_file_PID" >> "${status[file_spool]}"
        else
            if [[ ${events[${excludes[0]}]} ]]
            then
                printf '%s\n' "${input[@]}" | \
                command grep -vf <(printf '%s\n' "${filter[@]}") | \
                command inotifywait -qm -o "${status[file_queue]}" --format 'FILE %w|%:e|%f' --fromfile -
            else
                printf '%s\n' "${input[@]}" | \
                command inotifywait -qm -o "${status[file_queue]}" --format 'FILE %w|%:e|%f' --fromfile -
            fi
        fi
    fi
}

__event_loop_period ()
{
    trap '__event_kill' EXIT

    __event_prepare
    status[pid_loop_period]=$$
    __event_postpare

    __event_status 96 "period" "$$"

    if [[ ${options[nofifo]} == nofifo ]]
    then
        while command sleep "${options[delay]}"
        do
            event.sh -p
        done
    elif [[ ${options[coproc]} == coproc ]]
    then
        {
            coproc _loop_period {
                while command sleep "${options[delay]}"
                do
                    printf '%s\n' "PERIOD"
                done
            } 1>&3 2>&1
        } 3>&4
        status[pid_loop_period_coproc]=$_loop_period_PID
        __event_status 96 "period (coproc)" "$_loop_period_PID"
        printf '%s\n' "status[pid_loop_period_coproc]=$_loop_period_PID" >> "${status[file_spool]}"
    else
        #(exec event-loop-period.sh "${options[file_spool]}" "${options[file_queue]}" &)
        exec 3<>"${options[file_queue]}"
        while command sleep "${options[delay]}"
        do
            printf '%s %d\n' "PERIOD" "$(date +%s)" 1>&3
        done
        exec 3<&-
        exec 3>&-
    fi
}

__event_main ()
{
    declare -gi "$(date +time_curr=%s)"

    (($# == 0)) && __event_status 79

    declare -x LC_COLLATE=C

    declare -gA \
        events=() \
        functions=() \
        options=() \
        status=()

    if [[ $EVENT_RC_FILE ]]
    then
        if [[ -f $EVENT_RC_FILE ]]
        then
            source "${options[file_rc]:=${EVENT_RC_FILE}}"
            unset -v $EVENT_RC_FILE
        else
            __event_status 91 "$EVENT_RC_FILE"
        fi
    else
        if [[ -f ${options[file_rc]:=${XDG_CONFIG_HOME}/event.rc} ]]
        then
            source "${options[file_rc]}"
        else
            __event_status 91 "${options[file_rc]}"
        fi
    fi

    if [[ $EVENT_LOG_FILE ]]
    then
        options[file_log]=$EVENT_LOG_FILE
        unset -v EVENT_LOG_FILE
    else
        options[file_log]=${options[file_log]:-${XDG_DATA_HOME}/event.log}
    fi

    if [[ $EVENT_SPOOL_FILE ]]
    then
        options[file_spool]=$EVENT_SPOOL_FILE
        unset -v EVENT_SPOOL_FILE
    else
        options[file_spool]=${options[file_spool]:-${XDG_DATA_HOME}/event.spool}
    fi

    if [[ $EVENT_QUEUE_FILE ]]
    then
        options[file_queue]=$EVENT_QUEUE_FILE
        unset -v EVENT_QUEUE_FILE
    else
        options[file_queue]=${options[file_queue]:-${TMPDIR:-/tmp}/event.queue}
    fi

    command mkdir -vp \
        "${options[file_log]%/*}" \
        "${options[file_spool]%/*}" \
        "${options[file_queue]%/*}"

    options[delay]=${options[delay]:-60}

    declare \
        opt= \
        opts=:cfhi:klnpv

    declare -i j=$(($# - 1))

    while getopts $opts opt
    do
        case $opt in
            c)  options[coproc]=coproc              ;;
            f)  functions[f]=$((j++))               ;;
            i)
                if [[ $OPTARG == -* ]]
                then
                    __event_status 86 "$opt"
                elif [[ $OPTARG == [${opts//:/}] ]]
                then
                    __event_status 87 "$OPTARG"
                else
                    functions[i]=$OPTARG
                fi                                  ;;
            h)  __event_help ; exit $?              ;;
            k)  functions[k]=$((j++))               ;;
            l)  functions[l]=$((j++))               ;;
            n)  options[nofifo]=nofifo              ;;
            p)  functions[p]=$((j++))               ;;
            v)  __event_version; exit $?            ;;
            :)  __event_status 86 "$OPTARG"         ;;
            \?) __event_status 80 "$OPTARG"
        esac
    done

    [[ ${options[coproc]} == coproc && ${options[nofifo]} == nofifo ]] && __event_status 103

    functions[${functions[f]:--}]=__event_sub_file
    functions[${functions[k]:--}]=__event_kill
    functions[${functions[l]:--}]=__event_loop
    functions[${functions[p]:--}]=__event_sub_period

    source "${options[file_spool]}"

    declare -i err=

    if [[ ${functions[l]} && -z ${functions[f]}${functions[p]} ]]
    then
        __event_status 84
    elif [[ ${functions[k]} ]]
    then
        functions=()
        functions[0]=__event_kill
    elif [[ ${functions[l]} && ${functions[f]} && ${functions[p]} ]]
    then
        __event_check_loops
        err=$?
        if ((err == 100))
        then
            functions=()
            functions[0]=__event_loop_file
            functions[1]=__event_loop_period
        else
            exit 95
        fi
    elif [[ ${functions[l]} && ${functions[f]} ]]
    then
        [[ ${options[coproc]} ]] && __event_status 104
        __event_check_loops
        err=$?
        if ((err == 110 || err == 111))
        then
            exit 95
        else
            functions=()
            functions[0]=__event_loop_file
        fi
    elif [[ ${functions[l]} && ${functions[p]} ]]
    then
        [[ ${options[coproc]} ]] && __event_status 104
        __event_check_loops
        err=$?
        if ((err == 101 || err == 111))
        then
            exit 95
        else
            functions=()
            functions[0]=__event_loop_period
        fi
    elif [[ (${functions[f]} && ${functions[p]}) || ${functions[f]} ]]
    then
        options[coproc]=
        options[nofifo]=
        options[noloop]=noloop
        if [[ ${functions[i]} ]]
        then
            functions[${functions[f]}]="__event_sub_file ${functions[i]}"
        else
            __event_status 85
        fi
    elif [[ ${functions[p]} ]]
    then
        options[coproc]=
        options[nofifo]=
        options[noloop]=noloop
    fi

    unset -v \
        functions[--] \
        functions[f] \
        functions[i] \
        functions[k] \
        functions[l] \
        functions[p]

    exec >>"${options[file_log]}" 2>&1

    for ((opt=0 ; opt < $j ; opt++))
    do
        [[ ${functions[$opt]} ]] && ${functions[$opt]}
    done

    wait
}

__event_postpare ()
{
    if ((${#spool[@]} == 0))
    then
        command sed -i '/^status\[/d' "${status[file_spool]}"
    else
        printf '%s\n' "${spool[@]}" > "${options[file_spool]}"
    fi

    status[file_rc]=${status[file_rc]:-${options[file_rc]}}
    status[file_spool]=${status[file_spool]:-${options[file_spool]}}

    declare e=
    for e in "${!status[@]}"
    do
        printf 'status[%s]=%s\n' "$e" "${status[$e]}"
    done >> "${status[file_spool]}"
}

__event_prepare ()
{
    status[file_spool]=${options[file_spool]}
    if [[ ${status[file_queue]} || ${options[noloop]} ]]
    then
        :
    elif [[ ${options[nofifo]} == nofifo ]]
    then
        __event_create_file_log
    elif [[ ${options[coproc]} == coproc ]]
    then
        [[ ${status[pid_loop_period_coproc]} || ${status[pid_loop_file_coproc]} ]] || {
            __event_create_file_log
            __event_loop_coproc
        }
    else
        __event_create_file_log
        __event_loop_fifo
        command sleep 1
        source <(command grep "^status\[pid_loop_fifo\]=" "${options[file_spool]}")
    fi
}

__event_status ()
case $1 in
    79) printf '%s\n' "${time_curr} ${0}:Error:${1}: No command specified" 1>&2 ; exit "$1"                                          ;;
    80) printf '%s\n' "${time_curr} ${0}:Error:${1}: Unknown flag: '-${2}'" 1>&2 ; exit "$1"                                         ;;
    81) printf '%s\n' "${time_curr} ${0}:Error:${1}: Config file missing" 1>&2 ; exit "$1"                                           ;;
    82) printf '%s\n' "${time_curr} ${0}:Error:${1}: Anacronistic commands missing" 1>&2 ; exit "$1"                                 ;;
    83) printf '%s\n' "${time_curr} ${0}:Error:${1}: Inotify filenames missing" 1>&2 ; exit "$1"                                     ;;
    84) printf '%s\n' "${time_curr} ${0}:Error:${1}: No loop specified" 1>&2 ; exit "$1"                                             ;;
    85) printf '%s\n' "${time_curr} ${0}:Error:${1}: No event information specified" 1>&2 ; exit "$1"                                ;;
    86) printf '%s\n' "${time_curr} ${0}:Error:${1}: Option '-${2}' requires an argument" 1>&2 ; exit "$1"                           ;;
    87) printf '%s\n' "${time_curr} ${0}:Error:${1}: Wrong argument: '${2}'" 1>&2 ; exit "$1"                                        ;;
    88) printf '%s\n' "${time_curr} ${0}:Info:${1}: Removing queue: '${2}'" 1>&2                                                     ;;
    89) printf '%s\n' "${time_curr} ${0}:Info:${1}: Removing status information in spool: '${2}'" 1>&2                               ;;
    90) printf '%s\n' "${time_curr} ${0}:Info:${1}: Killing pid: '${2}'" 1>&2                                                        ;;
    91) printf '%s\n' "${time_curr} ${0}:Error:${1}: Conf File does not exist or is not a regular file: '${2}'" 1>&2 ; exit "$1"     ;;
    92) printf '%s\n' "${time_curr} ${0}:Info:${1}: Creating fifo: '${2}'" 1>&2                                                      ;;
    93) printf '%s\n' "${time_curr} ${0}:Info:${1}: Emptying log file: '${2}'" 1>&2                                                  ;;
    94) printf '%s\n' "${time_curr} ${0}:Info:${1}: Processing command '${2}': '${3}'" 1>&2                                          ;;
    95) printf '%s\n' "${time_curr} ${0}:Info:${1}: Loop '${2}' has already been started with pid: '${3}'" 1>&2 ; return 95          ;;
    96) printf '%s\n' "${time_curr} ${0}:Info:${1}: Starting loop '${2}' with pid: '${3}'" 1>&2                                      ;;
    97) printf '%s\n' "${time_curr} ${0}:Error:${1}: Job is unknown: '${2}'" 1>&2                                                    ;;
    98) printf '%s\n' "${time_curr} ${0}:Error:${1}: Options '-f' cannot be combined with '-p' in one commandline" 1>&2 ; exit "$1"  ;;
    99) printf '%s\n' "${time_curr} ${0}:Info:${1}: Restarting loop 'file' with pid: '${2}'" 1>&2 ; exit "$1"                        ;;
    100) printf '%s\n' "${time_curr} ${0}:Info:${1}: Restarting loops 'file' and 'period' with pids: '${2}','${3}'" 1>&2 ; exit "$1" ;;
    101) printf '%s\n' "${time_curr} ${0}:Info:${1}: Stopping loop 'fifo' with pid: '${2}'" 1>&2 ; exit "$1"                         ;;
    102) printf '%s\n' "${time_curr} ${0}:Error:${1}: Event symbols missing" 1>&2 ; exit "$1"                                        ;;
    103) printf '%s\n' "${time_curr} ${0}:Error:${1}: Options '-c' cannot be combined with '-n' in one commandline" 1>&2 ; exit "$1" ;;
    104) printf '%s\n' "${time_curr} ${0}:Error:${1}: Option '-c' must be combined with '-lfp' in one commandline" 1>&2 ; exit "$1"  ;;
esac

__event_sub_file ()
{
    declare \
        path= \
        event_number= \
        file= \
        s= \
        symbol= \

    declare -a \
        commands=() \
        events_names=() \
        symbols=() \
        files=()

    IFS='|' read -r path symbol file <<< "$@"

    [[ $symbol == DELETE_SELF ]] && {
        if [[ ${status[pid_loop_file_coproc]} || ${status[pid_loop_period_coproc]} ]]
        then
            __event_status 100 "${status[pid_loop_file_coproc]}" "${status[pid_loop_period_coproc]}"
        else
            __event_kill
            if [[ ${status[pid_loop_period]} ]]
            then
                __event_status 100 "${status[pid_loop_file]}" "${status[pid_loop_period]}"
            else
                __event_status 99 "${status[pid_loop_file]}"
            fi
        fi
    }

    shopt -s extglob

    events_names=(${!events[@]})
    files=(${events_names[@]//+([0-9])_@(command|exclude|name|period|symbol|time_last)/})
    symbols=(${events_names[@]//+([0-9])_@(command|exclude|file|name|period|time_last)/})
    commands=(${events_names[@]//+([0-9])_@(exclude|file|name|period|symbol|time_last)/})

    shopt -u extglob

    if ((${#files[@]} == 0))
    then
        __event_status 83
    elif ((${#commands[@]} == 0))
    then
        __event_status 82
    elif ((${#symbols[@]} == 0))
    then
        __event_status 102
    else
        status[time_run_last_file]=$time_curr
        while IFS='_' read -r event_number _
        do
            [[ ${events[${event_number}_file]} =~ $path ]] && {
                for s in ${events[${event_number}_symbol]//:/ }
                do
                    [[ $symbol =~ $s ]] && {
                        __event_status 94 "${event_number}" "${events[${event_number}_command]}"
                        (eval "${events[${event_number}_command]}") &
                        break
                    }
                done
                s=
            }
        done < <(printf '%s\n' "${files[@]}")
        wait
        __event_postpare
    fi
}

__event_sub_period ()
{
    declare -a \
        commands=() \
        spool=()

    declare -i \
        event_number= \
        time_diff=

    shopt -s extglob

    commands=(${!events[@]})
    commands=(${commands[@]//+([0-9])_@(exclude|file|name|period|symbol|time_last)/})

    ((${#commands[@]} == 0)) && __event_status 82

    shopt -u extglob

    while IFS='_' read -r event_number _
    do
        time_diff=$((time_curr - ${events[${event_number}_time_last]:-0}))
        if ((${events[${event_number}_period]}))
        then
            status[time_run_last_period]=$time_curr
            if ((time_diff >= ${events[${event_number}_period]}))
            then
                __event_status 94 "${event_number}" "${events[${event_number}_command]}"
                (eval "${events[${event_number}_command]}") &
                spool+=("events[${event_number}_time_last]=$time_curr")
            else
                spool+=("events[${event_number}_time_last]=${events[${event_number}_time_last]}")
            fi
        else
            continue
        fi
    done < <(printf '%s\n' "${commands[@]}" | sort -n)

    wait
    __event_postpare
}

__event_version ()
{
    declare md5sum=
    read -r md5sum _ < <(command md5sum "$BASH_SOURCE")

    printf '%s (%s)\n'  "v0.1.2.0alpha" "$md5sum"
}

# -- MAIN.

__event_main "$@"
