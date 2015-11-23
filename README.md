##### HELP

```
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
        Events[<int>_function]  Whether command list is a bash shell function.
                                true/false
        Events[<int>_name]      Name of the connected subscripts
        Events[<int>_period]    Period in seconds
        Events[<int>_symbol]    Names of the inotify events. Delimiter: colon
                                (:)
        Options[delay]          Delay of the time loop in seconds
        Options[file_log]       Logfile
        Options[file_spool]     Spoolfile
```

