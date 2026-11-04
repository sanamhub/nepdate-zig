# Benchmarks

B1 to B8 from the hub's [benchmark protocol](../shared/spec/BENCHMARK.md). The numbers compare the
Zig wrapper with the C core it wraps, in the same executable and on the same inputs. There is no
third-party Zig library to compare with, and the reason is in [competitors.md](competitors.md).

The machine was sampled for 30 seconds before the run: total CPU averaged 22.1 percent and peaked at
29 percent. That is above the protocol's 15 percent idle target because chat and agent processes stay
open on this machine. Both sides are measured in the same process, alternately, with a five-pass
trimmed mean, so a frequency change cannot favour one side; the ratios are the result to read. The
process was pinned to logical CPU 2 with affinity mask `0x4`.

## Machine and toolchain

| Item | Value |
|---|---|
| CPU | 12th Gen Intel Core i5-12500H, 4 performance + 8 efficiency cores, 16 threads |
| RAM | 31.7 GB |
| OS | Windows 11 Home |
| Zig | 0.17.0 |
| C core | `sanamhub/nepdate-c` `v0.2.0-rc.1` |
| Build | `ReleaseFast`, native x86_64 |
| Command | `zig build && start /affinity 4 /wait zig-out\bin\bench.exe 5000` |
| Iterations | 5000 per pass, 64 inputs, five passes per side, warm-up before measuring |

## Results

| ID | Zig wrapper ns/op | C core ns/op | Ratio |
|---|---:|---:|---:|
| B1 | 13.9 | 13.4 | 1.04 |
| B2 | 6.6 | 10.0 | 0.66 |
| B3 | 1.7 | 1.7 | 1.00 |
| B4 | 3.4 | 3.4 | 1.00 |
| B5 | 46.4 | 47.0 | 0.99 |
| B6 | 54.2 | 53.4 | 1.02 |
| B7 | 9.4 | 11.9 | 0.79 |
| B8 | 340.8 | 324.1 | 1.05 |

Three runs at 5000 iterations gave B8 at 348.5, 344.8 and 340.8 ns for the wrapper and 337.3, 329.9
and 324.1 ns for the core (ratios 1.03, 1.05 and 1.05). Every row is within 10 percent of the C
core or faster.

B1 is BS to AD, B2 is AD to BS, B3 adds 1000 days, B4 adds 13 months with clamp, B5 is the Nepali
long format with weekday, B6 is a strict parse, B7 is one patro lookup, and B8 is the month grid.

## What the numbers mean

The wrapper is a handful of checks and a call into C. B1 and B3 to B6 are parity, B2 is faster
because `ymd()` returns one integer where the C harness writes a three-field struct, and B7 is
faster because `infoInto` skips the events call when a day has no events while the C harness calls
it unconditionally. B8 is 5 percent slower because it builds a `CalendarInfo` and converts each
event name for every day of the month; that is the intended Zig surface, and the work is still
linear and about 0.34 microseconds for a whole month.

The earlier measured 28 percent gap on B7 and B8 came from the benchmark build, not from those
paths. Only the root module was `ReleaseFast`; the imported `nepdate` and `nepdate_patro` modules,
and the C sources attached to them, were compiled Debug. The benchmark now creates ReleaseFast
modules for both the wrapper and the C core. `infoInto` is also marked `inline`, because the extra
call per day was measurable even after the build fix; with both changes the gap is gone.

B5 formats into caller buffers on both sides. The allocating `longAlloc` path is the convenient one
and is not in this table; it adds one allocation per call. No allocation counts are reported because
the harness does not have a portable counter on every platform.

## Agreement

There is no competitor agreement column. The C core is the reference implementation, not an
independent library, and it produces the same values the shared vectors assert.

## Rerun

```sh
zig build
start /affinity 4 /wait zig-out\bin\bench.exe 5000
```

Pin the process to one performance core and leave the machine idle for 30 seconds before the run.
Record the idle samples and the command with the table. The harness warms up, then measures each
side five times in alternating order and reports the mean after dropping the fastest and slowest
pass.
