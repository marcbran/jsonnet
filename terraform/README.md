# terraform

> DSL for creating Terraform modules.

- [Source Code](https://github.com/marcbran/terraform/pkg/terraform): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform/terraform/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/terraform@terraform
```

Then you can import it into your file in order to use it:

```jsonnet
local tf = import 'terraform/main.libsonnet';
```

## Description


## Fields

### For

For

```jsonnet
tf.For()
```


#### Examples

##### variable

###### Running

```jsonnet
local tf = import 'terraform/main.libsonnet';
local var = tf.Local('var', ['a', 'b', 'c']);
tf.Cfg(
  tf.Output('example', {
    value: tf.For('s').In(var).List(function(s) tf.upper(s)),
  }),
)
```

###### yields

```json
[
    {
        "locals": {
            "var": [
                "a",
                "b",
                "c"
            ]
        }
    },
    {
        "output": {
            "example": {
                "value": "${[for s in local.var: upper(s)]}"
            }
        }
    }
]
```

##### index

###### Running

```jsonnet
local tf = import 'terraform/main.libsonnet';
tf.Cfg(
  tf.Output('example', {
    value: tf.For('i', 's').In([1, 2, 3]).List(function(i, s) { index: i, value: s }),
  }),
)
```

###### yields

```json
[
    {
        "output": {
            "example": {
                "value": "${[for i, s in [1,2,3]: {\"index\":i,\"value\":s}]}"
            }
        }
    }
]
```

##### map to list

###### Running

```jsonnet
local tf = import 'terraform/main.libsonnet';
tf.Cfg(
  tf.Output('example', {
    value: tf.For('k', 'v').In({ foo: 'a', bar: 'b' }).List(function(k, v) { key: k, value: v }),
  }),
)
```

###### yields

```json
[
    {
        "output": {
            "example": {
                "value": "${[for k, v in {\"bar\":\"b\",\"foo\":\"a\"}: {\"key\":k,\"value\":v}]}"
            }
        }
    }
]
```

##### list to map

###### Running

```jsonnet
local tf = import 'terraform/main.libsonnet';
tf.Cfg(
  tf.Output('example', {
    value: tf.For('s').In(['a', 'b', 'c']).Map(function(s) [s, tf.upper(s)]),
  }),
)
```

###### yields

```json
[
    {
        "output": {
            "example": {
                "value": "${{for s in [\"a\",\"b\",\"c\"]: s => upper(s) }}"
            }
        }
    }
]
```

##### map to map

###### Running

```jsonnet
local tf = import 'terraform/main.libsonnet';
tf.Cfg(
  tf.Output('example', {
    value: tf.For('k', 'v').In({ foo: 'a', bar: 'b' }).Map(function(k, v) [v, k]),
  }),
)
```

###### yields

```json
[
    {
        "output": {
            "example": {
                "value": "${{for k, v in {\"bar\":\"b\",\"foo\":\"a\"}: v => k }}"
            }
        }
    }
]
```

### Format

Format

```jsonnet
tf.Format()
```


#### Example

##### Running

```jsonnet
local tf = import 'terraform/main.libsonnet';
tf.Cfg(
  tf.Output('example', {
    value: tf.Format('Hello %s!', [tf.jsonencode({ foo: 'bar' })]),
  }),
)
```

##### yields

```json
[
    {
        "output": {
            "example": {
                "value": "Hello ${jsonencode({\"foo\":\"bar\"})}!"
            }
        }
    }
]
```

### If

If

```jsonnet
tf.If()
```


#### Example

##### Running

```jsonnet
local tf = import 'terraform/main.libsonnet';
local var = tf.Local('var', false);
tf.Cfg(
  tf.Output('example', {
    value: tf.If(tf.eq(true, var)).Then('a').Else('b'),
  }),
)
```

##### yields

```json
[
    {
        "locals": {
            "var": false
        }
    },
    {
        "output": {
            "example": {
                "value": "${true == local.var ? \"a\" : \"b\"}"
            }
        }
    }
]
```

### Local

Local

```jsonnet
tf.Local()
```


#### Example

##### Running

```jsonnet
local tf = import 'terraform/main.libsonnet';
local example = tf.Local('example', 'hello');
tf.Cfg(
  tf.Local('example2', example),
)
```

##### yields

```json
[
    {
        "locals": {
            "example": "hello"
        }
    },
    {
        "locals": {
            "example2": "${local.example}"
        }
    }
]
```

### Module

Module

```jsonnet
tf.Module()
```


#### Example

##### Running

```jsonnet
local tf = import 'terraform/main.libsonnet';
tf.Cfg(
  tf.Module('example', {
    source: '../tests/example',
  }),
)
```

##### yields

```json
[
    {
        "module": {
            "example": {
                "source": "../tests/example"
            }
        }
    }
]
```

### Output

Output

```jsonnet
tf.Output()
```


#### Example

##### Running

```jsonnet
local tf = import 'terraform/main.libsonnet';
local example = tf.Variable('example', {
  default: 'hello',
});
tf.Cfg(
  tf.Output('example2', {
    value: example,
  }),
)
```

##### yields

```json
[
    {
        "output": {
            "example2": {
                "value": "${var.example}"
            }
        }
    },
    {
        "variable": {
            "example": {
                "default": "hello"
            }
        }
    }
]
```

### Variable

Variable

```jsonnet
tf.Variable()
```


#### Example

##### Running

```jsonnet
local tf = import 'terraform/main.libsonnet';
tf.Cfg(
  tf.Variable('example', {
    default: 'hello',
  })
)
```

##### yields

```json
[
    {
        "variable": {
            "example": {
                "default": "hello"
            }
        }
    }
]
```
