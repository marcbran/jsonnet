# jsonnet

> DSL for creating Jsonnet code.

- [Source Code](https://github.com/marcbran/jsonnet-plugin-jsonnet): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/jsonnet/jsonnet/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet.git/jsonnet@jsonnet
```

Then you can import it into your file in order to use it:

```jsonnet
local j = import 'jsonnet/main.libsonnet';
```

## Description


## Fields

### Apply

Apply

```jsonnet
j.Apply()
```


#### Examples

##### no parameter

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Apply(j.Var('foo')),
)
```

###### yields

```
foo()
```

##### single positional parameter

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Apply(j.Var('foo'), [j.CommaSeparatedExpr(j.Var('a'))]),
)
```

###### yields

```
foo(a)
```

##### single positional parameter without comma separated expr

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Apply(j.Var('foo'), [j.Var('a')]),
)
```

###### yields

```
foo(a)
```

##### single named parameter

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Apply(j.Var('foo'), [], [j.NamedArgument('a', j.Number('1'))]),
)
```

###### yields

```
foo(a=1)
```

### ApplyBrace

ApplyBrace

```jsonnet
j.ApplyBrace()
```


#### Examples

##### apply brace

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.ApplyBrace(j.Var('a'), j.Object()),
)
```

###### yields

```
a {}
```

### Array

Array

```jsonnet
j.Array()
```


#### Examples

##### no elements

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Array(),
)
```

###### yields

```
[]
```

##### single element

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Array([j.CommaSeparatedExpr(j.Number('1'))]),
)
```

###### yields

```
[1]
```

##### single element, without comma separated expr

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Array([j.Number('1')]),
)
```

###### yields

```
[1]
```

### ArrayComp

ArrayComp

```jsonnet
j.ArrayComp()
```


#### Examples

##### single for

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.ArrayComp(
    j.Var('a'),
    [j.ForSpec('a', j.Array([j.CommaSeparatedExpr(j.Number('1')), j.CommaSeparatedExpr(j.Number('2')), j.CommaSeparatedExpr(j.Number('3'))]))]
  ),
)
```

###### yields

```
[a for a in [1, 2, 3]]
```

##### two fors

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.ArrayComp(
    j.Var('a'),
    [
      j.ForSpec('a', j.Array([j.CommaSeparatedExpr(j.Number('1')), j.CommaSeparatedExpr(j.Number('2')), j.CommaSeparatedExpr(j.Number('3'))])),
      j.ForSpec('b', j.Array([j.CommaSeparatedExpr(j.Number('4')), j.CommaSeparatedExpr(j.Number('5')), j.CommaSeparatedExpr(j.Number('6'))])),
    ]
  ),
)
```

###### yields

```
[a for a in [1, 2, 3] for b in [4, 5, 6]]
```

##### one for one if

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.ArrayComp(
    j.Var('a'),
    [
      j.ForSpec('a', j.Array([j.CommaSeparatedExpr(j.Number('1')), j.CommaSeparatedExpr(j.Number('2')), j.CommaSeparatedExpr(j.Number('3'))])),
      j.IfSpec(j.True),
    ]
  ),
)
```

###### yields

```
[a for a in [1, 2, 3] if true]
```

##### one for two ifs

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.ArrayComp(
    j.Var('a'),
    [
      j.ForSpec('a', j.Array([j.CommaSeparatedExpr(j.Number('1')), j.CommaSeparatedExpr(j.Number('2')), j.CommaSeparatedExpr(j.Number('3'))])),
      j.IfSpec(j.True),
      j.IfSpec(j.False),
    ]
  ),
)
```

###### yields

```
[a for a in [1, 2, 3] if true if false]
```

##### one for one if one for

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.ArrayComp(
    j.Var('a'),
    [
      j.ForSpec('a', j.Array([j.CommaSeparatedExpr(j.Number('1')), j.CommaSeparatedExpr(j.Number('2')), j.CommaSeparatedExpr(j.Number('3'))])),
      j.IfSpec(j.True),
      j.ForSpec('b', j.Array([j.CommaSeparatedExpr(j.Number('4')), j.CommaSeparatedExpr(j.Number('5')), j.CommaSeparatedExpr(j.Number('6'))])),
    ]
  ),
)
```

###### yields

```
[a for a in [1, 2, 3] if true for b in [4, 5, 6]]
```

### Assert

Assert

```jsonnet
j.Assert()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Assert(j.True, null, j.Var('a')),
)
```

