# markdown

> DSL for creating Markdown documents.

- [Source Code](https://github.com/marcbran/gensonnet/tree/main/pkg/markdown/lib): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/markdown/markdown/main.libsonnet): Inlined code published for usage in other projects

### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Document([
    md.Heading1('Title'),
    md.Paragraph(['Hello World!']),
  ])
)
```

### yields

```
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

##### JSON format

###### Calling

```jsonnet
md.Blockquote([
    [
        "Paragraph",
        {
            "blankPreviousLines": true
        },
        "Intelligent quote here"
    ]
])
```

###### yields

```json
[
    "Blockquote",
    {
        "blankPreviousLines": true
    },
    [
        "Paragraph",
        {
            "blankPreviousLines": true
        },
        "Intelligent quote here"
    ]
]
```

##### Markdown format with gensonnet

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Blockquote([md.Paragraph(['Intelligent quote here'])])
)
```

###### yields

```
> Intelligent quote here
```

### CodeBlock

https://spec.commonmark.org/0.31.2/#indented-code-blocks

```jsonnet
md.CodeBlock()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.CodeBlock("func main() {\n  fmt.Println(\"Hello World!\")\n}\n")
```

###### yields

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

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.CodeBlock('func main() {\n  fmt.Println("Hello World!")\n}\n')
)
```

###### yields

```
    func main() {
      fmt.Println("Hello World!")
    }
```

### Em

&lt;em&gt; emphasis

```jsonnet
md.Em()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.Em("Emphasised text")
```

###### yields

```json
[
    "Emphasis",
    {
        "level": 1
    },
    "Emphasised text"
]
```

##### Markdown format with gensonnet

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Paragraph([
    md.Em('Emphasised text'),
  ])
)
```

###### yields

```
*Emphasised text*
```

### Emphasis

https://spec.commonmark.org/0.31.2/#emphasis-and-strong-emphasis

```jsonnet
md.Emphasis()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.Emphasis(1, "Emphasised text")
```

###### yields

```json
[
    "Emphasis",
    {
        "level": 1
    },
    "Emphasised text"
]
```

##### Markdown format with gensonnet

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Paragraph([
    md.Emphasis(1, 'Emphasised text'),
  ])
)
```

###### yields

```
*Emphasised text*
```

### FencedCodeBlock

https://spec.commonmark.org/0.31.2/#fenced-code-blocks

```jsonnet
md.FencedCodeBlock()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.FencedCodeBlock("func main() {\n  fmt.Println(\"Hello World!\")\n}\n", "go")
```

###### yields

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

### HTMLBlock

https://spec.commonmark.org/0.31.2/#html-blocks

```jsonnet
md.HTMLBlock()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.HTMLBlock("<marquee>Welcome to my website</marquee>\n")
```

###### yields

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

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.HTMLBlock('<marquee>Welcome to my website</marquee>\n')
)
```

###### yields

```
<marquee>Welcome to my website</marquee>
```

### Heading

https://spec.commonmark.org/0.31.2/#atx-headings

```jsonnet
md.Heading()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.Heading(1, "Title")
```

###### yields

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

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading(1, 'Title')
)
```

###### yields

```
# Title
```

### Heading1

Level 1 heading

```jsonnet
md.Heading1()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.Heading1("Title")
```

###### yields

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

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading1('Title')
)
```

###### yields

```
# Title
```

### Heading2

Level 2 heading

```jsonnet
md.Heading2()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.Heading2("Title")
```

###### yields

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

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading2('Title')
)
```

###### yields

```
## Title
```

### Heading3

Level 3 heading

```jsonnet
md.Heading3()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.Heading3("Title")
```

###### yields

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

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading3('Title')
)
```

###### yields

```
### Title
```

### Heading4

Level 4 heading

```jsonnet
md.Heading4()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.Heading4("Title")
```

###### yields

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

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading4('Title')
)
```

###### yields

```
#### Title
```

### Heading5

Level 5 heading

