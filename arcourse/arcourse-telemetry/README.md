# arcourse/arcourse-telemetry

> Backend-agnostic `chart`/`logs`/`dashboard` nodes rendering telemetry

- [Source Code](https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-telemetry): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-telemetry/arcourse/arcourse-telemetry/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/arcourse/arcourse-telemetry@arcourse/arcourse-telemetry
```

Then you can import it into your file in order to use it:

```jsonnet
local arcourse-telemetry = import 'arcourse/arcourse-telemetry/main.libsonnet';
```

## Description

batched through the host's `telemetry` invocation (see
jsonnet-plugin-telemetry), resolving relative time ranges (via
jsonnet-plugin-time).

Each chart node queries exactly one telemetry type (a chart can't mix
metric and log series in one rendering), but `dashboard.node` is type-
agnostic and can lay out panels of different types side by side.

## Fields

### dashboard

Node rendering a `layout` of panels (see arcourse-echarts) as a

```jsonnet
arcourse-telemetry.dashboard
```

type's chart node - the dashboard only needs each panel's chart to
expose `_telemetryItems` and its own `option`/`links` rendering.

### logs

Backend-generic `logs` node: batches a telemetry item (query language set

```jsonnet
arcourse-telemetry.logs
```

the returned records as a time-sorted log view (severity accent,
click-to-expand fields).

### promql

`chart`/`list`/`labels`/`values` nodes for PromQL-shaped telemetry

```jsonnet
arcourse-telemetry.promql
```

`telemetry` invocation with `type: 'promql'` items instead of talking to
Grafana directly.
