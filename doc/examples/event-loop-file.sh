#!/usr/bin/env sh

printf 'status[%s]=%s\n' "pid_loop_file" "$$" >> "$1"

exec >>"${X_XDG_LOG_HOME}/event.log" 2>&1
printf '%s\n' "${0}:Info:111: Starting inotifywait file loop with pid '${$}'"

eval "$(inotifywait -qm -o "$2" --format 'FILE %w|%:e|%f' --exclude "event.log" --fromfile -)"

