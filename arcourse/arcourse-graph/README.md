# arcourse/arcourse-graph

> Path-addressable node graph primitives used to compose arcourse resource explorers.

- [Source Code](https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-graph): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-graph/arcourse/arcourse-graph/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/arcourse/arcourse-graph@arcourse/arcourse-graph
```

Then you can import it into your file in order to use it:

```jsonnet
local arcourse-graph = import 'arcourse/arcourse-graph/main.libsonnet';
```

## Description

A graph is built from a flat list of node specs (`[path, ...bodies]`), where `path`
segments prefixed with `$` become required variables on descendant nodes. Nodes at
the same path are layered (merged) together.

## Fields

### graph

Builds a full node tree from `nodeSpecs`, applying `defaultView` to any node that

```jsonnet
arcourse-graph.graph()
```


### node

Builds a single node at `path` from `body` (an object or array of layers).

```jsonnet
arcourse-graph.node()
```

