# arcourse/arcourse-echarts

> Shared views for rendering arcourse graph nodes as ECharts charts and dashboards,

- [Source Code](https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-echarts): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-echarts/arcourse/arcourse-echarts/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/arcourse/arcourse-echarts@arcourse/arcourse-echarts
```

Then you can import it into your file in order to use it:

```jsonnet
local arcourse-echarts = import 'arcourse/arcourse-echarts/main.libsonnet';
```

## Description


`chart` renders a single `option` (an ECharts option object) as a chart panel.
`dashboard` renders a `tree` of `row`/`column`/`panel` layouts as a grid of charts.

## Fields

### chart

Renders `option` (an ECharts option object) as a single chart panel.

```jsonnet
arcourse-echarts.chart
```


### column

Builds a vertical `tree` layout entry with the given `flex` and `children`.

```jsonnet
arcourse-echarts.column()
```


### dashboard

Renders `tree` (built from `row`/`column`/`panel`) as a grid of charts.

```jsonnet
arcourse-echarts.dashboard
```


### default

Alias for `chart`. Fallback view.

```jsonnet
arcourse-echarts.default
```


### panel

Builds a leaf `tree` layout entry embedding a `chart` node with the given `flex`.

```jsonnet
arcourse-echarts.panel()
```


### row

Builds a horizontal `tree` layout entry with the given `flex` and `children`.

```jsonnet
arcourse-echarts.row()
```

