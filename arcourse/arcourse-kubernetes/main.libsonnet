local j =
  local wrapArray(val) = if std.type(val) == 'array' then val else [val];

  local NodeBase = {
    fodder(f):: self { fodder::: wrapArray(f) },
  };

  {
    Null: NodeBase {
      __kind__: 'LiteralNull',
    },
    True: NodeBase {
      __kind__: 'LiteralBoolean',
      value: true,
    },
    False: NodeBase {
      __kind__: 'LiteralBoolean',
      value: false,
    },
    Self: NodeBase {
      __kind__: 'Self',
    },
    Dollar: NodeBase {
      __kind__: 'Dollar',
    },
    String(value, format=null):
      if format == null
      then NodeBase {
        __kind__: 'LiteralString',
        value: value,
      }
      else $.Percent({
        __kind__: 'LiteralString',
        value: value,
      }, format),
    Number(value): NodeBase {
      __kind__: 'LiteralNumber',
      originalString: value,
    },
    Var(id): NodeBase {
      __kind__: 'Var',
      id: id,
    },

    Index(target, index): NodeBase {
      __kind__: 'Index',
      target: target,
      index: index,
      leftBracketFodder(f):: self { leftBracketFodder::: wrapArray(f) },
      rightBracketFodder(f):: self { rightBracketFodder::: wrapArray(f) },
    },
    Member(target, id): NodeBase {
      __kind__: 'Index',
      target: target,
      id: id,
      dotLeftFodder(f):: self { leftBracketFodder::: wrapArray(f) },
      dotRightFodder(f):: self { rightBracketFodder::: wrapArray(f) },
    },
    Slice(target, begin, end, step): NodeBase {
      __kind__: 'Slice',
      target: target,
      beginIndex: begin,
      endIndex: end,
      step: step,
      leftBracketFodder(f):: self { leftBracketFodder::: wrapArray(f) },
      endColonFodder(f):: self { endColonFodder::: wrapArray(f) },
      stepColonFodder(f):: self { stepColonFodder::: wrapArray(f) },
      rightBracketFodder(f):: self { rightBracketFodder::: wrapArray(f) },
    },

    SuperIndex(index): NodeBase {
      __kind__: 'SuperIndex',
      index: index,
      leftBracketFodder(f):: self { dotFodder::: wrapArray(f) },
      rightBracketFodder(f):: self { idFodder::: wrapArray(f) },
    },
    SuperMember(id): NodeBase {
      __kind__: 'SuperIndex',
      id: id,
      dotLeftFodder(f):: self { dotFodder::: wrapArray(f) },
      dotRightFodder(f):: self { idFodder::: wrapArray(f) },
    },
    InSuper(index): NodeBase {
      __kind__: 'InSuper',
      index: index,
      inFodder(f):: self { inFodder::: wrapArray(f) },
      superFodder(f):: self { superFodder::: wrapArray(f) },
    },

    Function(parameters, body): NodeBase {
      __kind__: 'Function',
      parameters: parameters,
      body: body,
      parenLeftFodder(f):: self { parenLeftFodder::: wrapArray(f) },
      parenRightFodder(f):: self { parenRightFodder::: wrapArray(f) },
    },
    Parameter(name, defaultArg=null): NodeBase {
      __kind__: 'Parameter',
      name: name,
      defaultArg: defaultArg,
      nameFodder(f):: self { nameFodder::: wrapArray(f) },
      commaFodder(f):: self { commaFodder::: wrapArray(f) },
      eqFodder(f):: self { eqFodder::: wrapArray(f) },
    },

    Apply(target, positional=[], named=[]): NodeBase {
      __kind__: 'Apply',
      target: target,
      arguments: {
        positional: [if pos.__kind__ == 'CommaSeparatedExpr' then pos else $.CommaSeparatedExpr(pos) for pos in positional],
        named: named,
      },
      leftFodder(f):: self { fodderLeft::: wrapArray(f) },
      rightFodder(f):: self { fodderRight::: wrapArray(f) },
      tailStrictFodder(f):: self { tailStrictFodder::: wrapArray(f) },
    },
    CommaSeparatedExpr(expr): {
      __kind__: 'CommaSeparatedExpr',
      expr: expr,
      commaFodder(f):: self { commaFodder::: wrapArray(f) },
    },
    NamedArgument(name, arg): {
      __kind__: 'NamedArgument',
      name: name,
      arg: arg,
      nameFodder(f):: self { nameFodder::: wrapArray(f) },
      eqFodder(f):: self { eqFodder::: wrapArray(f) },
      commaFodder(f):: self { commaFodder::: wrapArray(f) },
    },

    Object(fields=[]): NodeBase {
      __kind__: 'Object',
      fields: fields,
      closeFodder(f):: self { closeFodder::: wrapArray(f) },
    },
    Field(id, expr): {
      __kind__: 'ObjectField',
      id: if std.type(id) == 'string' then id else null,
      expr1: if std.type(id) == 'object' then id else null,
      expr2: expr,
      kind: if std.type(id) == 'string' then 1 else 2,
      Hide: 1,
      opFodder(f):: self { opFodder::: wrapArray(f) },
      commaFodder(f):: self { commaFodder::: wrapArray(f) },
    },
    FieldLocal(id, expr): {
      __kind__: 'ObjectField',
      id: id,
      expr2: expr,
      kind: 4,
      Hide: 2,
      opFodder(f):: self { opFodder::: wrapArray(f) },
      commaFodder(f):: self { commaFodder::: wrapArray(f) },
    },
    FieldAssert(cond, message): {
      __kind__: 'ObjectField',
      expr2: cond,
      expr3: message,
      kind: 0,
      Hide: 2,
      opFodder(f):: self { opFodder::: wrapArray(f) },
      commaFodder(f):: self { commaFodder::: wrapArray(f) },
    },
    FieldFunction(id, parameters, body): {
      __kind__: 'ObjectField',
      id: if std.type(id) == 'string' then id else null,
      expr1: if std.type(id) == 'object' then id else null,
      method: $.Function(parameters, body),
      expr2: body,
      kind: if std.type(id) == 'string' then 1 else 2,
      Hide: 1,
      opFodder(f):: self { opFodder::: wrapArray(f) },
      commaFodder(f):: self { commaFodder::: wrapArray(f) },
    },
    ApplyBrace(left, right): NodeBase {
      __kind__: 'ApplyBrace',
      left: left,
      right: right,
    },

    Array(elements=[]): NodeBase {
      __kind__: 'Array',
      elements: [if elem.__kind__ == 'CommaSeparatedExpr' then elem else $.CommaSeparatedExpr(elem) for elem in elements],
      closeFodder(f):: self { closeFodder::: wrapArray(f) },
    },

    ObjectComp(fields=[], specs=[]): NodeBase {
      __kind__: 'ObjectComp',
      fields: fields,
      spec: std.foldl(
        function(acc, curr)
          if curr.__kind__ == 'ForSpec' then
            curr { outer: acc }
          else if curr.__kind__ == 'IfSpec' then
            acc {
              conditions: std.get(acc, 'conditions', []) + [curr],
            }
          else null,
        specs,
        null
      ),
      trailingCommaFodder(f):: self { trailingCommaFodder::: wrapArray(f) },
      closeFodder(f):: self { closeFodder::: wrapArray(f) },
    },
    ArrayComp(body, specs=[]): NodeBase {
      __kind__: 'ArrayComp',
      body: body,
      spec: std.foldl(
        function(acc, curr)
          if curr.__kind__ == 'ForSpec' then
            curr { outer: acc }
          else if curr.__kind__ == 'IfSpec' then
            acc {
              conditions: std.get(acc, 'conditions', []) + [curr],
            }
          else null,
        specs,
        null
      ),
      trailingCommaFodder(f):: self { trailingCommaFodder::: wrapArray(f) },
      closeFodder(f):: self { closeFodder::: wrapArray(f) },
    },
    ForSpec(varName, expr): {
      __kind__: 'ForSpec',
      varName: varName,
      expr: expr,
      forFodder(f):: self { forFodder::: wrapArray(f) },
      varFodder(f):: self { varFodder::: wrapArray(f) },
      inFodder(f):: self { inFodder::: wrapArray(f) },
    },
    IfSpec(expr): {
      __kind__: 'IfSpec',
      expr: expr,
      ifFodder(f):: self { ifFodder::: wrapArray(f) },
    },

    If(cond, branchTrue, branchFalse=null): NodeBase {
      __kind__: 'Conditional',
      cond: cond,
      branchTrue: branchTrue,
      branchFalse: branchFalse,
      thenFodder(f):: self { thenFodder::: wrapArray(f) },
      elseFodder(f):: self { elseFodder::: wrapArray(f) },
    },

    Local(binds, body): NodeBase {
      __kind__: 'Local',
      binds: if std.type(binds) == 'array' then binds else [binds],
      body: body,
    },
    Locals(localBinds, body): std.foldr(function(curr, acc) $.Local(curr, acc), localBinds, body),
    LocalBind(variable, body): {
      __kind__: 'LocalBind',
      variable: variable,
      body: body,
      varFodder(f):: self { varFodder::: wrapArray(f) },
      eqFodder(f):: self { eqFodder::: wrapArray(f) },
      closeFodder(f):: self { closeFodder::: wrapArray(f) },
    },
    LocalFunctionBind(variable, parameters, body): {
      __kind__: 'LocalBind',
      variable: variable,
      body: body,
      fun: $.Function(parameters, body),
      varFodder(f):: self { varFodder::: wrapArray(f) },
      eqFodder(f):: self { eqFodder::: wrapArray(f) },
      closeFodder(f):: self { closeFodder::: wrapArray(f) },
    },

    Assert(cond, message, rest): NodeBase {
      __kind__: 'Assert',
      cond: cond,
      message: message,
      rest: rest,
      colonFodder(f):: self { colonFodder::: wrapArray(f) },
      semicolonFodder(f):: self { semicolonFodder::: wrapArray(f) },
    },
    Error(expr): NodeBase {
      __kind__: 'Error',
      expr: expr,
    },

    Parens(inner): NodeBase {
      __kind__: 'Parens',
      inner: inner,
      closeFodder(f):: self { closeFodder::: wrapArray(f) },
    },

    Import(file): NodeBase {
      __kind__: 'Import',
      file: if std.type(file) == 'string' then $.String(file) else file,
    },
    ImportStr(file): NodeBase {
      __kind__: 'ImportStr',
      file: if std.type(file) == 'string' then $.String(file) else file,
    },
    ImportBin(file): NodeBase {
      __kind__: 'ImportBin',
      file: if std.type(file) == 'string' then $.String(file) else file,
    },

    Binary(left, op, right): NodeBase {
      __kind__: 'Binary',
      left: left,
      right: right,
      op: op,
      opFodder(f):: self { opFodder::: wrapArray(f) },
    },
    Mul(left, right): self.Binary(left, 0, right),
    Div(left, right): self.Binary(left, 1, right),
    Percent(left, right): self.Binary(left, 2, right),
    Add(left, right): self.Binary(left, 3, right),
    Sub(left, right): self.Binary(left, 4, right),
    LShift(left, right): self.Binary(left, 5, right),
    RShift(left, right): self.Binary(left, 6, right),
    Gt(left, right): self.Binary(left, 7, right),
    Gte(left, right): self.Binary(left, 8, right),
    Lt(left, right): self.Binary(left, 9, right),
    Lte(left, right): self.Binary(left, 10, right),
    In(left, right): self.Binary(left, 11, right),
    Eq(left, right): self.Binary(left, 12, right),
    Neq(left, right): self.Binary(left, 13, right),
    BitAnd(left, right): self.Binary(left, 14, right),
    BitXor(left, right): self.Binary(left, 15, right),
    BitOr(left, right): self.Binary(left, 16, right),
    And(left, right): self.Binary(left, 17, right),
    Or(left, right): self.Binary(left, 18, right),

    Unary(expr, op): NodeBase {
      __kind__: 'Unary',
      expr: expr,
      op: op,
    },
    Not(a): self.Unary(a, 0),
    BitNot(a): self.Unary(a, 1),
    Plus(a): self.Unary(a, 2),
    Minus(a): self.Unary(a, 3),

    Std: {
      // External Variables
      extVar(x): $.Apply($.Member($.Var('std'), 'extVar'), [x]),

      // Types and Reflection
      thisFile: $.Member($.Var('std'), 'thisFile'),
      type(val): $.Apply($.Member($.Var('std'), 'type'), [val]),
      length(x): $.Apply($.Member($.Var('std'), 'length'), [x]),
      prune(a): $.Apply($.Member($.Var('std'), 'prune'), [a]),

      // Mathematical Utilities
      abs(n): $.Apply($.Member($.Var('std'), 'abs'), [n]),
      sign(n): $.Apply($.Member($.Var('std'), 'sign'), [n]),
      max(a, b): $.Apply($.Member($.Var('std'), 'max'), [a, b]),
      min(a, b): $.Apply($.Member($.Var('std'), 'min'), [a, b]),
      pow(x, n): $.Apply($.Member($.Var('std'), 'pow'), [x, n]),
      exp(x): $.Apply($.Member($.Var('std'), 'exp'), [x]),
      log(x): $.Apply($.Member($.Var('std'), 'log'), [x]),
      exponent(x): $.Apply($.Member($.Var('std'), 'exponent'), [x]),
      mantissa(x): $.Apply($.Member($.Var('std'), 'mantissa'), [x]),
      floor(x): $.Apply($.Member($.Var('std'), 'floor'), [x]),
      ceil(x): $.Apply($.Member($.Var('std'), 'ceil'), [x]),
      sqrt(x): $.Apply($.Member($.Var('std'), 'sqrt'), [x]),
      sin(x): $.Apply($.Member($.Var('std'), 'sin'), [x]),
      cos(x): $.Apply($.Member($.Var('std'), 'cos'), [x]),
      tan(x): $.Apply($.Member($.Var('std'), 'tan'), [x]),
      asin(x): $.Apply($.Member($.Var('std'), 'asin'), [x]),
      acos(x): $.Apply($.Member($.Var('std'), 'acos'), [x]),
      atan(x): $.Apply($.Member($.Var('std'), 'atan'), [x]),
      round(x): $.Apply($.Member($.Var('std'), 'round'), [x]),
      isEven(x): $.Apply($.Member($.Var('std'), 'isEven'), [x]),
      isOdd(x): $.Apply($.Member($.Var('std'), 'isOdd'), [x]),
      isInteger(x): $.Apply($.Member($.Var('std'), 'isInteger'), [x]),
      isDecimal(x): $.Apply($.Member($.Var('std'), 'isDecimal'), [x]),
      clamp(x, minVal, maxVal): $.Apply($.Member($.Var('std'), 'clamp'), [x, minVal, maxVal]),

      // Assertions and Debugging
      assertEqual(a, b): $.Apply($.Member($.Var('std'), 'assertEqual'), [a, b]),

      // String Manipulation
      toString(a): $.Apply($.Member($.Var('std'), 'toString'), [a]),
      codepoint(str): $.Apply($.Member($.Var('std'), 'codepoint'), [str]),
      char(n): $.Apply($.Member($.Var('std'), 'char'), [n]),
      substr(str, from, len): $.Apply($.Member($.Var('std'), 'substr'), [str, from, len]),
      findSubstr(pat, str): $.Apply($.Member($.Var('std'), 'findSubstr'), [pat, str]),
      startsWith(a, b): $.Apply($.Member($.Var('std'), 'startsWith'), [a, b]),
      endsWith(a, b): $.Apply($.Member($.Var('std'), 'endsWith'), [a, b]),
      stripChars(str, chars): $.Apply($.Member($.Var('std'), 'stripChars'), [str, chars]),
      lstripChars(str, chars): $.Apply($.Member($.Var('std'), 'lstripChars'), [str, chars]),
      rstripChars(str, chars): $.Apply($.Member($.Var('std'), 'rstripChars'), [str, chars]),
      split(str, c): $.Apply($.Member($.Var('std'), 'split'), [str, c]),
      splitLimit(str, c, maxsplits): $.Apply($.Member($.Var('std'), 'splitLimit'), [str, c, maxsplits]),
      splitLimitR(str, c, maxsplits): $.Apply($.Member($.Var('std'), 'splitLimitR'), [str, c, maxsplits]),
      strReplace(str, from, to): $.Apply($.Member($.Var('std'), 'strReplace'), [str, from, to]),
      isEmpty(str): $.Apply($.Member($.Var('std'), 'isEmpty'), [str]),
      trim(str): $.Apply($.Member($.Var('std'), 'trim'), [str]),
      equalsIgnoreCase(str1, str2): $.Apply($.Member($.Var('std'), 'equalsIgnoreCase'), [str1, str2]),
      asciiUpper(str): $.Apply($.Member($.Var('std'), 'asciiUpper'), [str]),
      asciiLower(str): $.Apply($.Member($.Var('std'), 'asciiLower'), [str]),
      stringChars(str): $.Apply($.Member($.Var('std'), 'stringChars'), [str]),
      format(str, vals): $.Apply($.Member($.Var('std'), 'format'), [str, vals]),
      escapeStringBash(str): $.Apply($.Member($.Var('std'), 'escapeStringBash'), [str]),
      escapeStringDollars(str): $.Apply($.Member($.Var('std'), 'escapeStringDollars'), [str]),
      escapeStringJson(str): $.Apply($.Member($.Var('std'), 'escapeStringJson'), [str]),
      escapeStringPython(str): $.Apply($.Member($.Var('std'), 'escapeStringPython'), [str]),
      escapeStringXml(str): $.Apply($.Member($.Var('std'), 'escapeStringXml'), [str]),

      // Parsing
      parseInt(str): $.Apply($.Member($.Var('std'), 'parseInt'), [str]),
      parseOctal(str): $.Apply($.Member($.Var('std'), 'parseOctal'), [str]),
      parseHex(str): $.Apply($.Member($.Var('std'), 'parseHex'), [str]),
      parseJson(str): $.Apply($.Member($.Var('std'), 'parseJson'), [str]),
      parseYaml(str): $.Apply($.Member($.Var('std'), 'parseYaml'), [str]),
      encodeUTF8(str): $.Apply($.Member($.Var('std'), 'encodeUTF8'), [str]),
      decodeUTF8(arr): $.Apply($.Member($.Var('std'), 'decodeUTF8'), [arr]),

      // Manifestation
      manifestIni(ini): $.Apply($.Member($.Var('std'), 'manifestIni'), [ini]),
      manifestPython(v): $.Apply($.Member($.Var('std'), 'manifestPython'), [v]),
      manifestPythonVars(conf): $.Apply($.Member($.Var('std'), 'manifestPythonVars'), [conf]),
      manifestJsonEx(value, indent, newline, key_val_sep): $.Apply($.Member($.Var('std'), 'manifestJsonEx'), [value, indent, newline, key_val_sep]),
      manifestJsonMinified(value): $.Apply($.Member($.Var('std'), 'manifestJsonMinified'), [value]),
      manifestYamlDoc(value, indent_array_in_object=$.False, quote_keys=$.True): $.Apply($.Member($.Var('std'), 'manifestYamlDoc'), [value, indent_array_in_object, quote_keys]),
      manifestYamlStream(value, indent_array_in_object=$.False, c_document_end=$.False, quote_keys=$.True): $.Apply($.Member($.Var('std'), 'manifestYamlStream'), [value, indent_array_in_object, c_document_end, quote_keys]),
      manifestXmlJsonml(value): $.Apply($.Member($.Var('std'), 'manifestXmlJsonml'), [value]),
      manifestTomlEx(toml, indent): $.Apply($.Member($.Var('std'), 'manifestTomlEx'), [toml, indent]),

      // Arrays
      makeArray(sz, func): $.Apply($.Member($.Var('std'), 'makeArray'), [sz, func]),
      member(arr, x): $.Apply($.Member($.Var('std'), 'member'), [arr, x]),
      count(arr, x): $.Apply($.Member($.Var('std'), 'count'), [arr, x]),
      find(value, arr): $.Apply($.Member($.Var('std'), 'find'), [value, arr]),
      map(func, arr): $.Apply($.Member($.Var('std'), 'map'), [func, arr]),
      mapWithIndex(func, arr): $.Apply($.Member($.Var('std'), 'mapWithIndex'), [func, arr]),
      filterMap(filter_func, map_func, arr): $.Apply($.Member($.Var('std'), 'filterMap'), [filter_func, map_func, arr]),
      flatMap(func, arr): $.Apply($.Member($.Var('std'), 'flatMap'), [func, arr]),
      filter(func, arr): $.Apply($.Member($.Var('std'), 'filter'), [func, arr]),
      foldl(func, arr, init): $.Apply($.Member($.Var('std'), 'foldl'), [func, arr, init]),
      foldr(func, arr, init): $.Apply($.Member($.Var('std'), 'foldr'), [func, arr, init]),
      range(from, to): $.Apply($.Member($.Var('std'), 'range'), [from, to]),
      repeat(what, count): $.Apply($.Member($.Var('std'), 'repeat'), [what, count]),
      slice(indexable, index, end, step): $.Apply($.Member($.Var('std'), 'slice'), [indexable, index, end, step]),
      join(sep, arr): $.Apply($.Member($.Var('std'), 'join'), [sep, arr]),
      lines(arr): $.Apply($.Member($.Var('std'), 'lines'), [arr]),
      flattenArrays(arr): $.Apply($.Member($.Var('std'), 'flattenArrays'), [arr]),
      flattenDeepArray(value): $.Apply($.Member($.Var('std'), 'flattenDeepArray'), [value]),
      reverse(arrs): $.Apply($.Member($.Var('std'), 'reverse'), [arrs]),
      sort(arr, keyF): $.Apply($.Member($.Var('std'), 'sort'), [arr, keyF]),
      uniq(arr, keyF): $.Apply($.Member($.Var('std'), 'uniq'), [arr, keyF]),
      all(arr): $.Apply($.Member($.Var('std'), 'all'), [arr]),
      any(arr): $.Apply($.Member($.Var('std'), 'any'), [arr]),
      sum(arr): $.Apply($.Member($.Var('std'), 'sum'), [arr]),
      minArray(arr, keyF, onEmpty): $.Apply($.Member($.Var('std'), 'minArray'), [arr, keyF, onEmpty]),
      maxArray(arr, keyF, onEmpty): $.Apply($.Member($.Var('std'), 'maxArray'), [arr, keyF, onEmpty]),
      contains(arr, elem): $.Apply($.Member($.Var('std'), 'contains'), [arr, elem]),
      avg(arr): $.Apply($.Member($.Var('std'), 'avg'), [arr]),
      remove(arr, elem): $.Apply($.Member($.Var('std'), 'remove'), [arr, elem]),
      removeAt(arr, idx): $.Apply($.Member($.Var('std'), 'removeAt'), [arr, idx]),

      // Sets
      set(arr, keyF): $.Apply($.Member($.Var('std'), 'set'), [arr, keyF]),
      setInter(a, b, keyF): $.Apply($.Member($.Var('std'), 'setInter'), [a, b, keyF]),
      setUnion(a, b, keyF): $.Apply($.Member($.Var('std'), 'setUnion'), [a, b, keyF]),
      setDiff(a, b, keyF): $.Apply($.Member($.Var('std'), 'setDiff'), [a, b, keyF]),
      setMember(x, arr, keyF): $.Apply($.Member($.Var('std'), 'setMember'), [x, arr, keyF]),

      // Objects
      get(o, f): $.Apply($.Member($.Var('std'), 'get'), [o, f]) + {
        default(default): $.Apply($.Member($.Var('std'), 'get'), [o, f, default]) + {
          inc_hidden(inc_hidden):: $.Apply($.Member($.Var('std'), 'get'), [o, f, default, inc_hidden]),
        },
      },
      objectHas(o, f): $.Apply($.Member($.Var('std'), 'objectHas'), [o, f]),
      objectFields(o): $.Apply($.Member($.Var('std'), 'objectFields'), [o]),
      objectValues(o): $.Apply($.Member($.Var('std'), 'objectValues'), [o]),
      objectKeysValues(o): $.Apply($.Member($.Var('std'), 'objectKeysValues'), [o]),
      objectHasAll(o, f): $.Apply($.Member($.Var('std'), 'objectHasAll'), [o, f]),
      objectFieldsAll(o): $.Apply($.Member($.Var('std'), 'objectFieldsAll'), [o]),
      objectValuesAll(o): $.Apply($.Member($.Var('std'), 'objectValuesAll'), [o]),
      objectKeysValuesAll(o): $.Apply($.Member($.Var('std'), 'objectKeysValuesAll'), [o]),
      objectRemoveKey(obj, key): $.Apply($.Member($.Var('std'), 'objectRemoveKey'), [obj, key]),
      mapWithKey(func, obj): $.Apply($.Member($.Var('std'), 'mapWithKey'), [func, obj]),

      // Encoding
      base64(input): $.Apply($.Member($.Var('std'), 'base64'), [input]),
      base64DecodeBytes(str): $.Apply($.Member($.Var('std'), 'base64DecodeBytes'), [str]),
      base64Decode(str): $.Apply($.Member($.Var('std'), 'base64Decode'), [str]),
      md5(s): $.Apply($.Member($.Var('std'), 'md5'), [s]),
      sha1(s): $.Apply($.Member($.Var('std'), 'sha1'), [s]),
      sha256(s): $.Apply($.Member($.Var('std'), 'sha256'), [s]),
      sha512(s): $.Apply($.Member($.Var('std'), 'sha512'), [s]),
      sha3(s): $.Apply($.Member($.Var('std'), 'sha3'), [s]),

      // Booleans
      xor(x, y): $.Apply($.Member($.Var('std'), 'xor'), [x, y]),
      xnor(x, y): $.Apply($.Member($.Var('std'), 'xnor'), [x, y]),

      // JSON Merge Patch
      mergePatch(target, patch): $.Apply($.Member($.Var('std'), 'mergePatch'), [target, patch]),

      // Debugging
      trace(str, rest): $.Apply($.Member($.Var('std'), 'trace'), [str, rest]),
    },

    Fodder: {
      Blank(blanks=0): {
        blanks: blanks,
        indent: 0,
        comment: [],
        kind: 0,
      },
      LineEnd(blanks=0, indent=0, comment=null): {
        blanks: blanks,
        indent: indent,
        comment: if comment != null then [comment] else [],
        kind: 0,
      },
    },

    formatJsonnet(jsonnet): std.native('invoke:jsonnet')('formatJsonnet', [jsonnet]),
    manifestJsonnet(jsonnet): std.native('invoke:jsonnet')('manifestJsonnet', [jsonnet]),
    parseJsonnet(jsonnet): std.native('invoke:jsonnet')('parseJsonnet', [jsonnet]),
  };
