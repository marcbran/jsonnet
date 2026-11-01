# plugin/telemetry

> Batched telemetry queries: send a mix of query mechanisms (`promql`, `logql`, ...) in one call, distinguished by a `type` field, and let the configured backend batch as many of them as it can into as few round trips as possible.

- [Source Code](https://github.com/marcbran/jsonnet-plugin-telemetry): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/telemetry/plugin/telemetry/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/plugin/telemetry@plugin/telemetry
```

Then you can import it into your file in order to use it:

```jsonnet
local telemetry = import 'plugin/telemetry/main.libsonnet';
```

## Description


## Fields

### query

Runs a batch of query items and returns one result per item, in order. Each item is `{type, datasource, ...params}`, where `type` names the query mechanism (e.g. `promql`, `logql`) and decides how `params` is interpreted and which backend serves it. `datasource` is an opaque identifier meaningful only to that backend.

```jsonnet
telemetry.query()
```

