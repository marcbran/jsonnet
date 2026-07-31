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
local openapi = {
  apiSpec(spec): std.native('invoke:openapi')('apiSpec', [spec]),
  nestedSpec(spec): std.native('invoke:openapi')('nestedSpec', [spec]),
};

local generate(service, spec, links=[], columns=[], contextParams=[], manifest=true) =
  local le(indent=0) = j.Fodder.LineEnd(0, indent);
  local prettyArray(elements, indent=0) =
    j.Array([
      elem.fodder(le(indent + 2))
      for elem in elements
    ]).closeFodder(le(indent));
  local prettyObject(fields, indent=0) =
    j.Object([
      field { fodder: [le(indent + 2)] }
      for field in fields
    ]).closeFodder(le(indent));
  local prettyArrayComp(body, specs, indent=0) =
    j.ArrayComp(
      body,
      [
        if spec.__kind__ == 'ForSpec' then spec.forFodder(le(indent + 2))
        else if spec.__kind__ == 'IfSpec' then spec.ifFodder(le(indent + 2))
        else spec
        for spec in specs
      ]
    ).closeFodder(le(indent));
  local prettyObjectComp(fields, specs, indent=0) =
    j.ObjectComp(
      [
        field { fodder: [le(indent + 2)] }
        for field in fields
      ],
      [
        if spec.__kind__ == 'ForSpec' then spec.forFodder(le(indent + 2))
        else if spec.__kind__ == 'IfSpec' then spec.ifFodder(le(indent + 2))
        else spec
        for spec in specs
      ]
    ).closeFodder(le(indent));
  local prettyApply(target, args, indent=0) =
    j.Apply(target, [
      arg.fodder(le(indent + 2))
      for arg in args
    ]).rightFodder(le(indent));

  local isAsciiLetter(c) =
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
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
  local objectField(name, expr) =
    if std.type(name) == 'string' && isUnquotedFieldName(name) then j.Field(name, expr) else j.Field(j.String(name), expr);
  local access(expr, name) =
    if isUnquotedFieldName(name) then j.Member(expr, name) else j.Index(expr, j.String(name));

  local pathParamInner(seg) =
    local len = std.length(seg);
    if len >= 2 && std.substr(seg, 0, 1) == '{' && std.substr(seg, len - 1, 1) == '}' then
      std.substr(seg, 1, len - 2)
    else null;
  local mangledPathVar(name) =
    if isJsonnetIdent(name) && !isJsonnetKeyword(name) then name
    else 'p_' + std.md5(name);
  local routeSegment(seg) =
    local inner = pathParamInner(seg);
    if inner == null then seg else '$' + mangledPathVar(inner);
  local splitPath(path) = [part for part in std.split(path, '/') if part != ''];
  local contextPrefix = std.flattenArrays([[p, '$' + mangledPathVar(p)] for p in contextParams]);

  local var(name) = j.Var(name);
  local member(expr, name) = j.Member(expr, name);
  local call(expr, args=[]) = j.Apply(expr, args);
  local callPretty(expr, args, indent=0) = prettyApply(expr, args, indent);
  local emptyObject = j.Object([]);
  local literal(value, indent=0) =
    if value == null then j.Null
    else if std.type(value) == 'string' then j.String(value)
    else if std.type(value) == 'boolean' then if value then j.True else j.False
    else if std.type(value) == 'number' then j.Number(std.toString(value))
    else if std.type(value) == 'array' then prettyArray([literal(item, indent + 2) for item in value], indent)
    else if std.type(value) == 'object' then prettyObject([
      objectField(field, literal(value[field], indent + 2))
      for field in std.objectFields(value)
    ], indent)
    else error 'unsupported literal type: ' + std.type(value);

  local pathExpr(op) =
    local fmt = std.get(op, 'pathFormat', '/');
    local ns = std.get(op, 'pathArgNames', []);
    if std.length(ns) == 0 then j.String(fmt)
    else j.Std.format(
      j.String(fmt),
      j.Array([
        j.Std.toString(access(j.Dollar, mangledPathVar(n)))
        for n in ns
      ])
    );
  local templatePath(op) =
    local fmt = std.get(op, 'pathFormat', '/');
    local ns = std.get(op, 'pathArgNames', []);
    local parts = std.split(fmt, '%s');
    if std.length(ns) == 0 then fmt
    else std.join('', [
      parts[i] + (if i < std.length(ns) then '{' + ns[i] + '}' else '')
      for i in std.range(0, std.length(parts) - 1)
    ]);

  local bucketExpr(bucketKey) =
    j.Std.get(j.Dollar, j.String(bucketKey)).default(emptyObject);
  local argField(bucketKey, p) =
    local bucket = bucketExpr(bucketKey);
    objectField(
      p.name,
      if p.required then j.Index(bucket, j.String(p.name))
      else j.Std.get(bucket, j.String(p.name)).default(j.Null)
    );
  local paramObject(bucketKey, params) =
    if std.length(params) == 0 then
      emptyObject
    else
      prettyObject([argField(bucketKey, p) for p in params], 6);

  local contextObject =
    if std.length(contextParams) == 0 then null
    else prettyObject([
      objectField(p, access(j.Dollar, mangledPathVar(p)))
      for p in contextParams
    ], 6);
  local inputObject(op) =
    local q = std.get(op, 'queryParams', []);
    local h = std.get(op, 'headerParams', []);
    local base = [
      j.Field('method', j.String('GET')),
      j.Field('path', pathExpr(op)),
    ];
    local withQuery =
      if std.length(q) > 0 then base + [j.Field('query', paramObject('query', q))] else base;
    local withHeaders =
      if std.length(h) > 0 then withQuery + [j.Field('headers', paramObject('headers', h))] else withQuery;
    local withContext =
      if contextObject == null then withHeaders else withHeaders + [j.Field('context', contextObject)];
    prettyObject(withContext, 6);

  local request(op) =
    callPretty(call(member(var('std'), 'native'), [j.String('invoke:' + service)]), [
      j.String('request'),
      prettyArray([inputObject(op)], 4),
    ], 4);

  local pathValue(expr, path) =
    std.foldl(function(acc, part) access(acc, part), path, expr);
  local dataArray(link) = pathValue(member(j.Dollar, 'data'), link.array);
  local isArrayExpr(expr) =
    j.Eq(call(member(var('std'), 'type'), [expr]), j.String('array'));
  local safeDataArray(link) =
    j.Local([j.LocalBind('arr', dataArray(link))], j.If(isArrayExpr(var('arr')), var('arr'), j.Array([])));
  local itemValue(path) = pathValue(var('item'), path);
  local paramValue(link, param) =
    if std.objectHas(std.get(link, 'vars', {}), param) then itemValue(link.vars[param])
    else access(j.Dollar, mangledPathVar(param));
  local targetLink(link) =
    std.foldl(
      function(acc, part)
        local param = pathParamInner(part);
        if param == null then access(acc, part)
        else call(access(acc, mangledPathVar(param)), [j.Std.toString(paramValue(link, param))]),
      splitPath(link.targetPath),
      access(var('root'), service)
    );
  local targetParams(link) = [
    param
    for part in splitPath(link.targetPath)
    for param in [pathParamInner(part)]
    if param != null
  ];
  local objectHas(expr, field) =
    call(member(var('std'), 'objectHas'), [expr, j.String(field)]);
  local isObject(expr) =
    j.Eq(call(member(var('std'), 'type'), [expr]), j.String('object'));
  local itemPathGuard(path) =
    local guard(expr, parts) =
      if std.length(parts) == 0 then j.Neq(expr, j.Null)
      else
        local next = access(expr, parts[0]);
        j.And(
          j.And(
            j.Neq(expr, j.Null),
            j.And(isObject(expr), objectHas(expr, parts[0]))
          ),
          guard(next, std.slice(parts, 1, std.length(parts), 1))
        );
    guard(var('item'), path);
  local linkGuard(link) =
    local guards = [
      itemPathGuard(link.vars[param])
      for param in std.objectFields(std.get(link, 'vars', {}))
      if std.objectHas(std.get(link, 'vars', {}), param)
    ];
    if std.length(guards) == 0 then null
    else std.foldl(
      function(acc, guard) j.And(acc, guard),
      std.slice(guards, 1, std.length(guards), 1),
      guards[0]
    );
  local nestedLinkValue(link, params, index, indent=6) =
    if index >= std.length(params) then targetLink(link)
    else prettyObject([
      j.Field(
        j.Std.toString(paramValue(link, params[index])),
        nestedLinkValue(link, params, index + 1, indent + 2)
      ) { SuperSugar: index < std.length(params) - 1 },
    ], indent);
  local nestedLinkObject(link) =
    local params = targetParams(link);
    prettyObject([
      j.Field(
        j.Std.toString(paramValue(link, params[0])),
        nestedLinkValue(link, params, 1)
      ) { SuperSugar: std.length(params) > 1 },
    ], 6);
  local mergeLink(link) =
    j.Add(var('acc'), nestedLinkObject(link));
  local linkComprehension(link) =
    local guard = linkGuard(link);
    local body = if guard == null then mergeLink(link) else j.If(guard, mergeLink(link), var('acc'));
    callPretty(member(var('std'), 'foldl'), [
      j.Function([j.Parameter('acc'), j.Parameter('item')], body),
      safeDataArray(link),
      emptyObject,
    ], 4);
  local linkComprehensions(links) = [linkComprehension(link) for link in links];
  local linksExpr(links) =
    local exprs = linkComprehensions(links);
    std.foldl(
      function(acc, expr) j.Add(acc, expr),
      std.slice(exprs, 1, std.length(exprs), 1),
      exprs[0]
    );
  local linksFor(op) = [
    link
    for link in links
    if link.sourcePath == templatePath(op)
  ];
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
  local columnsFor(op) =
    local matching = [c for c in columns if c.sourcePath == templatePath(op)];
    if std.length(matching) > 0 then matching[0].columns else null;
  local defaultColumns(op) =
    local ls = linksFor(op);
    if std.length(ls) == 0 then null
    else
      local link = ls[0];
      local params = targetParams(link);
      local vars = std.get(link, 'vars', {});
      local varParams = [p for p in params if std.objectHas(vars, p)];
      if std.length(varParams) == 0 then null
      else [
        { label: p, path: vars[p], link: p == varParams[std.length(varParams) - 1] }
        for p in varParams
      ];
  local columnsForOp(op) =
    local explicit = columnsFor(op);
    if explicit != null then explicit
    else
      local d = defaultColumns(op);
      if d != null then d else [];
  local columnLink(link) = j.FieldFunction('link', [j.Parameter('item')], targetLink(link));
  local columnLiteral(col, link) =
    local base = compactLiteral({ label: col.label, path: col.path });
    if std.get(col, 'link', false) && link != null then
      base { fields+: [columnLink(link)] }
    else base;
  local resourceColumns(op) =
    local cols = columnsForOp(op);
    if std.length(cols) == 0 then null
    else
      local ls = linksFor(op);
      local firstLink = if std.length(ls) > 0 then ls[0] else null;
      prettyArray([columnLiteral(col, firstLink) for col in cols], 4);
  local view(name) = member(member(var('a'), name), 'view');
  local listView(op) =
    if resourceColumns(op) != null then view('table') else view('list');
  local dataField(expr, hidden=false) =
    j.Field('data', expr) { Hide: if hidden then 0 else 1 };
  local dataObject(op, expr) =
    local links = linksFor(op);
    local fields = [dataField(expr)] +
                   (if std.length(links) == 0 then [] else [j.Field('links', linksExpr(links))]);
    prettyObject(fields, 2);
  local listObject(op, expr) =
    local links = linksFor(op);
    local cols = resourceColumns(op);
    local firstLink = if std.length(links) > 0 then links[0] else null;
    local fields = [dataField(expr, hidden=true)] +
                   (if std.length(links) == 0 then [] else [j.Field('links', linksExpr(links))]) +
                   (if cols != null then [j.Field('columns', cols) { Hide: 0 }] else []) +
                   (if cols != null && firstLink != null then [j.Field('itemsPath', compactLiteral(firstLink.array)) { Hide: 0 }] else []);
    prettyObject(fields, 2);
  local node(path, body, viewExpr) = j.Array([
    j.Array([j.String(p) for p in path]),
    body,
    viewExpr,
  ]);
  local resourceOperationNode(path, op) =
    node(
      [service] + contextPrefix + [routeSegment(p) for p in path],
      dataObject(op, request(op)),
      view('resource')
    );
  local listOperationNode(path, op) =
    node(
      [service] + contextPrefix + [routeSegment(p) for p in path],
      listObject(op, request(op)),
      listView(op)
    );
  local operationNodesForPath(path, op) =
    if std.length(linksFor(op)) > 0 then [listOperationNode(path, op)]
    else [resourceOperationNode(path, op)];
  local hasRequiredParams(params) =
    std.length([p for p in params if p.required]) > 0;
  local isResourceOperation(op) =
    !hasRequiredParams(std.get(op, 'queryParams', [])) &&
    !hasRequiredParams(std.get(op, 'headerParams', []));

  local childrenOf(node) = std.get(node, 'children', {});
  local childKeys(node) = std.sort(std.objectFields(childrenOf(node)));
  local operationNodes(node, path=[]) =
    (if std.get(node, 'operation', null) != null && isResourceOperation(node.operation) then operationNodesForPath(path, node.operation) else []) +
    std.flattenArrays([
      operationNodes(childrenOf(node)[k], if k == '_' then path else path + [k])
      for k in childKeys(node)
    ]);

  local generated = j.Locals(
    [j.LocalBind('a', j.Import('arcourse-ui/main.libsonnet'))] +
    (if std.length(links) == 0 then [] else [j.LocalBind('root', j.Import('root'))]),
    prettyArray(operationNodes(spec.paths))
  );

  if manifest then j.manifestJsonnet(generated) else generated;

local graph = {
  manifest: true,
  contextParams: [],
  data: {
    spec: openapi.nestedSpec($.spec),
    links: std.get($, 'links', []),
    columns: std.get($, 'columns', []),
  },
  _view:: {
    jsonnet: generate($.service, $.data.spec, $.data.links, $.data.columns, $.contextParams, $.manifest),
  },
};

{
  graph: graph,
}
