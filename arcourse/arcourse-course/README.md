# arcourse/arcourse-course

> Node specs exposing an arcourse instance's own course history as part of the graph

- [Source Code](https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-course): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-course/arcourse/arcourse-course/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/arcourse/arcourse-course@arcourse/arcourse-course
```

Then you can import it into your file in order to use it:

```jsonnet
local arcourse-course = import 'arcourse/arcourse-course/main.libsonnet';
```

## Description


Reads the course log through the built-in arcourse plugin, so the sessions list, a
session's course and a single visit are ordinary traversable nodes rather than a
separate page. Watching a session streams new visits as they are appended.
