# plugin/time

> Relative time resolution: get the current time, and add a signed duration spec to it. `y`(ear) and `M`(onth) use calendar-aware arithmetic, so they land on the right day even though months and years aren't a fixed length - `M` is uppercase since lowercase `m` means minute. `w`(eek) and `d`(ay) are fixed-length (7/1 days). The remainder - `h`, `m`, `s`, `ms`, `us`, `ns` - is also fixed-length duration.

- [Source Code](https://github.com/marcbran/jsonnet-plugin-time): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/time/plugin/time/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/plugin/time@plugin/time
```

Then you can import it into your file in order to use it:

```jsonnet
local time = import 'plugin/time/main.libsonnet';
```

## Description


## Fields

### addDuration

Adds a signed duration spec (e.g. `2h30m`, `1y2M3w4d`, `-6h`) to `epochMs`, returning the resulting epoch milliseconds.

```jsonnet
time.addDuration()
```


### now

Returns the current time as epoch milliseconds.

```jsonnet
time.now()
```


### parseRFC3339

Parses an RFC3339 timestamp (e.g. `2026-08-04T00:00:00Z`) into epoch milliseconds.

```jsonnet
time.parseRFC3339()
```

