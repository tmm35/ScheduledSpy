# ScheduledSpy

A pspy-style process execution monitor for Windows. Watches for newly
spawned processes and prints them as they happen. This was built for catching
short-lived or periodic executions during Windows privilege escalation
work (scheduled tasks, services, or custom loops that relaunch a binary
on an interval), the kind of thing that's easy to miss if you're just
eyeballing Task Manager or polling `Get-Process` by hand.

pspy: https://github.com/dominicbreuker/pspy

Windows has no `/proc` equivalent, so unlike Linux `pspy` this can't
read a live process table for free. ScheduledSpy works by polling `Win32_Process`
on a short interval and diffing snapshots to catch new PIDs the moment
they appear.

## Usage

```powershell
.\ScheduledSpy.ps1
```

No arguments needed. The poll interval and processes excluded are
set via variables at the top of the script, edit before running if you want.

## Output columns

| Column | Meaning |
|---|---|
| Timestamp | `HH:mm:ss` when the process was first observed |
| User | Owning account, if resolvable (see limitations) |
| ProcessName | The new process's own image name |
| PPID / ParentName | Parent process ID and name — tells you *what* launched it (a service, a scheduled task, a custom script, etc.) |
| PID | Process ID of the new process |
| FullCommandLine | Full command line, if resolvable |

## Limitations

- **Polling driven, not event driven.** A process that starts and exits faster
  than the poll interval can be missed entirely. Lower `$IntervalMs` to
  catch faster processes at the cost of more CPU/noise.
- **`User` and `FullCommandLine` require matching privilege.** Windows
  only returns these for processes you own, or if you're SYSTEM/admin
  with `SeDebugPrivilege`. As a standard user, other users' processes
  (including SYSTEM's) will show `unknown` / `(no access to cmdline)` —
  this is a Windows access-control boundary, not a bug in the script.
  `ProcessName`, `PID`, and `PPID` are visible regardless of privilege
  level, and are usually enough to confirm what fired and when.
- **Name-based process matching is best-effort** when multiple instances
  of the same binary run concurrently.

## Example output

**Local Test** — a SYSTEM-scheduled task caught firing on a personal machine:

<img width="1836" height="328" alt="image" src="https://github.com/user-attachments/assets/29a3a77d-e5fd-4738-b0ee-ce3fe931c1b4" />

**CTF Target** — TFTP.exe caught executing on OffSec Proving Grounds
"Slort," confirming the binary-replacement privesc window is the likely path to privilege escalation (based on other information in the CTF - If you have done it, you know what I mean).

<img width="1140" height="201" alt="image" src="https://github.com/user-attachments/assets/296721af-9eb3-4524-a78c-2b5d37987d7c" />

## Disclaimers

- This script was written with the assistance of Claude. If you are upset over that, oh well.
- **For use in CTFs and authorized penetration testing engagements only.**
  Do not run this against systems you don't have explicit permission to
  test.
