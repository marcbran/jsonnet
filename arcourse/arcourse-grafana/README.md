# arcourse/arcourse-grafana

> Generates an arcourse graph for browsing Grafana datasources and rendering their

- [Source Code](https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-grafana): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-grafana/arcourse/arcourse-grafana/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/arcourse/arcourse-grafana@arcourse/arcourse-grafana
```

Then you can import it into your file in order to use it:

```jsonnet
local arcourse-grafana = import 'arcourse/arcourse-grafana/main.libsonnet';
```

## Description


Queries a datasource's `/api/ds/query` endpoint (via the host's `grafana`
invocation), resolving relative time ranges (via jsonnet-plugin-time), and wires
the results into `chart`/`dashboard` nodes, alongside `list`/`labels`/`values`
nodes for browsing metrics and label values.

## Fields

### chart

Node rendering a single time series query as a line chart, with a time-range nav.

```jsonnet
arcourse-grafana.chart
```


### dashboard

Node rendering a `layout` of queries (see arcourse-echarts) as a dashboard, with a time-range nav.

```jsonnet
arcourse-grafana.dashboard
```


### graph

Root graph function. `datasourceNames` are the Grafana datasource names to

```jsonnet
arcourse-grafana.graph()
```


### labels

Node listing label names present on the metric matched by `expr`, linked via `link`.

```jsonnet
arcourse-grafana.labels
```


### list

Node listing distinct values of `label` for the metric matched by `expr`, linked via `link`.

```jsonnet
arcourse-grafana.list
```


### values

Node rendering distinct values of `label` for the metric matched by `expr` as YAML.

```jsonnet
arcourse-grafana.values
```

