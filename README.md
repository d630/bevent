##### HELP

```
Usage:
        events.sh <options> [<arguments>]

Options:
        -f                      Work with file events via inotifywait(1)
        -h                      Show this instruction
        -i <info>               Input for postprocessing the inotifywait(1) file
                                loop with -f
        -k                      Kill any loop and purge the spool file
        -l                      Indicate to set up an event loop. Used with
                                options -[fp]
        -p                      Work with time events having periods configured
        -v                      Print version

Arguments:
        <info>                  See Manpage of inotifywait(1)
                                If feeding to the fifo loop:
                                        FILE %w|%:e|%f
                                or
                                        PERIOD %w|%:e|%f
                                Otherwise only:
                                        %w|%:e|%f

Environment variables:
        EVENT_LOG_FILE          ${XDG_DATA_HOME}/event.log
        EVENT_RC_FILE           ${XDG_CONFIG_HOME}/event.rc
        EVENT_SPOOL_FILE        ${XDG_DATA_HOME}/event.spool

Configs:
        Events[<int>_command]   Command list. Executed via setsid(1)
        Events[<int>_exclude]   BRE used with grep(1) to skip files inside
                                the watched folder. Delimiter: semicolon
        Events[<int>_file]      Watched filenames. Delimiter: colon
        Events[<int>_name]      Name of the connected subscripts
        Events[<int>_period]    Period in seconds
        Events[<int>_symbol]    Names of the inotify events. Delimiter: colon
        Options[delay]          Delay of the time loop in seconds
        Options[file_log]       Logfile
        Options[file_spool]     Spoolfile
```