```jsonnet
md.Heading5()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.Heading5("Title")
```

###### yields

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

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading5('Title')
)
```

###### yields

```
##### Title
```

### Heading6

Level 6 heading

```jsonnet
md.Heading6()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.Heading6("Title")
```

###### yields

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

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Heading6('Title')
)
```

###### yields

```
###### Title
```

### Image

https://spec.commonmark.org/0.31.2/#images

```jsonnet
md.Image()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.Image("illustrative diagram", "./diag.png")
```

###### yields

```json
[
    "Image",
    {
        "destination": "./diag.png"
    },
    "illustrative diagram"
]
```

##### Markdown format with gensonnet

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Paragraph([
    md.Image('illustrative diagram', './diag.png'),
  ])
)
```

###### yields

```
![illustrative diagram](./diag.png)
```

### Link

https://spec.commonmark.org/0.31.2/#links

```jsonnet
md.Link()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.Link("jsonnet", "https://github.com/marcbran/jsonnet")
```

###### yields

```json
[
    "Link",
    {
        "destination": "https://github.com/marcbran/jsonnet"
    },
    "jsonnet"
]
```

##### Markdown format with gensonnet

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Paragraph([
    md.Link('jsonnet', 'https://github.com/marcbran/jsonnet'),
  ])
)
```

###### yields

```
[jsonnet](https://github.com/marcbran/jsonnet)
```

### List

https://spec.commonmark.org/0.31.2/#lists

```jsonnet
md.List()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.List("-", 0, [
    [
        "ListItem",
        {
            "blankPreviousLines": true
        },
        "Do this"
    ],
    [
        "ListItem",
        {
            "blankPreviousLines": true
        },
        "Do that"
    ],
    [
        "ListItem",
        {
            "blankPreviousLines": true
        },
        "Do this again"
    ]
])
```

###### yields

```json
[
    "List",
    {
        "blankPreviousLines": true,
        "marker": "-",
        "start": 0
    },
    [
        "ListItem",
        {
            "blankPreviousLines": true
        },
        "Do this"
    ],
    [
        "ListItem",
        {
            "blankPreviousLines": true
        },
        "Do that"
    ],
    [
        "ListItem",
        {
            "blankPreviousLines": true
        },
        "Do this again"
    ]
]
```

### ListItem

https://spec.commonmark.org/0.31.2/#list-items

```jsonnet
md.ListItem()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.ListItem([
    [
        "Paragraph",
        {
            "blankPreviousLines": true
        },
        "Do dishes"
    ]
])
```

###### yields

```json
[
    "ListItem",
    {
        "blankPreviousLines": true
    },
    [
        "Paragraph",
        {
            "blankPreviousLines": true
        },
        "Do dishes"
    ]
]
```

### Paragraph

https://spec.commonmark.org/0.31.2/#paragraphs

```jsonnet
md.Paragraph()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.Paragraph([
    "Hello World!"
])
```

###### yields

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

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Paragraph(['Hello World!']),
)
```

###### yields

```
Hello World!
```

### Strong

&lt;strong&gt; emphasis

```jsonnet
md.Strong()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.Strong("Bold text")
```

###### yields

```json
[
    "Emphasis",
    {
        "level": 2
    },
    "Bold text"
]
```

##### Markdown format with gensonnet

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.Paragraph([
    md.Strong('Bold text'),
  ])
)
```

###### yields

```
**Bold text**
```

### ThematicBreak

https://spec.commonmark.org/0.31.2/#thematic-breaks

```jsonnet
md.ThematicBreak()
```


#### Examples

##### JSON format

###### Calling

```jsonnet
md.ThematicBreak()
```

###### yields

```json
[
    "ThematicBreak",
    {
        "blankPreviousLines": true
    }
]
```

##### Markdown format with gensonnet

###### Running

```jsonnet
local md = import 'markdown/main.libsonnet';
local g = import 'gensonnet/main.libsonnet';
g.manifestMarkdown(
  md.ThematicBreak()
)
```

###### yields

```
---
```