local kubernetes = {
  contexts(): std.native('invoke:kubernetes')('contexts', []),
  get(ctx, path): std.native('invoke:kubernetes')('get', [ctx, path]),
  neat: {
    get(ctx, path): $.get(ctx, path) {
      metadata+: {
        managedFields:: [],
      },
    },
  },
};

local resourceVerbs(resource) = std.get(resource, 'verbs', []);

local mergeResource(left, right) =
  if left.kind != right.kind then
    error 'conflicting kind for %s: %s vs %s' % [left.name, left.kind, right.kind]
  else
    left { namespaced: left.namespaced || right.namespaced, verbs: std.set(resourceVerbs(left) + resourceVerbs(right)) };

local dedupeResources(resources) =
  local byKey = std.foldl(
    function(acc, r)
      acc { [r.name]: if std.objectHas(acc, r.name) then mergeResource(acc[r.name], r) else r },
    resources,
    {}
  );
  [byKey[k] for k in std.sort(std.objectFields(byKey))];

local generate(resources, group) =
  local le(indent=0) = j.Fodder.LineEnd(0, indent);
  local prettyArray(elements, indent=0) =
    j.Array([elem.fodder(le(indent + 2)) for elem in elements]).closeFodder(le(indent));
  local prettyObject(fields, indent=0) =
    j.Object([field { fodder: [le(indent + 2)] } for field in fields]).closeFodder(le(indent));

  local isAsciiLetter(c) = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
  local isAsciiDigit(c) = c >= '0' && c <= '9';
  local isJsonnetIdent(s) =
    if std.length(s) == 0 then false
    else
      local len = std.length(s);
      local identStart(c) = c == '_' || isAsciiLetter(c);
      local identPart(c) = identStart(c) || isAsciiDigit(c);
      local check(i) =
        if i >= len then true
        else if i == 0 then identStart(s[i]) && check(i + 1)
        else identPart(s[i]) && check(i + 1);
      check(0);
  local jsonnetKeywords = [
    'assert',
    'else',
    'error',
    'false',
    'for',
    'function',
    'if',
    'import',
    'importstr',
    'in',
    'local',
    'null',
    'self',
    'super',
    'tailstrict',
    'then',
    'true',
  ];
  local isJsonnetKeyword(s) = std.member(jsonnetKeywords, s);
  local isUnquotedFieldName(s) = isJsonnetIdent(s) && !isJsonnetKeyword(s);
  local access(expr, name) =
    if isUnquotedFieldName(name) then j.Member(expr, name) else j.Index(expr, j.String(name));

  local contains(xs, x) = std.length([y for y in xs if y == x]) > 0;
  local hasVerb(resource, verb) = contains(resourceVerbs(resource), verb);
  local lowerKind(resource) = std.asciiLower(resource.kind);
  local hasDuplicateKind(resource) =
    std.length([r for r in resources if r.kind == resource.kind]) > 1;
  local resourcePrefix = if group == '' then [] else [group];
  local itemVar(resource) =
    local base =
      if hasDuplicateKind(resource) && group != '' then
        '%s%s' % [lowerKind(resource), std.substr(std.md5(group), 0, 8)]
      else
        lowerKind(resource);
    local candidate = if isUnquotedFieldName(base) then base else 'item';
    if isJsonnetKeyword(candidate) then candidate + 'Item' else candidate;
  local route(resource) =
    local candidate = resource.name;
    if candidate == itemVar(resource) then candidate + 'List' else candidate;

  local var(name) = j.Var(name);
  local member(expr, name) = j.Member(expr, name);
  local call(expr, args=[]) = j.Apply(expr, args);

  local contextOrigin = { origin: 'context' };
  local groupSegment = if group == '' then [] else [{ const: group }];
  local nameSegment(resource) = { param: itemVar(resource), path: ['metadata', 'name'] };
  local allNamespacesLinkSpec(resource) = {
    at: ['items'],
    keys: [{ path: ['metadata', 'namespace'] }, { path: ['metadata', 'name'] }],
    value: [{ const: 'kubernetes' }, contextOrigin, { param: 'namespace', path: ['metadata', 'namespace'] }]
           + groupSegment + [nameSegment(resource)],
  };
  local singleNamespaceLinkSpec(resource) = {
    at: ['items'],
    keys: [{ path: ['metadata', 'name'] }],
    value: [{ const: 'kubernetes' }, contextOrigin, { origin: 'namespace' }] + groupSegment + [nameSegment(resource)],
  };
  local clusterLinkSpec(resource) = {
    at: ['items'],
    keys: [{ path: ['metadata', 'name'] }],
    value: [{ const: 'kubernetes' }, contextOrigin] + groupSegment + [nameSegment(resource)],
  };

  local apiPrefix(resource) =
    if group == '' then '/api/' + resource.version
    else '/apis/' + group + '/' + resource.version;

  local k8sGet(pathExpr) =
    call(member(var('kubernetes'), 'get'), [access(j.Dollar, 'context'), pathExpr]);
  local k8sNeatGet(pathExpr) =
    call(member(member(var('kubernetes'), 'neat'), 'get'), [access(j.Dollar, 'context'), pathExpr]);

  local staticPath(path) = j.String(path);
  local formatPath(fmt, args) = j.Std.format(j.String(fmt), j.Array(args));
  local toStr(expr) = j.Std.toString(expr);

  local clusterListPath(resource) = staticPath(apiPrefix(resource) + '/' + resource.name);
  local clusterDetailPath(resource) =
    formatPath(apiPrefix(resource) + '/' + resource.name + '/%s', [toStr(access(j.Dollar, itemVar(resource)))]);
  local namespacedAllPath(resource) = staticPath(apiPrefix(resource) + '/' + resource.name);
  local namespacedListPath(resource) =
    formatPath(apiPrefix(resource) + '/namespaces/%s/' + resource.name, [toStr(access(j.Dollar, 'namespace'))]);
  local namespacedDetailPath(resource) =
    formatPath(apiPrefix(resource) + '/namespaces/%s/' + resource.name + '/%s', [
      toStr(access(j.Dollar, 'namespace')),
      toStr(access(j.Dollar, itemVar(resource))),
    ]);

  local objectField(name, expr) =
    if isUnquotedFieldName(name) then j.Field(name, expr) else j.Field(j.String(name), expr);

  local compactLiteral(value) =
    if value == null then j.Null
    else if std.type(value) == 'string' then j.String(value)
    else if std.type(value) == 'boolean' then if value then j.True else j.False
    else if std.type(value) == 'number' then j.Number(std.toString(value))
    else if std.type(value) == 'array' then j.Array([compactLiteral(item) for item in value])
    else if std.type(value) == 'object' then j.Object([
      objectField(field, compactLiteral(value[field]))
      for field in std.objectFields(value)
    ])
    else error 'unsupported literal type: ' + std.type(value);

  local dataField(expr, hidden=false) =
    j.Field('data', expr) { Hide: if hidden then 0 else 1 };
  local dataObject(expr) = prettyObject([dataField(expr)], 2);
  local linkSpecEntry(spec) =
    prettyObject([objectField(field, compactLiteral(spec[field])) for field in ['at', 'keys', 'value']], 6);
  local listObject(dataExpr, linkSpecs, columnsExpr=null) = prettyObject(
    [dataField(dataExpr), j.Field('linkSpecs', prettyArray([linkSpecEntry(s) for s in linkSpecs], 4)) { Hide: 0 }] +
    (if columnsExpr != null then [j.Field('table', prettyObject([
       j.Field('at', j.Array([j.String('items')])),
       j.Field('columns', columnsExpr),
     ], 4)) { Hide: 0 }] else []),
    2
  );
  local nodeView(name) = member(member(var('a'), name), 'node');
  local nodePath(path) = j.Array([j.String(p) for p in path]);
  local node(path, viewExpr, body) = j.Array([nodePath(path), j.Add(viewExpr, body)]);
  local emptyNode(path) = j.Array([nodePath(path), j.Object()]);

  local columnLiteral(col) = compactLiteral({ label: col.label, path: col.path });
  local resourceColumns(resource) =
    local cols = std.get(resource, 'columns', []);
    if std.length(cols) > 0 then
      prettyArray([columnLiteral(col) for col in cols], 4)
    else null;
  local listView(resource) =
    if std.length(std.get(resource, 'columns', [])) > 0 then nodeView('table') else nodeView('list');

  local namespacedAllList(resource) =
    local data = k8sGet(namespacedAllPath(resource));
    node(
      ['kubernetes', '$context'] + resourcePrefix + [route(resource)],
      listView(resource),
      listObject(data, [allNamespacesLinkSpec(resource)], resourceColumns(resource))
    );

  local namespacedList(resource) =
    local data = k8sGet(namespacedListPath(resource));
    node(
      ['kubernetes', '$context', '$namespace'] + resourcePrefix + [route(resource)],
      listView(resource),
      listObject(data, [singleNamespaceLinkSpec(resource)], resourceColumns(resource))
    );

  local namespacedDetail(resource) =
    node(
      ['kubernetes', '$context', '$namespace'] + resourcePrefix + ['$' + itemVar(resource)],
      nodeView('resource'),
      dataObject(k8sNeatGet(namespacedDetailPath(resource)))
    );

  local clusterList(resource) =
    local data = k8sGet(clusterListPath(resource));
    node(
      ['kubernetes', '$context'] + resourcePrefix + [route(resource)],
      listView(resource),
      listObject(data, [clusterLinkSpec(resource)], resourceColumns(resource))
    );

  local clusterDetail(resource) =
    node(
      ['kubernetes', '$context'] + resourcePrefix + ['$' + itemVar(resource)],
      nodeView('resource'),
      dataObject(k8sNeatGet(clusterDetailPath(resource)))
    );

  local resourceNodes(resource) =
    if resource.namespaced then
      (if hasVerb(resource, 'list') then [namespacedAllList(resource), namespacedList(resource)] else []) +
      (if hasVerb(resource, 'get') then [namespacedDetail(resource)] else [])
    else
      (if hasVerb(resource, 'list') then [clusterList(resource)] else []) +
      (if hasVerb(resource, 'get') then [clusterDetail(resource)] else []);

  local hasNamespacedResources = std.length([r for r in resources if r.namespaced]) > 0;
  local groupContextNodes = if group != '' then [emptyNode(['kubernetes', '$context', group])] else [];
  local groupNamespaceNodes =
    if group != '' && hasNamespacedResources
    then [emptyNode(['kubernetes', '$context', '$namespace', group])]
    else [];

  groupContextNodes +
  groupNamespaceNodes +
  std.flattenArrays([resourceNodes(r) for r in resources]);

