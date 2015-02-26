#!/usr/bin/env bash

printf 'status[%s]=%s\n' "pid_loop_period" "$$" >> "$1"
exec >>"${X_XDG_LOG_HOME}/event.log" 2>&1

printf '%s\n' "${0}:Info:111: Starting period loop with pid '${$}'"

exec 3<>"$2"

while sleep 60
do
    printf '%s %d\n' "PERIOD" "$(date +%s)" 1>&3
done
