# arcourse/gcp/arcourse-gcp

> Arcourse entry nodes for Google Cloud: the `gcp` node listing the configured projects and the

- [Source Code](https://github.com/marcbran/jsonnet-plugin-gcp/tree/main/pkg/arcourse-gcp): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/gcp/arcourse-gcp/arcourse/gcp/arcourse-gcp/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/arcourse/gcp/arcourse-gcp@arcourse/gcp/arcourse-gcp
```

Then you can import it into your file in order to use it:

```jsonnet
local arcourse-gcp = import 'arcourse/gcp/arcourse-gcp/main.libsonnet';
```

## Description

from the project nodes.

## Fields

### nodeList

The `gcp` and `gcp/$project` nodes for the configured projects.

```jsonnet
arcourse-gcp.nodeList
```


### projects

Projects to browse, as `{ [projectId]: { name } }`; none by default.

```jsonnet
arcourse-gcp.projects
```

