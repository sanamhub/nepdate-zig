# Benchmarks

B1 to B8 from the hub's [benchmark protocol](../shared/spec/BENCHMARK.md). The numbers compare the
Zig wrapper with the C core it wraps, in the same executable and on the same inputs. There is no
third-party Zig library to compare with, and the reason is in [competitors.md](competitors.md).

**Preliminary.** The run below was taken before the 30 second CPU-idle check, so the numbers are
labelled preliminary even where the machine was quiet. The protocol's quiet rerun happens before
1.0.0.

## Machine and toolchain

| Item | Value |
|---|---|
| CPU | 12th Gen Intel Core i5-12500H, 4 performance + 8 efficiency cores, 16 threads |
| RAM | 31.7 GB |
| OS | Windows 11 Home |
| Zig | 0.17.0 |
| C core | `sanamhub/nepdate-c` `v0.2.0-rc.1` |
| Build | `ReleaseFast`, native x86_64 |
| Command | `zig build bench -- 2000` |
| Iterations | 2000 per operation, 64 inputs, warm cache |

## Results

| ID | Zig wrapper ns/op | C core ns/op | Ratio |
|---|---:|---:|---:|
| B1 | 22.2 | 24.8 | 0.90 |
| B2 | 14.0 | 12.2 | 1.15 |
| B3 | 3.8 | 3.5 | 1.09 |
| B4 | 8.4 | 9.3 | 0.90 |
| B5 | 240.1 | 237.5 | 1.01 |
| B6 | 111.1 | 112.8 | 0.99 |
| B7 | 32.2 | 26.1 | 1.23 |
| B8 | 1139.3 | 845.3 | 1.35 |

B1 is BS to AD, B2 is AD to BS, B3 adds 1000 days, B4 adds 13 months with clamp, B5 is the Nepali
long format with weekday, B6 is a strict parse, B7 is one patro lookup, and B8 is the month grid.

## What the numbers mean

The wrapper is a handful of checks and a call into C, so most rows are within a few nanoseconds of
the core. B2 checks the Gregorian fields and then reads the BS components; B7 and B8 also build the
event list, which the C path does too. B8 is the widest gap because the Zig path constructs a
`Range`, an iterator and a `CalendarInfo` for every day; the work is still linear and under 1.2
microseconds for a whole month.

B5 formats into caller buffers on both sides. The allocating `longAlloc` path is the convenient one
and is not in this table; it adds one allocation per call. No allocation counts are reported because
the harness does not have a portable counter on every platform.

## Agreement

There is no competitor agreement column. The C core is the reference implementation, not an
independent library, and it produces the same values the shared vectors assert.

## Rerun

```sh
start /affinity 4 /wait zig build bench -- 2000
```

Pin the process to one performance core and leave the machine idle for 30 seconds with total CPU
under 15 percent. Replace this table and remove the preliminary label in the 1.0.0 release pull
request.
