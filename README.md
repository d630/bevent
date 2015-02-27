### event.sh v0.1.2.0alpha [GNU GPLv3]

#### Help

```
event.sh v0.1.2.0alpha (0c7d4dabbcdf434f7235e11e89c0b4df)

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
    EVENT_LOG_FILE          ${XDG_DATA_HOME}/event.log
    EVENT_QUEUE_FILE        ${TMPDIR:-/tmp}/event.queue
    EVENT_RC_FILE           ${XDG_CONFIG_HOME}/event.rc
    EVENT_SPOOL_FILE        ${XDG_DATA_HOME}/event.spool

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
```
