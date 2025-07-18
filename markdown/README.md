# markdown

> DSL for creating Markdown documents.

- [Source Code](https://github.com/marcbran/gensonnet/tree/main/pkg/markdown/lib): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/markdown/markdown/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet.git/markdown@markdown
```

Then you can import it into your file in order to use it:

```jsonnet
local md = import 'markdown/main.libsonnet';
```

## Description

Creating Markdown documents with this library is a two-step process.
This library itself doesn't output any Markdown strings.
Instead, it outputs a format that is similar to [JsonML](http://www.jsonml.org/), but for Markdown elements.
The unofficial name for this format is "JsonMD".

The second step, creating actual Markdown documents, will require the usage of [gensonnet](https://github.com/marcbran/gensonnet) itself.
The gesonnet project's `manifestMarkdown` native function takes any value that is valid JsonMD and outputs a string in Markdown format.
It does so by relying on another Go library ([goldmark](https://github.com/yuin/goldmark)), converting the JsonMD value to a goldmark AST before rendering out the final string.

So strictly speaking this here Jsonnet library is nothing but syntactic sugar on top of what is provided by gensonnet.