local generateAll(groups, manifest=true) =
  local le(indent=0) = j.Fodder.LineEnd(0, indent);
  local prettyArray(elements, indent=0) =
    j.Array([elem.fodder(le(indent + 2)) for elem in elements]).closeFodder(le(indent));
  local prettyObject(fields, indent=0) =
    j.Object([field { fodder: [le(indent + 2)] } for field in fields]).closeFodder(le(indent));
  local prettyObjectComp(fields, specs, indent=0) =
    j.ObjectComp(
      [field { fodder: [le(indent + 2)] } for field in fields],
      [spec.forFodder(le(indent + 2)) for spec in specs]
    ).closeFodder(le(indent));
  local var(name) = j.Var(name);
  local member(expr, name) = j.Member(expr, name);
  local call(expr, args=[]) = j.Apply(expr, args);

  local contextsNode = j.Array([
    j.Array([j.String('kubernetes'), j.String('contexts')]),
    j.Add(
      member(member(var('a'), 'list'), 'node'),
      prettyObject([
        j.Field('data', call(member(var('kubernetes'), 'contexts'))),
        j.Field('links', prettyObjectComp(
          [j.Field(member(var('c'), 'name'), call(member(member(var('root'), 'kubernetes'), 'context'), [member(var('c'), 'name')]))],
          [j.ForSpec('c', member(j.Dollar, 'data'))],
          4
        )),
      ], 2)
    ),
  ]);
  local contextNode = j.Array([
    j.Array([j.String('kubernetes'), j.String('$context')]),
    j.Object(),
  ]);

  local allRouteNodes = [contextsNode, contextNode] + std.flattenArrays([
    generate(g.resources, g.group)
    for g in groups
  ]);
  local generated = j.Locals(
    [
      j.LocalBind('a', j.Import('arcourse-ui/main.libsonnet')),
      j.LocalBind('kubernetes', j.Import('kubernetes/main.libsonnet')),
      j.LocalBind('root', j.Import('root')),
    ],
    prettyArray(allRouteNodes)
  );
  if manifest then j.manifestJsonnet(generated) else generated;

