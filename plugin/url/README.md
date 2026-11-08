# plugin/url

> URL building, parsing and escaping backed by Go's `net/url`. Path segments and query parameters are escaped the way Go escapes them: a path segment keeps characters like `:`, `@` and `+`, while query keys and values escape them and encode spaces as `+`. Query parameters are objects whose values are strings, numbers, booleans or arrays of those; arrays become repeated keys and `null` values are omitted.

- [Source Code](https://github.com/marcbran/jsonnet-plugin-url/tree/main/pkg/jsonnet-plugin-url): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/url/plugin/url/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/plugin/url@plugin/url
```

Then you can import it into your file in order to use it:

```jsonnet
local url = import 'plugin/url/main.libsonnet';
```

## Description


## Fields

### encodeQuery

Encodes a params object into a query string sorted by key, like Go's `url.Values.Encode`.

```jsonnet
url.encodeQuery()
```


### format

Formats a URL object with optional `scheme`, `host`, `path` (an array of unescaped segments), `params` and `fragment` into a string.

```jsonnet
url.format()
```


### parse

Parses a URL string into an object with `scheme`, `host`, `path`, `params` and `fragment`, the inverse of `format`.

```jsonnet
url.parse()
```


### parseQuery

Parses a query string into an object whose values are always arrays of strings, like Go's `url.ParseQuery`.

```jsonnet
url.parseQuery()
```


### pathEscape

Escapes `s` so it can be used as a single path segment, like Go's `url.PathEscape`.

```jsonnet
url.pathEscape()
```


### pathUnescape

Reverses `pathEscape`, like Go's `url.PathUnescape`.

```jsonnet
url.pathUnescape()
```


### queryEscape

Escapes `s` so it can be used as a query key or value, like Go's `url.QueryEscape`.

```jsonnet
url.queryEscape()
```


### queryUnescape

Reverses `queryEscape`, like Go's `url.QueryUnescape`.

```jsonnet
url.queryUnescape()
```

