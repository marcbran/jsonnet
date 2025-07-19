# markdown

> DSL for creating Markdown documents.

- [Source Code](https://github.com/marcbran/gensonnet/tree/main/pkg/markdown/lib): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/markdown/markdown/main.libsonnet): Inlined code published for usage in other projects

**Running**

```jsonnet
local md = import 'markdown/main.libsonnet';
&nbsp;
md.Document([
  md.Heading1('Title'),
  md.Paragraph(['Hello World!']),
])
```

**yields**

```json
# Title
Hello World!
```

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
The gensonnet project's `manifestMarkdown` native function takes any value that is valid JsonMD and outputs a string in Markdown format.
It does so by relying on another Go library ([goldmark](https://github.com/yuin/goldmark)), converting the JsonMD value to a goldmark AST before rendering out the final string.

So strictly speaking this here Jsonnet library is nothing but syntactic sugar on top of what is provided by gensonnet.

## Fields

### Blockquote

https://spec.commonmark.org/0.31.2/#block-quotes

```jsonnet
md.Blockquote()
```


#### Examples

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Blockquote/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading1('Title')
)
```

**yields**

```json
"# Title\n"
```

### CodeBlock

https://spec.commonmark.org/0.31.2/#indented-code-blocks

```jsonnet
md.CodeBlock()
```


#### Examples

##### JSON format

**Calling**

```jsonnet
md.CodeBlock("func main() {\n  fmt.Println(\"Hello World!\")\n}\n")
```

**yields**

```json
[
    "CodeBlock",
    {
        "blankPreviousLines": true
    },
    "func main() {\n  fmt.Println(\"Hello World!\")\n}\n"
]
```

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'CodeBlock/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.CodeBlock('func main() {\n  fmt.Println("Hello World!")\n}\n')
)
```

**yields**

```json
"    func main() {\n      fmt.Println(\"Hello World!\")\n    }\n"
```

### Em

&lt;em&gt; emphasis

```jsonnet
md.Em()
```


#### Examples

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Em/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading1('Title')
)
```

**yields**

```json
"# Title\n"
```

### Emphasis

https://spec.commonmark.org/0.31.2/#emphasis-and-strong-emphasis

```jsonnet
md.Emphasis()
```


#### Examples

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Emphasis/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading1('Title')
)
```

**yields**

```json
"# Title\n"
```

### FencedCodeBlock

https://spec.commonmark.org/0.31.2/#fenced-code-blocks

```jsonnet
md.FencedCodeBlock()
```


#### Examples

##### JSON format

**Calling**

```jsonnet
md.FencedCodeBlock("func main() {\n  fmt.Println(\"Hello World!\")\n}\n", "go")
```

**yields**

```json
[
    "FencedCodeBlock",
    {
        "blankPreviousLines": true,
        "language": "go"
    },
    "func main() {\n  fmt.Println(\"Hello World!\")\n}\n"
]
```

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'FencedCodeBlock/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.FencedCodeBlock('func main() {\n  fmt.Println("Hello World!")\n}\n', 'go')
)
```

**yields**

```json
"```go\nfunc main() {\n  fmt.Println(\"Hello World!\")\n}\n```\n"
```

### HTMLBlock

https://spec.commonmark.org/0.31.2/#html-blocks

```jsonnet
md.HTMLBlock()
```


#### Examples

##### JSON format

**Calling**

```jsonnet
md.HTMLBlock("<marquee>Welcome to my website</marquee>\n")
```

**yields**

```json
[
    "HTMLBlock",
    {
        "blankPreviousLines": true
    },
    "<marquee>Welcome to my website</marquee>\n"
]
```

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'HTMLBlock/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.HTMLBlock('<marquee>Welcome to my website</marquee>\n')
)
```

**yields**

```json
"<marquee>Welcome to my website</marquee>\n"
```

### Heading

https://spec.commonmark.org/0.31.2/#atx-headings

```jsonnet
md.Heading()
```


#### Examples

##### JSON format

**Calling**

```jsonnet
md.Heading(1, "Title")
```

**yields**