##### yields

```
assert true; a
```

### Binary

Binary

```jsonnet
j.Binary()
```


#### Examples

##### add

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Mul(j.Number('1'), j.Number('2')),
)
```

###### yields

```
1 * 2
```

### Dollar

Dollar

```jsonnet
j.Dollar
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Dollar,
)
```

##### yields

```
$
```

### Error

Error

```jsonnet
j.Error()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Error(j.String('input required')),
)
```

##### yields

```
error 'input required'
```

### False

False literal

```jsonnet
j.False
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.False,
)
```

##### yields

```
false
```

### Function

Function

```jsonnet
j.Function()
```


#### Examples

##### no parameter

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Function([], j.String('foo')),
)
```

###### yields

```
function() 'foo'
```

##### single parameter

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Function([j.Parameter('a')], j.Var('a')),
)
```

###### yields

```
function(a) a
```

##### parameter with default value

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Function([j.Parameter('a', j.Number('2'))], j.Var('a')),
)
```

###### yields

```
function(a=2) a
```

### If

If

```jsonnet
j.If()
```


#### Examples

##### if-then

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.If(j.True, j.Var('a')),
)
```

###### yields

```
if true then a
```

##### if-then-else

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.If(j.True, j.Var('a'), j.Var('b')),
)
```

###### yields

```
if true then a else b
```

### Import

Import

```jsonnet
j.Import()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Import('main.libsonnet'),
)
```

##### yields

```
import 'main.libsonnet'
```

### ImportBin

ImportBin

```jsonnet
j.ImportBin()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.ImportBin('data.raw'),
)
```

##### yields

```
importbin 'data.raw'
```

### ImportStr

ImportStr

```jsonnet
j.ImportStr()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.ImportStr('main.txt'),
)
```

##### yields

```
importstr 'main.txt'
```

### InSuper

InSuper

```jsonnet
j.InSuper()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.InSuper(j.Var('a')),
)
```

##### yields

```
 a in super
```

### Index

Index

```jsonnet
j.Index()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Index(j.Var('a'), j.String('b')),
)
```

##### yields

```
a.b
```

### Local

Local

```jsonnet
j.Local()
```


#### Examples

##### single bind

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Local([j.LocalBind('a', j.Number('1'))], j.Var('a')),
)
```

###### yields

```
local a = 1; a
```

##### two binds

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Local(
    [
      j.LocalBind('a', j.Number('1')),
      j.LocalBind('b', j.Var('a')),
    ],
    j.Var('b')
  ),
)
```

###### yields

```
local a = 1, b = a; b
```

##### two locals

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Local(
    [
      j.LocalBind('a', j.Number('1')),
    ],
    j.Local(
      [
        j.LocalBind('b', j.Var('a')),
      ],
      j.Var('b')
    ),
  ),
)
```

###### yields

```
local a = 1; local b = a; b
```

##### function bind

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Local(
    [j.LocalFunctionBind('a', [j.Parameter('b')], j.Var('b'))],
    j.Apply(j.Var('a'), [j.CommaSeparatedExpr(j.Number('1'))])
  ),
)
```

###### yields

```
local a(b) = b; a(1)
```

### Member

Member

```jsonnet
j.Member()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Member(j.Var('a'), 'b'),
)
```

##### yields

```
a.b
```

### Null

Null literal

```jsonnet
j.Null
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Null,
)
```

##### yields

```
null
```

### Number

Number

```jsonnet
j.Number()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Number('123.456'),
)
```

##### yields

```
123.456
```

### Object

Object

```jsonnet
j.Object()
```


#### Examples

##### no fields

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Object(),
)
```

###### yields

```
{}
```

##### single field

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Object([j.Field('a', j.Number('1'))]),
)
```

###### yields

```
{ a: 1 }
```

##### single expr field

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Object([j.Field(j.Var('a'), j.Number('1'))]),
)
```

###### yields

```
{ [a]: 1 }
```

##### single field func

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Object([j.FieldFunction('a', [], j.Number('1'))]),
)
```

###### yields

```
{ a(): 1 }
```

### ObjectComp

ObjectComp

```jsonnet
j.ObjectComp()
```


#### Examples