local groupVersionFromSpec(specStr) =
  local spec = std.parseJson(specStr);
  local firstPath = std.objectFields(spec.paths)[0];
  local parts = [p for p in std.split(firstPath, '/') if p != ''];
  if parts[0] == 'api' then { group: '', version: parts[1] }
  else { group: parts[1], version: parts[2] };

local linksFromSpec(specStr) =
  local spec = std.parseJson(specStr);
  local suffix = '/{name}';
  local suffixLen = std.length(suffix);
  local endsWith(s) =
    std.length(s) >= suffixLen &&
    std.substr(s, std.length(s) - suffixLen, suffixLen) == suffix;
  [
    { sourcePath: std.substr(p, 0, std.length(p) - suffixLen), targetPath: p, array: ['items'], vars: { name: ['metadata', 'name'] } }
    for p in std.objectFields(spec.paths)
    if endsWith(p) && std.objectHas(spec.paths, std.substr(p, 0, std.length(p) - suffixLen))
  ];

local resourcesFromSpecAndLinks(specStr, links, columns, group) =
  local spec = std.parseJson(specStr);
  local effectiveLinks = if links != null then links else linksFromSpec(specStr);
  local isNamespacedPath(path) =
    std.length(std.findSubstr('/namespaces/{', path)) > 0;
  local resourceNameFromPath(path) =
    local parts = [p for p in std.split(path, '/') if p != ''];
    parts[std.length(parts) - 1];
  local findKind(path) =
    local pathEntry = std.get(spec.paths, path, {});
    local getOp = std.get(pathEntry, 'get', null);
    if getOp == null then null
    else std.get(getOp, 'x-kubernetes-group-version-kind', null);
  local defaultColumns(path) =
    [{ key: 'metadata.name', kind: 'name', label: 'Name', path: ['metadata', 'name'], priority: 'primary' }] +
    (if isNamespacedPath(path) then [{ key: 'metadata.namespace', kind: 'text', label: 'Namespace', path: ['metadata', 'namespace'], priority: 'secondary' }] else []) +
    [{ key: 'metadata.creationTimestamp', kind: 'timestamp', label: 'Created', path: ['metadata', 'creationTimestamp'], priority: 'tertiary' }];
  local findColumns(path) =
    local matching = [c for c in columns if c.sourcePath == path];
    if std.length(matching) > 0 then matching[0].columns else defaultColumns(path);
  local resourceFromLink(link) =
    local name = resourceNameFromPath(link.sourcePath);
    local gvk = findKind(link.sourcePath);
    {
      name: name,
      kind: if gvk != null then gvk.kind else 'Unknown',
      namespaced: isNamespacedPath(link.sourcePath),
      verbs: ['get', 'list'],
      group: group,
      columns: findColumns(link.sourcePath),
    };
  dedupeResources([resourceFromLink(link) for link in effectiveLinks]);