```json
[
    "Heading",
    {
        "blankPreviousLines": true,
        "level": 1
    },
    "Title"
]
```

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Heading/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading(1, 'Title')
)
```

**yields**

```json
"# Title\n"
```

### Heading1

Level 1 heading

```jsonnet
md.Heading1()
```


#### Examples

##### JSON format

**Calling**

```jsonnet
md.Heading1("Title")
```

**yields**

```json
[
    "Heading",
    {
        "blankPreviousLines": true,
        "level": 1
    },
    "Title"
]
```

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Heading1/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading1('Title')
)
```

**yields**

```json
"# Title\n"
```

### Heading2

Level 2 heading

```jsonnet
md.Heading2()
```


#### Examples

##### JSON format

**Calling**

```jsonnet
md.Heading2("Title")
```

**yields**

```json
[
    "Heading",
    {
        "blankPreviousLines": true,
        "level": 2
    },
    "Title"
]
```

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Heading2/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading2('Title')
)
```

**yields**

```json
"## Title\n"
```

### Heading3

Level 3 heading

```jsonnet
md.Heading3()
```


#### Examples

##### JSON format

**Calling**

```jsonnet
md.Heading3("Title")
```

**yields**

```json
[
    "Heading",
    {
        "blankPreviousLines": true,
        "level": 3
    },
    "Title"
]
```

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Heading3/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading3('Title')
)
```

**yields**

```json
"### Title\n"
```

### Heading4

Level 4 heading

```jsonnet
md.Heading4()
```


#### Examples

##### JSON format

**Calling**

```jsonnet
md.Heading4("Title")
```

**yields**

```json
[
    "Heading",
    {
        "blankPreviousLines": true,
        "level": 4
    },
    "Title"
]
```

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Heading4/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading4('Title')
)
```

**yields**

```json
"#### Title\n"
```

### Heading5

Level 5 heading

```jsonnet
md.Heading5()
```


#### Examples

##### JSON format

**Calling**

```jsonnet
md.Heading5("Title")
```

**yields**

```json
[
    "Heading",
    {
        "blankPreviousLines": true,
        "level": 5
    },
    "Title"
]
```

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Heading5/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading5('Title')
)
```

**yields**

```json
"##### Title\n"
```

### Heading6

Level 6 heading

```jsonnet
md.Heading6()
```


#### Examples

##### JSON format

**Calling**

```jsonnet
md.Heading6("Title")
```

**yields**

```json
[
    "Heading",
    {
        "blankPreviousLines": true,
        "level": 6
    },
    "Title"
]
```

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Heading6/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading6('Title')
)
```

**yields**

```json
"###### Title\n"
```

### Image

https://spec.commonmark.org/0.31.2/#images

```jsonnet
md.Image()
```


#### Examples

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Image/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading1('Title')
)
```

**yields**

```json
"# Title\n"
```

### Link

https://spec.commonmark.org/0.31.2/#links

```jsonnet
md.Link()
```


#### Examples

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Link/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading1('Title')
)
```

**yields**

```json
"# Title\n"
```

### List

https://spec.commonmark.org/0.31.2/#lists

```jsonnet
md.List()
```


#### Examples

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'List/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading1('Title')
)
```

**yields**

```json
"# Title\n"
```

### ListItem

https://spec.commonmark.org/0.31.2/#list-items

```jsonnet
md.ListItem()
```


#### Examples

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'ListItem/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading1('Title')
)
```

**yields**

```json
"# Title\n"
```

### Paragraph

https://spec.commonmark.org/0.31.2/#paragraphs

```jsonnet
md.Paragraph()
```


#### Examples

##### JSON format

**Calling**

```jsonnet
md.Paragraph([
    "Hello World!"
])
```

**yields**

```json
[
    "Paragraph",
    {
        "blankPreviousLines": true
    },
    "Hello World!"
]
```

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Paragraph/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Paragraph(['Hello World!']),
)
```

**yields**

```json
"Hello World!\n"
```

### Strong

&lt;strong&gt; emphasis

```jsonnet
md.Strong()
```


#### Examples

##### Markdown format with gensonnet

**Running**

```jsonnet
local md = import 'Strong/main.libsonnet';
&nbsp;
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading1('Title')
)
```

**yields**

```json
"# Title\n"
```

### ThematicBreak

https://spec.commonmark.org/0.31.2/#thematic-breaks

```jsonnet
md.ThematicBreak()
```


#### Example

**Calling**

```jsonnet
md.ThematicBreak()
```

**yields**

```json
[
    "ThematicBreak",
    {
        "blankPreviousLines": true
    }
]
```