##### single for

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.ObjectComp(
    [j.Field(j.Var('a'), j.Number('1'))],
    [j.ForSpec('a', j.Array([j.CommaSeparatedExpr(j.Number('1')), j.CommaSeparatedExpr(j.Number('2')), j.CommaSeparatedExpr(j.Number('3'))]))]
  ),
)
```

###### yields

```
{ [a]: 1 for a in [1, 2, 3] }
```

##### two fors

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.ObjectComp(
    [j.Field(j.Var('a'), j.Var('b'))],
    [
      j.ForSpec('a', j.Array([j.CommaSeparatedExpr(j.Number('1')), j.CommaSeparatedExpr(j.Number('2')), j.CommaSeparatedExpr(j.Number('3'))])),
      j.ForSpec('b', j.Array([j.CommaSeparatedExpr(j.Number('4')), j.CommaSeparatedExpr(j.Number('5')), j.CommaSeparatedExpr(j.Number('6'))])),
    ]
  ),
)
```

###### yields

```
{ [a]: b for a in [1, 2, 3] for b in [4, 5, 6] }
```

##### one for one if

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.ObjectComp(
    [j.Field(j.Var('a'), j.Var('b'))],
    [
      j.ForSpec('a', j.Array([j.CommaSeparatedExpr(j.Number('1')), j.CommaSeparatedExpr(j.Number('2')), j.CommaSeparatedExpr(j.Number('3'))])),
      j.IfSpec(j.True),
    ]
  ),
)
```

###### yields

```
{ [a]: b for a in [1, 2, 3] if true }
```

##### one for two ifs

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.ObjectComp(
    [j.Field(j.Var('a'), j.Var('b'))],
    [
      j.ForSpec('a', j.Array([j.CommaSeparatedExpr(j.Number('1')), j.CommaSeparatedExpr(j.Number('2')), j.CommaSeparatedExpr(j.Number('3'))])),
      j.IfSpec(j.True),
      j.IfSpec(j.False),
    ]
  ),
)
```

###### yields

```
{ [a]: b for a in [1, 2, 3] if true if false }
```

##### one for one if one for

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.ObjectComp(
    [j.Field(j.Var('a'), j.Var('b'))],
    [
      j.ForSpec('a', j.Array([j.CommaSeparatedExpr(j.Number('1')), j.CommaSeparatedExpr(j.Number('2')), j.CommaSeparatedExpr(j.Number('3'))])),
      j.IfSpec(j.True),
      j.ForSpec('b', j.Array([j.CommaSeparatedExpr(j.Number('4')), j.CommaSeparatedExpr(j.Number('5')), j.CommaSeparatedExpr(j.Number('6'))])),
    ]
  ),
)
```

###### yields

```
{ [a]: b for a in [1, 2, 3] if true for b in [4, 5, 6] }
```

### Parameter

Parameter

```jsonnet
j.Parameter()
```


### Parens

Parens

```jsonnet
j.Parens()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Parens(j.String('foo')),
)
```

##### yields

```
('foo')
```

### Self

Self

```jsonnet
j.Self
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Self,
)
```

##### yields

```
self
```

### Slice

Slice

```jsonnet
j.Slice()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Slice(j.Var('a'), j.Number('1'), j.Number('10'), j.Number('2')),
)
```

##### yields

```
a[1:10:2]
```

### Std

Std

```jsonnet
j.Std
```


#### Examples

##### get

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Std.get(j.Var('a'), j.String('foo')).default(j.Null),
)
```

###### yields

```
std.get(a, 'foo', null)
```

### String

String

```jsonnet
j.String()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.String('foobar'),
)
```

##### yields

```
'foobar'
```

### SuperIndex

SuperIndex

```jsonnet
j.SuperIndex()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.SuperIndex(j.String('a')),
)
```

##### yields

```
super['a']
```

### SuperMember

SuperMember

```jsonnet
j.SuperMember()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.SuperMember('a'),
)
```

##### yields

```
super.a
```

### True

True literal

```jsonnet
j.True
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.True,
)
```

##### yields

```
true
```

### Unary

Unary

```jsonnet
j.Unary()
```


#### Examples

##### negate

###### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Not(j.Var('a')),
)
```

###### yields

```
!a
```

### Var

Var

```jsonnet
j.Var()
```


#### Example

##### Running

```jsonnet
local j = import 'jsonnet/main.libsonnet';
j.manifestJsonnet(
  j.Var('a'),
)
```

##### yields

```
a
```

### manifestJsonnet

manifestJsonnet

```jsonnet
j.manifestJsonnet()
```


### parseJsonnet

parseJsonnet

```jsonnet
j.parseJsonnet()
```

