#!/usr/bin/env bash

printf 'status[pid_loop_fifo]=%d\n' "$$" >> "$3"
exec >>"$2" 2>&1

printf '%s %s:Info:96: Starting fifo loop with pid: %d\n' "$1" "${BASH_SOURCE[0]}" "$$"

typeset +i \
    job= \
    info=;

typeset -i err=

while
        read -r job info
do
        if
                [[ $job == PERIOD ]]
        then
                event.sh -p
        elif
                [[ $job == FILE ]]
        then
                event.sh -fi "$info"
                err=$?
                if
                        (( $err == 99 ))
                then
                        exec event.sh -lf
                elif
                        (( $err == 100 ))
                then
                        ( exec event.sh -lp & )
                        command sleep 2
                        ( exec event.sh -lf & )
                        printf '%(%s)T %s:Info:101: Stopping loop fifo with pid: %d' -1 "$0" "$$"
                fi
        else
                printf '%(%s)T %s:Error:97: Job is unknown: %s\n' -1 "$0" "$$" "$job"
        fi
        unset -v \
                job \
                info
done < "$4"

# vim: set ts=8 sw=8 tw=0 et :
