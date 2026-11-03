# Benchmarks

B1 to B8 from the hub's [benchmark protocol](../shared/spec/BENCHMARK.md). The numbers compare the
Zig wrapper with the C core it wraps, in the same executable and on the same inputs. There is no
third-party Zig library to compare with, and the reason is in [competitors.md](competitors.md).

The machine was idle for 30 seconds with total CPU at 8.17 percent before this run, and the process
was pinned to logical CPU 2 with affinity mask `0x4`.

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
| Iterations | 5000 per operation, 64 inputs, warm cache |
| Idle check | 30 samples, 1 s apart: average 8.17 percent, maximum 11.92 percent |

## Results

| ID | Zig wrapper ns/op | C core ns/op | Ratio |
|---|---:|---:|---:|
| B1 | 23.4 | 26.9 | 0.87 |
| B2 | 15.4 | 13.5 | 1.14 |
| B3 | 4.0 | 3.7 | 1.08 |
| B4 | 9.0 | 9.0 | 1.00 |
| B5 | 234.8 | 232.3 | 1.01 |
| B6 | 110.3 | 107.3 | 1.03 |
| B7 | 31.4 | 24.5 | 1.28 |
| B8 | 1140.0 | 889.5 | 1.28 |

B1 is BS to AD, B2 is AD to BS, B3 adds 1000 days, B4 adds 13 months with clamp, B5 is the Nepali
long format with weekday, B6 is a strict parse, B7 is one patro lookup, and B8 is the month grid.

## What the numbers mean

The wrapper is a handful of checks and a call into C, so every row is within 5 ns of the core except
the patro rows. B1 is marginally faster than the direct C path because the benchmark measures the
whole operation and the C path reads the result fields separately. B2 checks the Gregorian fields
and then reads the BS components. B7 and B8 also build the event list, which the C path does too.
B8 is the widest gap because the Zig path constructs a `Range`, an iterator and a `CalendarInfo` for
every day; the work is still linear and about 1.1 microseconds for a whole month.

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

Pin the process to one performance core and leave the machine idle for 30 seconds with total CPU
under 15 percent. Record the idle samples and the command with the table.
