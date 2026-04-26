# plugin/http

> Read-only HTTP GET requests against a REST API. Base URL and default headers are configured when the plugin is started or embedded in Go.

- [Source Code](https://github.com/marcbran/jsonnet-plugin-http): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/http/plugin/http/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/plugin/http@plugin/http
```

Then you can import it into your file in order to use it:

```jsonnet
local http = import 'plugin/http/main.libsonnet';
```

## Description

Generated operation functions take `args` with optional `query` and `headers` objects (Http `in: query` / `in: header`); path parameters are separate function arguments on the nested path API.

## Fields

### request

Sends a GET request. `input` is an object with `method` (`GET` only), `path`, optional `headers`, and optional `query` (query string map).

```jsonnet
http.request()
```

On success returns parsed JSON. On failure returns a `Status` object (`kind: "Status"`).
