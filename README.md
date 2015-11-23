##### HELP

```
Usage:
        bevent <options> [<arguments>]

Options:
        -f                      Work with file events via inotifywait(1)
        -h                      Show this instruction
        -i <info>               Input for postprocessing the inotifywait(1)
                                output. Used with option -f
        -k                      Kill any coprocess and purge the spool file
        -C                      Indicate to set up an event loop in a coprocess
                                Used with options -[fp]
        -p                      Work with time events having periods configured
        -v                      Print version

Arguments:
        <info>                  See Manpage of inotifywait(1):
                                %w|%:e|%f

Environment variables:
        BEVENT_LOG_FILE         ${XDG_DATA_HOME}/bevent/bevent.log
        BEVENT_RC_FILE          ${XDG_CONFIG_HOME}/bevent/bevent.rc
        BEVENT_SPOOL_FILE       ${XDG_DATA_HOME}/bevent/bevent.spool

Configs:
        Bevents[<int>_command]  Command list. Executed via setsid(1)
        Bevents[<int>_exclude]  BRE used with grep(1) to select non-matching
                                files in a watched folder. Delimiter: semicolon
                                (;)
        Bevents[<int>_file]     Watched filenames. Delimiter: vertical bar (|)
        Bevents[<int>_name]     Name of the connected subscripts
        Bevents[<int>_period]   Period in seconds
        Bevents[<int>_symbol]   Names of the inotify events. Delimiter: colon
                                (:)
        Options[delay]          Delay of the time loop in seconds
        Options[file_log]       Logfile
        Options[file_spool]     Spoolfile
```

