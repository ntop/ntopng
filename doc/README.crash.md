If the ntopng service crashes with a *segmentation fault*, there is a bug in the
software which must be fixed.

Before opening a new issue, please ensure that you are using a recent (ideally the latest)
ntopng version. In order to speed up the troubleshooting process, a stack trace of the
crash is needed.

# Linux

An easy way to get a stack trace on Linux is to run ntopng through the *gdb* debugger:

1. Ask to the ntop team a binary with debug symbols, specifing ntopng version
2. Install gdb (e.g. `sudo apt-get install gdb`)
3. Stop the running service: `sudo systemctl stop ntopng`
4. Start gdb: `gdb --args <downloaded binary path> /etc/ntopng/ntopng.conf`
5. Execute `handle SIG33 nostop noprint pass` and `handle SIGPIPE nostop noprint pass`
6. Execute `run` to start debugging ntopng
7. Wait for the crash to occur
8. Now run `bt` into gdb to get a stack trace of the crash
9. Send the bt output to ntop team

# Windows

The *WinDbg* tool can be used to get a stack trace on Windows:

1. Download and install WinDbg Preview: https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/debugger-download-tools
2. Stop the running service: `C:\Program Files\ntopng\ntopng.exe /r`
3. Open the WinDbg debugger and load the ntopng executable
4. Run the `g` command to start ntopng
5. Wait for the crash to occur
6. Now run `k` to get a stack trace of the crash

See https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/getting-started-with-windbg for more details.
