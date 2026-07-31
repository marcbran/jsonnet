# arcourse/arcourse-openapi

> Generates an arcourse graph for browsing any OpenAPI-described service.

- [Source Code](https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-openapi): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-openapi/arcourse/arcourse-openapi/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/arcourse/arcourse-openapi@arcourse/arcourse-openapi
```

Then you can import it into your file in order to use it:

```jsonnet
local arcourse-openapi = import 'arcourse/arcourse-openapi/main.libsonnet';
```

## Description

Resolves an OpenAPI spec (via jsonnet-plugin-openapi) into a nested operation tree
and generates Jsonnet source (via jsonnet-plugin-jsonnet) that wires up nodes for
each resource-shaped operation, optionally cross-linked via `links` and rendered
with custom `columns`.

## Fields

### graph

Root package. `service` names the generated context node, `spec` is the OpenAPI

```jsonnet
arcourse-openapi.graph
```

`contextParams` lists extra parameters threaded through generated requests.
`manifest` (default `true`) controls whether `_view.jsonnet` is rendered as a
string or returned as an AST.
