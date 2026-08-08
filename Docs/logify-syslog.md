# The Logify Syslog adapter

How to send Logify output to the system logger on Linux.

The other files in this folder are reference material about syslog itself (the man pages, the RFCs, the guides). This one is about Logify's adapter for it.

---

## Contents

- [What it does](#what-it-does)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [The three units](#the-three-units)
- [Configuration](#configuration)
  - [AppName: the tag](#appname-the-tag)
  - [Facility](#facility)
  - [Options](#options)
  - [Level](#level)
  - [SplitLines](#splitlines)
  - [MaxLength](#maxlength)
  - [UseLogMask](#uselogmask)
- [How levels map onto syslog](#how-levels-map-onto-syslog)
- [What a record looks like](#what-a-record-looks-like)
- [Exceptions](#exceptions)
- [Raw lines](#raw-lines)
- [Several adapters and the shared session](#several-adapters-and-the-shared-session)
- [Lifecycle](#lifecycle)
- [Threading](#threading)
- [Reading the records back](#reading-the-records-back)
- [Routing the records with rsyslog](#routing-the-records-with-rsyslog)
- [Building for Linux](#building-for-linux)
- [Troubleshooting](#troubleshooting)
- [Two things the adapter protects you from](#two-things-the-adapter-protects-you-from)
- [What is not implemented](#what-is-not-implemented)
- [API summary](#api-summary)

---

## What it does

The adapter hands every log line to libc `syslog(3)`. From there the record follows whatever the machine is already set up to do with system logs:

- under **systemd**, it reaches `journald` and is readable with `journalctl`
- under **rsyslog** or **syslog-ng**, it lands in `/var/log/syslog`, or in a file of your choosing
- if the host forwards its logs, it goes to the central collector with everything else

That is the reason to prefer it over the Files adapter on a server: log rotation, retention, filtering, remote shipping and access control are already solved by the platform, and your application stops owning any of it.

It is a good fit for daemons, services and containers. For a desktop application, the Files or Debug adapters are usually more convenient.

## Requirements

- **Linux 64 bit.** The adapter and its binding are guarded with `{$IFDEF POSIX}` and compile to empty units everywhere else, so a cross platform project can list them unconditionally: on Windows they simply contain nothing.
- **A Delphi installation with the Linux64 toolchain**, and the platform SDK fetched from the target machine (or from WSL) through PAServer.
- No third party dependency: the binding is part of Logify, since the RTL does not ship one.

The three units are in `Source` and are part of the runtime package.

## Quick start

```delphi
uses
  Logify,
  Logify.Syslog,
  Logify.Adapter.Syslog;

begin
  TLoggerAdapterRegistry.Instance.RegisterFactory(
    TLogifyAdapterSyslogFactory.CreateAdapterFactory('syslog',
      procedure (var AConfig: TSyslogConfig)
      begin
        AConfig.AppName := 'myapp';
        AConfig.Facility := TSyslogFacility.Local6;
        AConfig.Options := [TSyslogOption.PID];
        AConfig.Level := TLogLevel.Info;
      end
    ));

  Logger.LogInfo('service started');
end.
```

```
Aug 08 11:54:02 host myapp[1230]: [default] INFO | service started
```

The factory also accepts a prepared record, if you would rather build the configuration elsewhere:

```delphi
var LConfig := TSyslogConfig.Default;
LConfig.AppName := 'myapp';

TLoggerAdapterRegistry.Instance.RegisterFactory(
  TLogifyAdapterSyslogFactory.CreateAdapterFactory('syslog', LConfig));
```

## The three units

| Unit | Platform | Role |
| --- | --- | --- |
| `Posix.Syslog` | POSIX only | The libc binding: `openlog`, `syslog`, `closelog`, `setlogmask` and the `LOG_*` constants |
| `Logify.Syslog` | **all platforms** | Types, configuration and message shaping. No POSIX dependency |
| `Logify.Adapter.Syslog` | POSIX only | The adapter and its factory |

The middle one carries no platform dependency on purpose. Everything interesting — the facility and severity codes, the level mapping, the payload layout, the line splitting — lives there, which means it is exercised by the test suite on Windows, and a future network transport (RFC 3164 or 5424, over UDP or TCP) could reuse it without touching any of it.

## Configuration

`TSyslogConfig.Default` returns: `User` facility, `[PID]`, level `Info`, `SplitLines` on, `MaxLength` 1024, `UseLogMask` off, and no `AppName`.

### AppName: the tag

The name records are filed under — `journalctl -t` matches on it, and rsyslog writes it in front of the message.

Leave it empty and libc uses the program name (`argv[0]`) instead. That is often what you want, and it means the adapter can skip `openlog()` altogether.

```delphi
AConfig.AppName := 'myapp';
```

### Facility

The facility says *which part of the system* produced the record. Administrators route on it, so it is the knob that decides which file your logs land in.

```delphi
AConfig.Facility := TSyslogFacility.Local6;
```

| Facility | Code | Meaning |
| --- | --- | --- |
| `Kernel` | 0 | kernel messages |
| `User` | 1 | generic user level messages — the default |
| `Mail` | 2 | mail system |
| `Daemon` | 3 | system daemons |
| `Auth` | 4 | security and authorization |
| `Syslog` | 5 | syslogd's own messages |
| `LPR` | 6 | printing |
| `News` | 7 | network news |
| `UUCP` | 8 | UUCP |
| `Cron` | 9 | clock daemon |
| `AuthPriv` | 10 | private security and authorization |
| `FTP` | 11 | ftp daemon |
| `NTP`, `Audit`, `Alert`, `Clock` | 12–15 | reserved for the system |
| `Local0` … `Local7` | 16–23 | **left free for applications** |

Use one of `Local0`…`Local7` unless your program really is a mail system or a print spooler. They exist precisely so that local applications can be routed separately, and nothing else on the machine will be competing for them.

`User` is the default because it is the safe choice when nobody has decided yet.

### Options

Flags passed to `openlog()`.

```delphi
AConfig.Options := [TSyslogOption.PID, TSyslogOption.NoDelay];
```

| Option | Effect |
| --- | --- |
| `PID` | Include the process id in every record. On by default, and worth keeping |
| `Console` | If the message cannot be delivered, write it to the system console |
| `Delay` | Open the connection lazily, at the first record. This is libc's own default |
| `NoDelay` | Open the connection immediately instead |
| `NoWait` | Do not wait for child processes. Deprecated, and ignored on Linux |
| `PrintError` | Also write every record to `stderr` |

`PrintError` is useful while developing: you see the lines in the terminal without going through the journal at all.

### Level

The lowest level that reaches syslog. Everything below is dropped by the adapter, before any libc call.

```delphi
AConfig.Level := TLogLevel.Debug;
```

`TLogLevel.Off` is never emitted, whatever the configuration says.

### SplitLines

A logged exception is several lines long. Syslog has no notion of a multi line record: rsyslog escapes the newlines to `#012` and journald keeps them, so the result is one long unreadable blob.

With `SplitLines` on (the default) the adapter emits **one record per line**, all with the same priority, so the trace reads normally:

```
myapp[1230]: [TfrmMain] ERROR | the operation failed
myapp[1230]: Exception: the outer failure
myapp[1230]: the root cause
myapp[1230]: --- Caused by Exception: the root cause
```

Turn it off if you would rather have exactly one record per log call, at the cost of readability:

```delphi
AConfig.SplitLines := False;
```

Blank lines never produce a record either way.

### MaxLength

The longest record emitted, 1024 characters by default.

Syslog implementations disagree about how long a record may be — RFC 3164 mandates only 1024 bytes, most daemons accept far more — and they truncate silently when it is exceeded. Cutting the line yourself is more predictable than discovering the daemon did it.

- with `SplitLines` on, a longer line is **wrapped** into several records
- with `SplitLines` off, it is **truncated**
- set it to `0` to remove the limit entirely

Note this counts characters, not the bytes syslog will actually see: a payload of non ASCII text is longer once encoded as UTF-8.

### UseLogMask

Off by default. When on, the adapter also calls `setlogmask()` so libc drops anything below `Level` as well.

There is rarely a reason to enable it. The adapter already filters, so all this adds is a second place to look when a line does not turn up. It exists for the case where another part of the process logs through libc directly and you want one mask covering everything.

## How levels map onto syslog

Syslog defines eight severities, Logify has six real levels, so the mapping is not one to one:

| `TLogLevel` | Severity | Code |
| --- | --- | --- |
| `Trace` | `LOG_DEBUG` | 7 |
| `Debug` | `LOG_DEBUG` | 7 |
| `Info` | `LOG_INFO` | 6 |
| `Warning` | `LOG_WARNING` | 4 |
| `Error` | `LOG_ERR` | 3 |
| `Critical` | `LOG_CRIT` | 2 |
| `Off` | never emitted | |

**`Trace` and `Debug` share severity 7.** Nothing distinguishes them on the wire, which is exactly why the level is also written into the message text: `journalctl -p debug` gives you both, and the text tells them apart.

`LOG_NOTICE` (5), `LOG_ALERT` (1) and `LOG_EMERG` (0) are never produced. `EMERG` in particular is broadcast to every logged in user on some systems, which is not something a library should do on your behalf.

The number actually sent is the two combined:

```
priority = facility * 8 + severity
```

so `Local6` (22) with `Error` (3) is `179`. `TSyslogConfig.PriorityFor` does this for you.

## What a record looks like

The payload is deliberately short:

```
[ClassName] LEVEL | message
```

Syslog already records the **timestamp**, the **host**, the **tag** and the **pid**. Repeating any of that would waste the line and make the journal harder to read, so the adapter writes only what syslog cannot know: which class logged, and at which Logify level.

The class name is the one you passed to `TLoggerManager.GetLogger`, shortened to its last dotted segment — `Demo.Form.Main.TfrmMain` becomes `TfrmMain`. When there is no class, it reads `[default]`.

This is the one place where the syslog adapter deliberately differs from the other adapters, which use the full `TLoggerAdapterHelper` layout with an ISO 8601 timestamp and the thread id.

## Exceptions

Passing an exception appends its full description to the payload: class, message, stack trace when a provider is installed, and the whole `InnerException` chain.

```delphi
try
  DoTheWork;
except
  on E: Exception do
    Logger.LogError(E, 'the operation failed');
end;
```

With `SplitLines` on, each line of that becomes its own record, all at the priority of the original call.

The text comes from `GetFullExceptionInfo`, which is public in `Logify.pas`, so an adapter you write yourself can render exceptions identically.

## Raw lines

`LogRawLine` bypasses the payload layout entirely — no class, no level, just the text:

```delphi
Logger.LogRawLine('=== batch 42 starting ===', TLogLevel.Info);
```

```
myapp[1230]: === batch 42 starting ===
```

The level still decides the syslog priority and is still filtered against `Level`; it just does not appear in the text.

## Several adapters and the shared session

`openlog()` and `closelog()` act on **the process**, not on a handle. Two adapters calling `openlog()` with different tags do not get one session each: the second simply overwrites the first, and whichever is destroyed first would close the session for both.

The adapter handles this by reference counting the session: the first adapter that needs it opens it, the last one to go closes it. A second adapter registered later therefore inherits the first one's tag and options.

If you want two syslog destinations with different tags, that is not something syslog itself supports through this API. What you *can* vary per adapter is everything the adapter controls rather than libc: the facility, the level, the splitting and the length limit. Two adapters in different categories, one at `Local6`/`Info` and one at `Local7`/`Error`, work exactly as expected.

When neither `AppName` nor `Options` is set, `openlog()` is skipped altogether — `syslog()` opens the session itself and libc tags the records with the program name.

## Lifecycle

The adapter is built by its factory the first time something logs to its category, and the session is opened then — not when the factory is registered. A program that registers a syslog adapter and never logs never touches libc.

The session is closed when the last adapter is released, which happens when you clear the registry:

```delphi
TLoggerAdapterRegistry.Instance.Clear;
```

or `UnregisterFactory` for that one adapter. If you never do, the process exit closes it, which is equally fine.

## Threading

`syslog(3)` is thread safe in glibc, and the adapter adds no state of its own per call, so nothing is serialised on the way out. Records from several threads interleave as records, never mid line — which is more than can be said for writing to a console.

The registry itself is thread safe, so the adapter is created exactly once no matter how many threads log first.

## Reading the records back

Under systemd:

```bash
journalctl -t myapp                  # everything from this tag
journalctl -t myapp -f               # follow
journalctl -t myapp -n 50            # last 50
journalctl -t myapp -p err           # err and worse
journalctl -t myapp --since "10 min ago"
journalctl SYSLOG_FACILITY=22        # everything on local6
journalctl -t myapp -o json-pretty   # all fields, including PRIORITY
```

`-o json-pretty` (or `-o verbose`) is the way to confirm the facility and priority actually sent, rather than trusting the rendered text:

```json
{
  "SYSLOG_IDENTIFIER": "myapp",
  "SYSLOG_FACILITY": "22",
  "PRIORITY": "3",
  "MESSAGE": "[TfrmMain] ERROR | the operation failed"
}
```

With rsyslog and no systemd:

```bash
grep myapp /var/log/syslog
tail -f /var/log/syslog
```

## Routing the records with rsyslog

The point of choosing a `Local` facility is that the administrator can send your application somewhere of its own. Create `/etc/rsyslog.d/50-myapp.conf`:

```
# everything on local6 goes to its own file
local6.*    /var/log/myapp.log

# and stop it also going to the general syslog
& stop
```

then

```bash
sudo systemctl restart rsyslog
```

Rotation is then configured the usual way, in `/etc/logrotate.d/myapp`:

```
/var/log/myapp.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
}
```

This is the payoff of using syslog instead of writing files directly: none of the above is your application's problem, and it is configured the same way as every other service on the box.

## Building for Linux

The demo in `Demos/Syslog` is a working starting point.

From the IDE: select the **Linux64** target platform, pick a connection profile pointing at your Linux machine or WSL instance, and build.

From the command line:

```
call "<Studio>\bin\rsvars.bat"
msbuild Demos\Syslog\DemoSyslog.dproj /t:Build /p:Config=Debug /p:Platform=Linux64
```

which needs a connection profile and platform SDK already registered — the IDE does that once, through **Tools ▸ Options ▸ Deployment ▸ SDK Manager**.

To check the units compile without linking, which needs no SDK at all:

```
dcclinux64 -B -U"<Studio>\lib\linux64\release;Source" -NS"System;Posix" Source\Logify.Adapter.Syslog.pas
```

## Troubleshooting

**Nothing appears anywhere.** `syslog()` reports no errors: if there is no listener on `/dev/log`, records are dropped silently. Check the socket exists:

```bash
ls -l /dev/log
```

Under systemd it is a symlink into `/run/systemd/journal/`. In a container it is often missing entirely unless the socket is mounted in, which is the usual explanation.

**Nothing appears, but `/dev/log` exists.** Check the adapter's `Level` — and, if you enabled `UseLogMask`, that too. Then confirm the message is being logged at all by registering a Console adapter alongside.

**The tag is wrong, or is the executable name.** You did not set `AppName`, or another syslog adapter opened the session first and its tag won (see [the shared session](#several-adapters-and-the-shared-session)).

**Newlines show up as `#012`.** That is rsyslog escaping a multi line record. Set `SplitLines := True`.

**Records are cut off.** `MaxLength`, or the daemon's own limit. Raise the first, and check `$MaxMessageSize` in the rsyslog configuration for the second.

**Lines are missing under load.** The `/dev/log` datagram socket can drop messages when the daemon falls behind. Log less, or raise the daemon's queue.

**Trace lines look like Debug.** They are: both map to severity 7. The Logify level in the message text is what tells them apart.

## Two things the adapter protects you from

Both are easy to get wrong when calling `syslog(3)` from Delphi, and both fail quietly.

**The ident string is not copied.** `openlog()` stores the pointer it is given. Marshalling a Delphi string into a temporary and passing that means libc reads freed memory for the tag of every later record — the symptom is a garbage tag, or a crash, long after the call that caused it. The adapter keeps the encoded ident alive for as long as the session.

**The message must not be the format string.** `syslog(pri, msg)` treats the message as a `printf` format, so a `%s` in a logged line makes libc read an argument that was never pushed, and a `%n` makes it *write* through one. Any log line containing user input then becomes a format string vulnerability. The adapter calls `syslog(pri, "%s", msg)`, so a percent sign in a message is only ever a percent sign.

## What is not implemented

- **No network transport.** Records go to the local daemon; forwarding them elsewhere is the daemon's job. RFC 3164 and RFC 5424 framing over UDP or TCP are not implemented — though `Logify.Syslog` carries no POSIX dependency precisely so that such a transport could be added on top of the same mapping.
- **No RFC 5424 structured data.** No `MSGID`, no `STRUCTURED-DATA` elements.
- **No native journald fields.** The adapter goes through `syslog(3)`, not `sd_journal_send`, so custom journal fields are not available. What you get is the standard set: tag, pid, facility, priority, message.
- **No per message facility.** The facility is fixed per adapter. Two facilities means two adapters, in two categories.
- **Not Windows.** The `docs/syslog-win32` folder in this repository holds a C implementation of a Windows syslog client, but nothing in Logify uses it today.

## API summary

```delphi
// Logify.Syslog

TSyslogFacility = (Kernel, User, Mail, Daemon, Auth, Syslog, LPR, News,
                   UUCP, Cron, AuthPriv, FTP, NTP, Audit, Alert, Clock,
                   Local0, Local1, Local2, Local3, Local4, Local5, Local6, Local7);

TSyslogSeverity = (Emergency, Alert, Critical, Error, Warning, Notice, Info, Debug);

TSyslogOption   = (PID, Console, Delay, NoDelay, NoWait, PrintError);
TSyslogOptions  = set of TSyslogOption;

TSyslogConfig = record
  class function Default: TSyslogConfig; static;

  function Accepts(ALevel: TLogLevel): Boolean;     // does this level get through?
  function PriorityFor(ALevel: TLogLevel): Integer; // facility or severity
  function FacilityCode: Integer;                   // facility alone, for openlog()
  function LogMask: Integer;                        // LOG_UPTO(Level)
  function NeedsOpenLog: Boolean;                   // is openlog() needed at all?

  property AppName: string;
  property Facility: TSyslogFacility;
  property Options: TSyslogOptions;
  property Level: TLogLevel;
  property SplitLines: Boolean;
  property MaxLength: Integer;
  property UseLogMask: Boolean;
end;

function ShapeMessage(const AClassName, AMessage: string; ALevel: TLogLevel): string;
function SplitMessage(const AMessage: string; AMaxLength: Integer;
  ASplitLines: Boolean): TArray<string>;

// Logify.Adapter.Syslog

TLogifyAdapterSyslogFactory = class(TLoggerAdapterFactory)
  class function CreateAdapterFactory(const AConfig: TSyslogConfig): TLogifyAdapterSyslogFactory; overload;
  class function CreateAdapterFactory(const AName: string; const AConfig: TSyslogConfig): TLogifyAdapterSyslogFactory; overload;
  class function CreateAdapterFactory(const AName: string; AConfProc: TSyslogConfProc): TLogifyAdapterSyslogFactory; overload;
end;
```
