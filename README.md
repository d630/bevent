##### README

[bevent](https://github.com/D630/bevent) is a bash shell script which a) executes scheduled commands every x seconds and b) executes commands based on events from inotifywait(1).

##### BUGS & REQUESTS

Please feel free to open an issue or put in a pull request on https://github.com/D630/bevent

##### GIT

To download the very latest source code:

```
git clone https://github.com/D630/bevent
```

In order to use the latest tagged version, do also something like this:

```
cd -- ./bevent
git checkout $(git describe --abbrev=0 --tags)
```

##### INSTALL

Just put `bevent` on your PATH.

##### USAGE

```
bevent <options> [<arguments>]
```


###### ENVIRONMENT VARIABLES

```
BEVENT_LOG_FILE         Default:    ${XDG_DATA_HOME}/bevent/bevent.log
BEVENT_RC_FILE          "           ${XDG_CONFIG_HOME}/bevent/bevent.rc
BEVENT_SPOOL_FILE       "           ${XDG_DATA_HOME}/bevent/bevent.spool
```

###### OPTIONS

```
-f                      Work with file events via inotifywait(1)
-h                      Show this instruction
-i <info>               Input for postprocessing the inotifywait(1)
                        output. Used with option -f
-k                      Kill any coprocess and purge the spool file
-C                      Indicate to set up an event loop in a coprocess
                        Used with options -[fp]
-p                      Work with time events having periods configured
-v                      Print version
```

###### ARGUMENTS

```
<info>                  See Manpage of inotifywait(1):
                        %w|%:e|%f
```


##### CONFIGURATIONS

```
Bevents[<int>_command]  Command list. Executed via setsid(1)
Bevents[<int>_exclude]  BRE used with grep(1) to select non-matching
                        files in a watched folder. Delimiter: semicolon
                        (;)
Bevents[<int>_file]     Watched filenames. Delimiter: vertical bar (|)
Events[<int>_function]  Whether command list is a bash shell function.
                        true/false
Bevents[<int>_name]     Name of the connected subscripts
Bevents[<int>_period]   Period in seconds
Bevents[<int>_symbol]   Names of the inotify events. Delimiter: colon
                        (:)
Options[delay]          Delay of the time loop in seconds
Options[file_log]       Logfile
Options[file_spool]     Spoolfile
```

##### NOTICE

bevent has been written in [GNU bash](http://www.gnu.org/software/bash/) on [Debian GNU/Linux 9 (stretch/sid)](https://www.debian.org) using these programs/packages:

- GNU bash 4.3.42(1)-release
- GNU coreutils 8.23: mkdir, sleep
- GNU grep 2.22
- GNU sed 4.2.2
- inotifywait 3.14
- procps-ng 3.3.10: pkill
- util-linux 2.27.1: setsid

##### LICENCE

GNU GPLv3