local defaultColumns(namespaced) =
  [{ key: 'metadata.name', kind: 'name', label: 'Name', path: ['metadata', 'name'], priority: 'primary' }] +
  (if namespaced then [{ key: 'metadata.namespace', kind: 'text', label: 'Namespace', path: ['metadata', 'namespace'], priority: 'secondary' }] else []) +
  [{ key: 'metadata.creationTimestamp', kind: 'timestamp', label: 'Created', path: ['metadata', 'creationTimestamp'], priority: 'tertiary' }];

local resourcesFromDiscovery(discovery, group, columns, links) =
  local groupVersion = if group == '' then 'v1' else discovery.groupVersion;
  local bareVersion =
    local parts = std.split(discovery.groupVersion, '/');
    parts[std.length(parts) - 1];
  local columnsForGroup = std.get(columns, groupVersion, []);
  local linksForGroup = std.get(links, groupVersion, null);
  local apiPrefix = if group == '' then '/api/' + discovery.groupVersion else '/apis/' + discovery.groupVersion;
  local isNamespaced(r) = r.namespaced;
  local sourcePath(r) = if isNamespaced(r) then apiPrefix + '/namespaces/{namespace}/' + r.name else apiPrefix + '/' + r.name;
  local findColumns(r) =
    local path = sourcePath(r);
    local matching = [c for c in columnsForGroup if c.sourcePath == path];
    if std.length(matching) > 0 then matching[0].columns else defaultColumns(isNamespaced(r));
  local effectiveLinks = if linksForGroup != null then linksForGroup else [];
  local linkedNames = std.set([
    local parts = [p for p in std.split(l.sourcePath, '/') if p != ''];
    parts[std.length(parts) - 1]
    for l in effectiveLinks
  ]);
  dedupeResources([
    r { group: group, version: bareVersion, columns: findColumns(r) }
    for r in discovery.resources
    if std.length(std.findSubstr('/', r.name)) == 0
  ]);

