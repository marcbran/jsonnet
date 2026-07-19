# plugin/html

> Object-based DSL for creating HTML documents.

- [Source Code](https://github.com/marcbran/jsonnet-plugin-html): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/html/plugin/html/main.libsonnet): Inlined code published for usage in other projects

### Running

```jsonnet
local html = import 'plugin/html/main.libsonnet';
html.manifestHtml({
  element: 'div',
  attributes: { class: 'card' },
  children: [
    { element: 'h1', children: ['Title'] },
    { element: 'p', children: ['Hello World!'] },
  ],
})
```

### yields

```
<div class="card"><h1>Title</h1><p>Hello World!</p></div>
```

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/plugin/html@plugin/html
```

Then you can import it into your file in order to use it:

```jsonnet
local html = import 'plugin/html/main.libsonnet';
```

## Description

A node is either an element (`{element: 'div', attributes: {...}, children: [...]}`)
or a reference to other markup (`{html: ...}`), where the `html` value is either
a string (used verbatim, unescaped) or another node (recursed into). This is how
components compose: a component is any object with an `html` key, all its other
keys are ignored by the renderer.

This library itself doesn't output any HTML strings, and it intentionally has no
helper functions for building nodes - object literals are cheaper than jsonnet
function calls. The `manifestHtml` native function takes any value that is valid
according to this shape and outputs a string in HTML format.

## Fields

### manifestHtml

Renders a node tree to an HTML string.

```jsonnet
html.manifestHtml()
```


#### Examples

##### void elements have no closing tag

###### Running

```jsonnet
local html = import 'plugin/html/main.libsonnet';
html.manifestHtml({ element: 'br' })
```

###### yields

```
<br>
```

##### text children are escaped

###### Running

```jsonnet
local html = import 'plugin/html/main.libsonnet';
html.manifestHtml({ element: 'p', children: ['Tom & Jerry'] })
```

###### yields

```
<p>Tom &amp; Jerry</p>
```

##### components are objects with an html key

###### Running

```jsonnet
local html = import 'plugin/html/main.libsonnet';
local Greeting(name) = { html: { element: 'strong', children: ['Hello, ' + name + '!'] } };
html.manifestHtml({ element: 'p', children: [Greeting('World')] })
```

###### yields

```
<p><strong>Hello, World!</strong></p>
```

##### html key with a string value is raw, unescaped markup

###### Running

```jsonnet
local html = import 'plugin/html/main.libsonnet';
html.manifestHtml({ element: 'div', children: [{ html: '<b>raw</b>' }] })
```

###### yields

```
<div><b>raw</b></div>
```

##### null and false children are dropped, arrays are flattened

###### Running

```jsonnet
local html = import 'plugin/html/main.libsonnet';
html.manifestHtml({
  element: 'ul',
  children: [
    [{ element: 'li', children: ['1'] }, { element: 'li', children: ['2'] }],
    if false then { element: 'li', children: ['3'] },
  ],
})
```

###### yields

```
<ul><li>1</li><li>2</li></ul>
```
