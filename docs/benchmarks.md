# Benchmarks

B1 to B8 from the hub's [benchmark protocol](../shared/spec/BENCHMARK.md). The numbers compare the
Zig wrapper with the C core it wraps, in the same executable and on the same inputs. There is no
third-party Zig library to compare with, and the reason is in [competitors.md](competitors.md).

The run is quiet: the machine was idle and was sampled every second for 30 seconds before the run
(total CPU averaged 4.4 percent and peaked at 7.5 percent, under the protocol's 15 percent target)
and during it (four samples, average 9.2 percent, peak 12.5 percent, which includes the benchmark's
own pinned core and the sampler). Both sides are measured in the same process, alternately, with a
five-pass trimmed mean, so a frequency change cannot favour one side; the ratios are the result to
read. The process was pinned to logical CPU 2 with affinity mask `0x4`. The raw output of the three
runs is in [`raw/2026-11-16/`](raw/2026-11-16/).

The comparison here is with the C core the wrapper calls, because no independent Zig library passes
the bar in [competitors.md](competitors.md).

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
| Date of run | 2026-11-16 |
| Iterations | 5000 per pass, 64 inputs, five passes per side, warm-up before measuring |

## Results

| ID | Zig wrapper ns/op | C core ns/op | Ratio |
|---|---:|---:|---:|
| B1 | 11.2 | 11.1 | 1.01 |
| B2 | 5.1 | 7.9 | 0.65 |
| B3 | 1.4 | 1.4 | 1.00 |
| B4 | 2.9 | 2.9 | 1.00 |
| B5 | 37.5 | 37.9 | 0.99 |
| B6 | 42.7 | 41.7 | 1.02 |
| B7 | 7.6 | 9.6 | 0.79 |
| B8 | 278.8 | 263.9 | 1.06 |

Three runs at 5000 iterations gave B8 at 278.8, 275.5 and 276.4 ns for the wrapper and 263.9, 257.7
and 261.2 ns for the core (ratios 1.06, 1.07 and 1.06). Every row is within 10 percent of the C
core or faster.

The comparison with C# NepDate, the original library, and the target check from `spec/BENCHMARK.md` section 6 are in the hub: [performance page](https://nepdate.com/docs/project/performance/).

B1 is BS to AD, B2 is AD to BS, B3 adds 1000 days, B4 adds 13 months with clamp, B5 is the Nepali
long format with weekday, B6 is a strict parse, B7 is one patro lookup, and B8 is the month grid.

## What the numbers mean

The wrapper is a handful of checks and a call into C. B1 and B3 to B6 are parity, B2 is faster
because `ymd()` returns one integer where the C harness writes a three-field struct, and B7 is
faster because `infoInto` skips the events call when a day has no events while the C harness calls
it unconditionally. B8 is 6 percent slower because it builds a `CalendarInfo` and converts each
event name for every day of the month; that is the intended Zig surface, and the work is still
linear and about 0.34 microseconds for a whole month.

The 28 percent gap that an earlier build showed on B7 and B8 came from the benchmark build, not from those
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
