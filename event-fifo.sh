#!/usr/bin/env bash

printf 'status[%s]=%s\n' "pid_loop_fifo" "$$" >> "$3"
exec >>"$2" 2>&1

printf '%s\n' "${1} ${0}:Info:96: Starting loop 'fifo' with pid: '${$}'"

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
        if (($err == 99))
        then
            exec event.sh -lf
        elif (($err == 100))
        then
            (exec event.sh -lp &)
            command sleep 2
            (exec event.sh -lf &)
            printf '%s\n' "$(date +%s) ${0}:Info:101: Stopping loop 'fifo' with pid: '${$}'"
        fi
    else
        printf '%s\n' "$(date +%s) ${0}:Error:97: Job is unknown: '${job}'"
    fi
    unset -v \
        job \
        info
done < "$4"
