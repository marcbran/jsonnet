# arcourse/arcourse-ui

> Shared views for rendering arcourse graph nodes as HTML, built on top of

- [Source Code](https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-ui): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-ui/arcourse/arcourse-ui/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/arcourse/arcourse-ui@arcourse/arcourse-ui
```

Then you can import it into your file in order to use it:

```jsonnet
local arcourse-ui = import 'arcourse/arcourse-ui/main.libsonnet';
```

## Description


Each entry renders a node's `data` and its neighboring links (`_view.fragment`),
and wraps the result in a full page (`_view.html`).

## Fields

### default

Same as `list`. Fallback view.

```jsonnet
arcourse-ui.default
```


### list

Renders the node's neighboring links as a list, grouping any nested (two-level) links under a titled section.

```jsonnet
arcourse-ui.list
```


### resource

Renders `data` as YAML alongside its neighboring links, if any, grouping any nested (two-level) links under a titled section like `list` does.

```jsonnet
arcourse-ui.resource
```


### table

Renders `data` items (at `table.at`, default `['items']`) as a table with `table.columns`, each row linking to its own item if `linkSpecs` resolves one.

```jsonnet
arcourse-ui.table
```


### yaml

Renders `data` as YAML.

```jsonnet
arcourse-ui.yaml
```