local mergeGroups(groups) =
  local byKey = std.foldl(
    function(acc, g)
      local key = g.group;
      acc {
        [key]: if std.objectHas(acc, key)
        then acc[key] { resources: dedupeResources(acc[key].resources + g.resources) }
        else g,
      },
    groups,
    {}
  );
  [byKey[k] for k in std.objectFields(byKey)];

local groupVersionsOrdered(g) =
  [g.preferredVersion] + [v for v in g.versions if v.version != g.preferredVersion.version];

local groupsFromContext(ctx, columns, links) =
  local core = kubernetes.get(ctx, '/api/v1');
  local apis = kubernetes.get(ctx, '/apis');
  [{ group: '', resources: resourcesFromDiscovery(core, '', columns, links) }] + std.flattenArrays([
    [
      local discovery = kubernetes.get(ctx, '/apis/' + v.groupVersion);
      { group: g.name, resources: resourcesFromDiscovery(discovery, g.name, columns, links) }
      for v in groupVersionsOrdered(g)
    ]
    for g in apis.groups
  ]);

local graph = {
  manifest: true,
  contexts: error 'contexts is required',
  data:
    local columns = if std.objectHas(self, 'columns') then self.columns else {};
    local links = if std.objectHas(self, 'links') then self.links else {};
    {
      groups: mergeGroups(std.flattenArrays([
        groupsFromContext(ctx, columns, links)
        for ctx in $.contexts
      ])),
    },
  _view:: {
    jsonnet: generateAll($.data.groups, $.manifest),
  },
};

{
  graph: graph,
}
