local graphLib =
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
    get(ctx, path, fields=[]): std.native('invoke:kubernetes')('get', [ctx, path, fields]),
    neat: {
      get(ctx, path, fields=[]): std.native('invoke:kubernetes')('neatGet', [ctx, path, fields]),
    },
  };

  local fieldListMixin = |||
    {
      kubernetes+: {
        table+: {
          fieldList(columns, linkSpecs)::
            std.set([
              std.join('.', path)
              for col in columns
              for path in std.get(col, 'paths', [col.path])
            ] + [
              std.join('.', seg.path)
              for spec in linkSpecs
              if std.isArray(spec.value)
              for seg in std.get(spec, 'keys', []) + spec.value
              if std.objectHas(seg, 'path')
            ]),
        },
      },
    }
  |||;

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

  local namespaceLinkSpec = {
    at: ['metadata'],
    keys: [{ const: 'namespace' }],
    value: [{ const: 'kubernetes' }, { origin: 'context' }, { param: 'namespace', path: ['namespace'] }],
  };

  local ownerReferenceLinkSpec = {
    at: ['metadata', 'ownerReferences'],
    keys: [{ const: 'owner' }, { path: ['name'] }],
    value: [
      { const: 'kubernetes' },
      { origin: 'context' },
      { origin: 'namespace' },
      { path: ['apiVersion'], transform: "function(v) local p = std.split(v, '/'); if std.length(p) > 1 then p[0] else ''" },
      { param: { path: ['kind'], transform: 'std.asciiLower' }, path: ['name'] },
    ],
  };

  local isSubdomainPattern(pattern) = std.startsWith(pattern, '*.');

  local matchesGroup(pattern, group) =
    if pattern == '*' then true
    else if isSubdomainPattern(pattern) then std.endsWith(group, pattern[1:])
    else group == pattern || std.endsWith(group, '.' + pattern);

  local patternSpecificity(pattern) =
    if pattern == '*' then 0
    else if isSubdomainPattern(pattern) then std.length(std.split(pattern[2:], '.')) + 0.5
    else std.length(std.split(pattern, '.'));

  local bestMatch(patterns, group) =
    local matches = [
      { index: i, specificity: patternSpecificity(patterns[i]) }
      for i in std.range(0, std.length(patterns) - 1)
      if matchesGroup(patterns[i], group)
    ];
    if std.length(matches) == 0 then null
    else std.sort(matches, function(m) [-m.specificity, m.index])[0];

  local groupLayout(groups, favorites, collapsed) =
    local category(group) = if std.length(std.findSubstr('.', group)) == 0 then 0 else 1;
    local favoriteRank(group) =
      local m = bestMatch(favorites, group);
      if m == null then std.length(favorites) else m.index;
    local isCollapsed(group) =
      local c = bestMatch(collapsed, group);
      local f = bestMatch(favorites, group);
      c != null && (f == null || c.specificity > f.specificity);
    local ordered = std.sort(groups, function(group) [favoriteRank(group), category(group)] + std.reverse(std.split(group, '.')));
    {
      expanded: [g for g in ordered if !isCollapsed(g)],
      collapsed: [g for g in ordered if isCollapsed(g)],
    };

  local listViewField(columns, layout, remainingTitle) =
    local le(indent) = j.Fodder.LineEnd(0, indent);
    local stringArray(values) = j.Array([j.String(v).fodder(le(8)) for v in values]).closeFodder(le(6));
    local hasCollapsed = std.length(layout.collapsed) > 0;
    local order = layout.expanded + (if hasCollapsed then [remainingTitle] else []);
    local fields =
      [j.Field('columns', j.Number(std.toString(columns)))] +
      (if std.length(order) > 0 then [j.Field('groupOrder', stringArray(order))] else []) +
      (if hasCollapsed then [j.Field('nodeGroups', j.Object([
         j.Field(j.String(remainingTitle), j.Array([j.String(g).fodder(le(10)) for g in layout.collapsed]).closeFodder(le(8))) { fodder: [le(8)] },
       ]).closeFodder(le(6)))] else []);
    j.Field(
      'list',
      if std.length(fields) == 1 then j.Object(fields)
      else j.Object([field { fodder: [le(6)] } for field in fields]).closeFodder(le(4))
    ) { Hide: 0 };

  local generate(resources, group, links=[], globalLinkSpecs=[], collapsed=false, namespaceListField=null) =
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

    local k8sNeatGet(pathExpr, fieldsExpr=null) =
      call(
        member(member(var('kubernetes'), 'neat'), 'get'),
        [access(j.Dollar, 'context'), pathExpr] + (if fieldsExpr == null then [] else [fieldsExpr])
      );

    local k8sGet(pathExpr, fieldsExpr) =
      call(
        member(var('kubernetes'), 'get'),
        [access(j.Dollar, 'context'), pathExpr, fieldsExpr]
      );

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

    local clusterDetailPathStr(resource) = apiPrefix(resource) + '/' + resource.name + '/{name}';
    local namespacedDetailPathStr(resource) = apiPrefix(resource) + '/namespaces/{namespace}/' + resource.name + '/{name}';

    local isNamespacesConst(seg) = std.objectHas(seg, 'const') && seg.const == 'namespaces';
    local resourceItemVarByName = { [r.name]: itemVar(r) for r in resources };
    local wellKnownItemVars = { namespaces: 'namespace', nodes: 'node' };
    local targetItemVarFor(name) =
      if std.objectHas(resourceItemVarByName, name) then resourceItemVarByName[name]
      else if std.objectHas(wellKnownItemVars, name) then wellKnownItemVars[name]
      else null;
    local renameParam(seg, name) = if std.objectHas(seg, 'param') then seg { param: name } else seg;
    local rewriteLinkValue(value) =
      local isCore = value[0].const == 'api';
      local targetGroupSegment = if isCore then [] else [value[1]];
      local afterPrefix = std.slice(value, if isCore then 2 else 3, std.length(value), 1);
      local hasNamespace = std.length(afterPrefix) >= 2 && isNamespacesConst(afterPrefix[0]);
      local namespaceValueSeg = if hasNamespace then renameParam(afterPrefix[1], 'namespace') else null;
      local afterNamespace = if hasNamespace then std.slice(afterPrefix, 2, std.length(afterPrefix), 1) else afterPrefix;
      if std.length(afterNamespace) == 0 then
        if namespaceValueSeg == null then null
        else [{ const: 'kubernetes' }, contextOrigin] + targetGroupSegment + [namespaceValueSeg]
      else
        local rawIdSeg = afterNamespace[std.length(afterNamespace) - 1];
        local rawResourceNameSeg = if std.length(afterNamespace) >= 2 then afterNamespace[std.length(afterNamespace) - 2] else null;
        local targetItemVar =
          if rawResourceNameSeg != null && std.objectHas(rawResourceNameSeg, 'const')
          then targetItemVarFor(rawResourceNameSeg.const)
          else null;
        if targetItemVar == null then null
        else
          [{ const: 'kubernetes' }, contextOrigin] +
          (if hasNamespace then [namespaceValueSeg] else []) +
          targetGroupSegment +
          [renameParam(rawIdSeg, targetItemVar)];
    local linksAt(path) =
      local candidates = [l { value: rewriteLinkValue(l.value) } for l in links if l.sourcePath == path];
      [l for l in candidates if l.value != null];

    local objectField(name, expr) =
      if isUnquotedFieldName(name) then j.Field(name, expr) else j.Field(j.String(name), expr);

    local compactLiteral(value) =
      if value == null then j.Null
      else if std.type(value) == 'string' then j.String(value)
      else if std.type(value) == 'boolean' then if value then j.True else j.False
      else if std.type(value) == 'number' then j.Number(std.toString(value))
      else if std.type(value) == 'array' then j.Array([compactLiteral(item) for item in value])
      else if std.type(value) == 'object' then j.Object([
        objectField(field, if field == 'transform' then j.parseJsonnet(value[field]) else compactLiteral(value[field]))
        for field in std.objectFields(value)
      ])
      else error 'unsupported literal type: ' + std.type(value);

    local dataField(expr, hidden=false) =
      j.Field('data', expr) { Hide: if hidden then 0 else 1 };
    local linkSpecEntry(spec) =
      prettyObject([objectField(field, compactLiteral(spec[field])) for field in ['at', 'keys', 'value']], 6);
    local dataObject(expr, linkSpecs=[], viewFields=[]) = prettyObject(
      [dataField(expr)] +
      (if std.length(linkSpecs) > 0 then [j.Field('linkSpecs', prettyArray([linkSpecEntry(s) for s in linkSpecs], 4)) { Hide: 0 }] else []) +
      viewFields,
      2
    );
    local listObject(dataExpr, linkSpecs, columnsExpr=null) = prettyObject(
      [dataField(dataExpr, columnsExpr != null), j.Field('linkSpecs', prettyArray([linkSpecEntry(s) for s in linkSpecs], 4)) { Hide: 0 }] +
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

    local tableFields = call(
      member(member(member(var('a'), 'kubernetes'), 'table'), 'fieldList'),
      [member(member(j.Dollar, 'table'), 'columns'), member(j.Dollar, 'linkSpecs')]
    );
    local listData(resource, pathExpr) =
      if resourceColumns(resource) != null then k8sGet(pathExpr, tableFields) else k8sNeatGet(pathExpr);

    local namespacedAllList(resource) =
      local linkSpecs = [allNamespacesLinkSpec(resource)];
      local columnsExpr = resourceColumns(resource);
      local data = listData(resource, namespacedAllPath(resource));
      node(
        ['kubernetes', '$context'] + resourcePrefix + [route(resource)],
        listView(resource),
        listObject(data, linkSpecs, columnsExpr)
      );

    local namespacedList(resource) =
      local linkSpecs = [singleNamespaceLinkSpec(resource)];
      local columnsExpr = resourceColumns(resource);
      local data = listData(resource, namespacedListPath(resource));
      node(
        ['kubernetes', '$context', '$namespace'] + resourcePrefix + [route(resource)],
        listView(resource),
        listObject(data, linkSpecs, columnsExpr)
      );

    local namespacedDetail(resource) =
      node(
        ['kubernetes', '$context', '$namespace'] + resourcePrefix + ['$' + itemVar(resource)],
        nodeView('resource'),
        dataObject(k8sNeatGet(namespacedDetailPath(resource)), globalLinkSpecs + linksAt(namespacedDetailPathStr(resource)))
      );

    local clusterList(resource) =
      local linkSpecs = [clusterLinkSpec(resource)];
      local columnsExpr = resourceColumns(resource);
      local data = listData(resource, clusterListPath(resource));
      node(
        ['kubernetes', '$context'] + resourcePrefix + [route(resource)],
        listView(resource),
        listObject(data, linkSpecs, columnsExpr)
      );

    local namespaceViewFields(resource) =
      if group == '' && resource.name == 'namespaces' then [
        j.Field('resource', compactLiteral({ stacked: true })) { Hide: 0 },
        namespaceListField,
      ] else [];
    local clusterDetail(resource) =
      node(
        ['kubernetes', '$context'] + resourcePrefix + ['$' + itemVar(resource)],
        nodeView('resource'),
        dataObject(k8sNeatGet(clusterDetailPath(resource)), globalLinkSpecs + linksAt(clusterDetailPathStr(resource)), namespaceViewFields(resource))
      );

    local resourceNodes(resource) =
      if resource.namespaced then
        (if hasVerb(resource, 'list') then [namespacedAllList(resource), namespacedList(resource)] else []) +
        (if hasVerb(resource, 'get') then [namespacedDetail(resource)] else [])
      else
        (if hasVerb(resource, 'list') then [clusterList(resource)] else []) +
        (if hasVerb(resource, 'get') then [clusterDetail(resource)] else []);

    local hasNamespacedResources = std.length([r for r in resources if r.namespaced]) > 0;
    local groupContextNodes = if collapsed && group != '' then [emptyNode(['kubernetes', '$context', group])] else [];
    local groupNamespaceNodes =
      if collapsed && group != '' && hasNamespacedResources
      then [emptyNode(['kubernetes', '$context', '$namespace', group])]
      else [];

    groupContextNodes +
    groupNamespaceNodes +
    std.flattenArrays([resourceNodes(r) for r in resources]);

  local generateAll(groups, manifest=true, globalLinkSpecs=[], listColumns=4, favoriteGroups=[], collapsedGroups=[], remainingGroupsTitle='remaining groups') =
    local layout = groupLayout(std.set([g.group for g in groups if g.group != '']), favoriteGroups, collapsedGroups);
    local namespacedGroups = std.set([g.group for g in groups if std.length([r for r in g.resources if r.namespaced]) > 0]);
    local namespaceLayout = layout { collapsed: [g for g in super.collapsed if std.setMember(g, namespacedGroups)] };
    local namespaceListField = listViewField(listColumns, namespaceLayout, remainingGroupsTitle);
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
      prettyObject([listViewField(listColumns, layout, remainingGroupsTitle)], 2),
    ]);

    local allRouteNodes = [contextsNode, contextNode] + std.flattenArrays([
      generate(g.resources, g.group, std.get(g, 'links', []), globalLinkSpecs, std.member(layout.collapsed, g.group), namespaceListField)
      for g in groups
    ]);
    local binds = [
      j.LocalBind('base', j.Import('arcourse-ui/main.libsonnet')),
      j.LocalBind('a', j.Add(var('base'), j.parseJsonnet(fieldListMixin))),
      j.LocalBind('kubernetes', j.Import('kubernetes/main.libsonnet')),
      j.LocalBind('root', j.Import('root')),
    ];
    local generated = std.foldr(
      function(i, acc)
        local node = j.Local(binds[i], acc);
        if i == 0 then node else node.fodder(j.Fodder.LineEnd(0, 0)),
      std.range(0, std.length(binds) - 1),
      prettyArray(allRouteNodes).fodder(j.Fodder.LineEnd(0, 0))
    );
    if manifest then j.manifestJsonnet(generated) else generated;

  local groupVersionFromKey(key) =
    local parts = [p for p in std.split(key, '/') if p != ''];
    if parts[0] == 'api' then { group: '', version: parts[1] }
    else { group: parts[1], version: parts[2] };

  local linksFromSpec(spec) =
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

  local resourceNameFromPath(path) =
    local parts = [p for p in std.split(path, '/') if p != ''];
    local last = parts[std.length(parts) - 1];
    local isParam(s) = std.length(s) >= 1 && std.substr(s, 0, 1) == '{';
    if isParam(last) then parts[std.length(parts) - 2] else last;

  local isSubresourcePath(path) =
    local parts = [p for p in std.split(path, '/') if p != ''];
    std.length(parts) >= 2 &&
    parts[std.length(parts) - 2] == '{name}' &&
    std.substr(parts[std.length(parts) - 1], 0, 1) != '{';

  local resourcesFromSpec(spec, group, version, columns, links) =
    local groupVersion = if group == '' then version else group + '/' + version;
    local columnsForGroup = std.get(columns, groupVersion, []);
    local linksForGroup = std.get(links, groupVersion, null);
    local effectiveLinks = if linksForGroup != null then linksForGroup else linksFromSpec(spec);
    local nodeLinks = if linksForGroup != null then linksForGroup else [];
    local isNamespacedPath(path) =
      std.length(std.findSubstr('/namespaces/{', path)) > 0;
    local apiPrefix = if group == '' then '/api/' + version else '/apis/' + group + '/' + version;
    local collectionPath(name, namespaced) =
      apiPrefix + (if namespaced then '/namespaces/{namespace}/' else '/') + name;
    local detailPath(name, namespaced) = collectionPath(name, namespaced) + '/{name}';
    local findKind(path) =
      local pathEntry = std.get(spec.paths, path, {});
      local getOp = std.get(pathEntry, 'get', null);
      if getOp == null then null
      else std.get(getOp, 'x-kubernetes-group-version-kind', null);
    local hasGet(path) =
      std.objectHas(spec.paths, path) && std.objectHas(spec.paths[path], 'get');
    local defaultColumns(namespaced) =
      [{ key: 'metadata.name', kind: 'name', label: 'Name', path: ['metadata', 'name'], priority: 'primary' }] +
      (if namespaced then [{ key: 'metadata.namespace', kind: 'text', label: 'Namespace', path: ['metadata', 'namespace'], priority: 'secondary' }] else []) +
      [{ key: 'metadata.creationTimestamp', kind: 'timestamp', label: 'Created', path: ['metadata', 'creationTimestamp'], priority: 'tertiary' }];
    local findColumns(path, namespaced) =
      local matching = [c for c in columnsForGroup if c.sourcePath == path];
      if std.length(matching) > 0 then matching[0].columns else defaultColumns(namespaced);
    local resourceFromLink(link) =
      local name = resourceNameFromPath(link.sourcePath);
      local namespaced = isNamespacedPath(link.sourcePath);
      local gvk = findKind(link.sourcePath);
      {
        name: name,
        kind: if gvk != null then gvk.kind else 'Unknown',
        namespaced: namespaced,
        verbs: (if hasGet(collectionPath(name, namespaced)) then ['list'] else []) + (if hasGet(detailPath(name, namespaced)) then ['get'] else []),
        group: group,
        version: version,
        columns: findColumns(collectionPath(name, namespaced), namespaced),
      };
    {
      resources: dedupeResources([
        resourceFromLink(link)
        for link in effectiveLinks
        if !isSubresourcePath(link.sourcePath)
      ]),
      links: nodeLinks,
    };

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
    {
      resources: dedupeResources([
        r { group: group, version: bareVersion, columns: findColumns(r) }
        for r in discovery.resources
        if std.length(std.findSubstr('/', r.name)) == 0
      ]),
      links: effectiveLinks,
    };

  local mergeGroups(groups) =
    local byKey = std.foldl(
      function(acc, g)
        local key = g.group;
        acc {
          [key]: if std.objectHas(acc, key)
          then acc[key] {
            resources: dedupeResources(acc[key].resources + g.resources),
            links: std.get(acc[key], 'links', []) + std.get(g, 'links', []),
          }
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
    local coreResult = resourcesFromDiscovery(core, '', columns, links);
    [{ group: '', resources: coreResult.resources, links: coreResult.links }] + std.flattenArrays([
      [
        local discovery = kubernetes.get(ctx, '/apis/' + v.groupVersion);
        local result = resourcesFromDiscovery(discovery, g.name, columns, links);
        { group: g.name, resources: result.resources, links: result.links }
        for v in groupVersionsOrdered(g)
      ]
      for g in apis.groups
    ]);

  local groupsFromSpecs(specs, columns, links) =
    mergeGroups([
      local gv = groupVersionFromKey(key);
      local result = resourcesFromSpec(specs[key], gv.group, gv.version, columns, links);
      { group: gv.group, resources: result.resources, links: result.links }
      for key in std.objectFields(specs)
    ]);

  {
    _record: false,
    manifest:: true,
    favoriteGroups:: [],
    collapsedGroups:: [],
    remainingGroupsTitle:: 'remaining groups',
    listColumns:: 4,
    contexts:: [],
    specs:: {},
    globalLinkSpecs:: [namespaceLinkSpec, ownerReferenceLinkSpec],
    data::
      local columns = if std.objectHasAll(self, 'columns') then self.columns else {};
      local links = if std.objectHasAll(self, 'links') then self.links else {};
      {
        groups: mergeGroups(
          std.flattenArrays([groupsFromContext(ctx, columns, links) for ctx in $.contexts]) +
          groupsFromSpecs($.specs, columns, links)
        ),
      },
    _view:: {
      jsonnet: generateAll($.data.groups, $.manifest, $.globalLinkSpecs, $.listColumns, $.favoriteGroups, $.collapsedGroups, $.remainingGroupsTitle),
    },
  };
local nodeListsAppsLib =
  local a =
    local linkspecs =
      local url =
        local hexDigits = '0123456789ABCDEF';

        local unreserved(b) =
          (b >= 65 && b <= 90) || (b >= 97 && b <= 122) || (b >= 48 && b <= 57)
          || b == 45 || b == 95 || b == 46 || b == 126;

        local unreservedChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~';

        local percentEncode(s) =
          if std.length(std.stripChars(s, unreservedChars)) == 0 then s
          else std.join('', [
            if unreserved(b) then std.char(b)
            else '%' + hexDigits[std.floor(b / 16)] + hexDigits[b % 16]
            for b in std.encodeUTF8(s)
          ]);

        local queryValue(value) =
          if std.isString(value) then value
          else if std.isArray(value) then std.manifestJsonMinified(value)
          else std.toString(value);

        local query(params) =
          local keys = std.objectFields(params);
          if std.length(keys) == 0 then ''
          else '?' + std.join('&', [
            percentEncode(k) + '=' + percentEncode(queryValue(params[k]))
            for k in keys
          ]);

        function(u)
          local scheme = std.get(u, 'scheme', null);
          local path = std.get(u, 'path', []);
          (if scheme != null then scheme + '://' else '')
          + std.get(u, 'host', '')
          + (if std.length(path) > 0 then '/' + std.join('/', [percentEncode(seg) for seg in path]) else '')
          + query(std.get(u, 'params', {}));

      local walk(current, remaining, buildFn) =
        if std.length(remaining) == 0 then
          if std.type(current) == 'array' then
            std.foldl(function(acc, item) acc + buildFn(item), current, {})
          else buildFn(current)
        else
          local next =
            if std.type(current) == 'object' then std.get(current, remaining[0], null)
            else null;
          if next == null then {}
          else if std.type(next) == 'array' then
            std.foldl(function(acc, item) acc + walk(item, remaining[1:], buildFn), next, {})
          else
            walk(next, remaining[1:], buildFn);

      local itemPath(item, path) =
        std.foldl(
          function(acc, seg) if std.type(acc) == 'object' then std.get(acc, seg, null) else null,
          path,
          item
        );

      local nestValue(labels, index, value) =
        if index == std.length(labels) - 1 then { [labels[index]]: value }
        else { [labels[index]]+: nestValue(labels, index + 1, value) };

      local nestKeys(keySegs, item, value) =
        local labels = [
          if std.objectHas(seg, 'const') then seg.const else std.toString(itemPath(item, seg.path))
          for seg in keySegs
        ];
        nestValue(labels, 0, value);

      local splitPrefix(valueSegs) =
        if std.length(valueSegs) == 0 then { prefix: [], suffix: [] }
        else if std.objectHas(valueSegs[0], 'param') || std.objectHas(valueSegs[0], 'path') then { prefix: [], suffix: valueSegs }
        else
          local rest = splitPrefix(valueSegs[1:]);
          { prefix: [valueSegs[0]] + rest.prefix, suffix: rest.suffix };

      local resolveBase(root, node, prefixSegs) =
        std.foldl(
          function(acc, seg)
            if std.objectHas(seg, 'const') then acc[seg.const]
            else acc[seg.origin](std.toString(node[seg.origin])),
          prefixSegs,
          root
        );

      local resolveKey(spec, item) =
        if std.type(spec) == 'string' then spec
        else
          local raw = itemPath(item, spec.path);
          if std.objectHas(spec, 'transform') then spec.transform(raw) else raw;

      local resolveFromBase(base, item, suffixSegs) =
        std.foldl(
          function(acc, seg)
            if std.objectHas(seg, 'param') then
              acc[resolveKey(seg.param, item)](std.toString(itemPath(item, seg.path)))
            else if std.objectHas(seg, 'const') then
              acc[seg.const]
            else
              acc[resolveKey(seg, item)],
          suffixSegs,
          base
        );

      local resolvable(item, valueSegs) =
        std.all(
          [itemPath(item, seg.path) != null for seg in valueSegs if std.objectHas(seg, 'path')] +
          [
            itemPath(item, seg.param.path) != null
            for seg in valueSegs
            if std.objectHas(seg, 'param') && std.type(seg.param) == 'object'
          ]
        );

      local resolveLiteralSegment(node, item, seg) =
        if std.objectHas(seg, 'const') then seg.const
        else if std.objectHas(seg, 'origin') then std.toString(node[seg.origin])
        else resolveKey(seg, item);

      local resolveLiteralSegments(node, item, segs) =
        std.foldl(function(acc, seg) acc + resolveLiteralSegment(node, item, seg), segs, '');

      local resolveUrl(node, item, literal) =
        local query = std.get(literal, 'query', {});
        url({
          scheme: std.get(literal, 'scheme', null),
          host: resolveLiteralSegments(node, item, std.get(literal, 'host', [])),
          path: [resolveLiteralSegment(node, item, seg) for seg in std.get(literal, 'path', [])],
          params: { [k]: resolveLiteralSegments(node, item, query[k]) for k in std.objectFields(query) },
        });

      local urlSegments(literal) =
        std.get(literal, 'host', []) + std.get(literal, 'path', [])
        + std.flattenArrays([literal.query[k] for k in std.objectFields(std.get(literal, 'query', {}))]);

      local buildLinks(node, specs, root=import 'root') =
        std.foldl(
          function(acc, spec)
            acc + (
              if std.type(spec.value) == 'object' then
                walk(
                  node.data,
                  spec.at,
                  function(item)
                    if resolvable(item, urlSegments(spec.value))
                    then nestKeys(spec.keys, item, resolveUrl(node, item, spec.value))
                    else {}
                )
              else
                local split = splitPrefix(spec.value);
                local base = resolveBase(root, node, split.prefix);
                walk(
                  node.data,
                  spec.at,
                  function(item)
                    if resolvable(item, spec.value)
                    then nestKeys(spec.keys, item, resolveFromBase(base, item, split.suffix))
                    else {}
                )
            ),
          specs,
          {}
        );

      local rowLinkSpec(specs, at) =
        local matches = [spec for spec in specs if spec.at == at];
        if std.length(matches) == 0 then null else matches[0];

      local rowLinkFor(node, specs, at, root=import 'root') =
        local spec = rowLinkSpec(specs, at);
        if spec == null then null
        else
          local split = splitPrefix(spec.value);
          local base = resolveBase(root, node, split.prefix);
          function(item)
            if resolvable(item, spec.value) then resolveFromBase(base, item, split.suffix) else null;

      {
        buildLinks: buildLinks,
        rowLinkFor: rowLinkFor,
        withLinkSpecs: {
          linkSpecs:: [],
          links: buildLinks(self, self.linkSpecs, import 'root'),
        },
      };
    local c = {
      list:
        local style = |||
          @scope (.list) {
            :scope {
              font-family: monospace;
              display: inline-flex;
              flex-direction: column;
              gap: 0.25em;
            }
            a {
              color: var(--primary-color);
              border-radius: 0.5em;
            }
            a:hover {
              text-decoration: none;
            }
            a:focus {
              outline: 2px solid var(--primary-color);
              outline-offset: 2px;
            }
            ul {
              list-style: none;
              margin: 0;
              padding: 0;
            }
            :scope.columns {
              flex-direction: row;
              flex-wrap: wrap;
              align-items: flex-start;
            }
            .list-column {
              display: flex;
              flex-direction: column;
              gap: 0.25em;
            }
          }
        |||;

        local itemList = {
          local c = self,
          items:: error 'ItemList requires items',
          html: {
            element: 'ul',
            children: [
              {
                element: 'li',
                children: [{
                  element: 'a',
                  attributes: { href: item.link } + (
                    if std.get(item, 'external', false)
                    then { target: '_blank', rel: 'noopener noreferrer' }
                    else {}
                  ),
                  children: [item.text],
                }],
              }
              for item in c.items
            ],
          },
        };

        local card = {
          local c = self,
          title:: null,
          items:: error 'Card requires items',
          lines:: std.length(c.items) + (if c.title == null then 0 else 1),
          html: {
            element: 'nav',
            attributes: { class: 'card' },
            children:
              (if c.title == null then [] else [{ element: 'strong', children: [c.title] }])
              + [itemList { items:: c.items }],
          },
        };

        local column = {
          local c = self,
          cards:: error 'Column requires cards',
          html: {
            element: 'div',
            attributes: { class: 'list-column' },
            children: [card.html for card in c.cards],
          },
        };

        local lineCount(cards) = std.foldl(function(acc, card) acc + card.lines, cards, 0);

        local distribute(cards, count) =
          local target = lineCount(cards) / count;
          std.foldl(
            function(columns, card)
              local last = columns[std.length(columns) - 1];
              if std.length(last) > 0 && std.length(columns) < count && lineCount(last) + card.lines / 2 > target
              then columns + [[card]]
              else columns[:std.length(columns) - 1] + [last + [card]],
            cards,
            [[]]
          );

        {
          local c = self,
          items:: error 'List requires items',
          groups:: [],
          columns:: 1,
          style:: '',
          local cards =
            (if std.length(c.items) > 0 then [card { items:: c.items }] else [])
            + [card { title:: group.title, items:: group.items } for group in c.groups],
          html: [
            { element: 'style', children: [style] },
            {
              element: 'aside',
              attributes: { class: if c.columns > 1 then 'list columns' else 'list' } + (if c.style != '' then { style: c.style } else {}),
              children:
                if c.columns > 1 then [column { cards:: cards }.html for cards in distribute(cards, c.columns)]
                else [card.html for card in cards],
            },
          ],
        },
      table:
        local style = |||
          @scope (.table-card) {
            :scope.card {
              padding: 0.25em;
            }
            :scope {
              display: inline-flex;
              flex-direction: column;
              align-items: flex-start;
              gap: 0.5em;
            }
          }
          @scope (.table) {
            :scope {
              border-collapse: separate;
              border-spacing: 0;
              font-family: monospace;
            }
            th {
              color: var(--primary-color);
              font-weight: bold;
              padding: 0.3em 0.4em;
              cursor: pointer;
              user-select: none;
              white-space: nowrap;
            }
            th:hover {
              text-decoration: underline;
            }
            th.sort-asc::after {
              content: ' ↑';
            }
            th.sort-desc::after {
              content: ' ↓';
            }
            td {
              padding: 0;
              border-top: 2px solid transparent;
              border-bottom: 2px solid transparent;
            }
            td:first-child {
              border-left: 2px solid transparent;
            }
            td:last-child {
              border-right: 2px solid transparent;
            }
            td > * {
              display: block;
              box-sizing: border-box;
              height: 100%;
              padding: 0.3em 0.4em;
            }
            td > a {
              text-decoration: none;
              color: var(--on-background-color);
            }
            tbody tr:has(a):hover {
              background-color: var(--container-low-color);
            }
            tbody tr:has(a:focus) td {
              background-color: var(--container-low-color);
              border-color: var(--primary-color);
            }
            tbody tr:has(a:focus) td:first-child {
              border-radius: 0.8em 0 0 0.8em;
            }
            tbody tr:has(a:focus) td:last-child {
              border-radius: 0 0.8em 0.8em 0;
            }
            td > a:focus {
              outline: none;
            }
            td.empty {
              text-align: center;
              opacity: 0.6;
            }
          }
          @scope (.table-pagination) {
            :scope {
              display: flex;
              align-items: stretch;
              width: fit-content;
              border: 1px solid var(--border-color);
              border-radius: 0.5em;
              overflow: hidden;
              background: var(--container-low-color);
              font-family: monospace;
            }
            a, span.disabled {
              display: flex;
              align-items: center;
              justify-content: center;
              line-height: 1;
              width: 2.6rem;
              height: 2.6rem;
              font-size: 1.4em;
              border-right: 1px solid var(--border-color);
              text-decoration: none;
              color: var(--on-background-color);
            }
            a:last-child, span.disabled:last-child {
              border-right: none;
            }
            a:hover {
              background-color: var(--background-color);
            }
            span.disabled {
              opacity: 0.4;
            }
          }
        |||;

        local sortScript = |||
          (function () {
            if (window.__tableSortBound) return;
            window.__tableSortBound = true;

            var observer = null;

            function headers(table) {
              return Array.prototype.slice.call(table.querySelectorAll('thead th'));
            }

            function cellText(row, i) {
              var td = row.children[i];
              return td ? td.textContent.trim() : '';
            }

            function compare(a, b) {
              var na = Number(a);
              var nb = Number(b);
              if (a !== '' && b !== '' && !isNaN(na) && !isNaN(nb)) return na - nb;
              return a.localeCompare(b);
            }

            function firstCol(table) {
              var th = table.querySelector('thead th');
              return th ? th.dataset.col : null;
            }

            function apply(table) {
              var ths = headers(table);
              ths.forEach(function (th) { th.classList.remove('sort-asc', 'sort-desc'); });
              if (ths.length === 0) return;
              var key = window.hashParams.get('sort');
              var desc = window.hashParams.get('dir') === 'desc';
              var i = 0;
              if (key) {
                i = -1;
                ths.forEach(function (th, idx) { if (th.dataset.col === key) i = idx; });
                if (i < 0) { i = 0; desc = false; }
              } else {
                desc = false;
              }
              ths[i].classList.add(desc ? 'sort-desc' : 'sort-asc');
              var tbody = table.querySelector('tbody');
              if (!tbody || tbody.querySelector('td.empty')) return;
              var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
              rows.sort(function (a, b) {
                var r = compare(cellText(a, i), cellText(b, i));
                return desc ? -r : r;
              });
              rows.forEach(function (r) { tbody.appendChild(r); });
            }

            function applyAll() {
              if (observer) observer.disconnect();
              document.querySelectorAll('table.table').forEach(apply);
              if (observer) {
                var target = document.getElementById('node') || document.body;
                if (target) observer.observe(target, { childList: true, subtree: true });
              }
            }

            document.addEventListener('click', function (e) {
              var th = e.target.closest ? e.target.closest('th') : null;
              if (!th || !th.dataset.col) return;
              var table = th.closest('table.table');
              if (!table) return;
              var key = th.dataset.col;
              var first = firstCol(table);
              var curKey = window.hashParams.get('sort') || first;
              var curDesc = window.hashParams.get('dir') === 'desc';
              var nextKey;
              var nextDesc;
              if (curKey !== key) {
                nextKey = key;
                nextDesc = false;
              } else if (!curDesc) {
                nextKey = key;
                nextDesc = true;
              } else {
                nextKey = first;
                nextDesc = false;
              }
              if (nextKey === first && !nextDesc) {
                window.hashParams.remove('sort');
                window.hashParams.remove('dir');
              } else {
                window.hashParams.set('sort', nextKey);
                if (nextDesc) window.hashParams.set('dir', 'desc');
                else window.hashParams.remove('dir');
              }
              applyAll();
            });

            function init() {
              observer = new MutationObserver(applyAll);
              applyAll();
            }

            if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
            else init();
          })();
        |||;

        local slug(label) = std.asciiLower(std.strReplace(std.toString(label), ' ', '-'));

        local cellText(item, col) =
          local val = std.get(item, col.key, null);
          if val == null then '' else std.toString(val);

        local rowHref(target) =
          if std.type(target) == 'object' && std.objectHasAll(target, '_queryPath')
          then target._queryPath
          else null;

        local cell = {
          local c = self,
          item:: error 'Cell requires item',
          col:: error 'Cell requires col',
          href:: null,
          first:: true,
          local text = cellText(c.item, c.col),
          html:
            if c.href == null then
              { element: 'span', children: [text] }
            else
              { element: 'a', attributes: { href: c.href } + (if c.first then {} else { tabindex: '-1' }), children: [text] },
        };

        local emptyRow = {
          local c = self,
          columnCount:: error 'EmptyRow requires columnCount',
          html: {
            element: 'tr',
            children: [{
              element: 'td',
              attributes: { class: 'empty', colspan: std.max(1, c.columnCount) },
              children: [{ element: 'span', children: ['No items'] }],
            }],
          },
        };

        local navLink = {
          local c = self,
          icon:: error 'NavLink requires icon',
          title:: error 'NavLink requires title',
          href:: null,
          html:
            if c.href == null then
              { element: 'span', attributes: { class: 'disabled', title: c.title }, children: [c.icon] }
            else
              { element: 'a', attributes: { href: c.href, title: c.title }, children: [c.icon] },
        };

        local paginationDirections = [
          { key: 'first', icon: '«', title: 'First page' },
          { key: 'prev', icon: '‹', title: 'Previous page' },
          { key: 'next', icon: '›', title: 'Next page' },
          { key: 'last', icon: '»', title: 'Last page' },
        ];

        local paginationNav = {
          local c = self,
          pagination:: null,
          local links = if c.pagination == null then {} else c.pagination,
          visible:: std.length(std.objectFields(links)) > 0,
          html: {
            element: 'div',
            attributes: { class: 'table-pagination' },
            children: [
              local target = std.get(links, dir.key, null);
              (navLink {
                 icon:: dir.icon,
                 title:: dir.title,
                 href:: if target == null then null else target._queryPath,
               }).html
              for dir in paginationDirections
            ],
          },
        };

        {
          local c = self,
          items:: error 'Table requires items',
          columns:: [],
          rowLinks:: [],
          pagination:: null,
          local rows = if std.isArray(c.items) then c.items else [],
          local nav = paginationNav { pagination:: c.pagination },
          html: [
            { element: 'style', children: [style] },
            {
              element: 'div',
              attributes: { class: 'card table-card' },
              children: [
                {
                  element: 'table',
                  attributes: { class: 'table' },
                  children: [
                    {
                      element: 'thead',
                      children: [{
                        element: 'tr',
                        children: [
                          { element: 'th', attributes: { 'data-col': slug(col.label) }, children: [col.label] }
                          for col in c.columns
                        ],
                      }],
                    },
                    {
                      element: 'tbody',
                      children:
                        if std.length(rows) == 0 then [emptyRow { columnCount:: std.length(c.columns) }]
                        else [
                          local item = rows[r];
                          local href = rowHref(if r < std.length(c.rowLinks) then c.rowLinks[r] else null);
                          {
                            element: 'tr',
                            children: [
                              { element: 'td', children: [cell { item:: item, col:: c.columns[i], href:: href, first:: i == 0 }] }
                              for i in std.range(0, std.length(c.columns) - 1)
                            ],
                          }
                          for r in std.range(0, std.length(rows) - 1)
                        ],
                    },
                  ],
                },
              ] + (if nav.visible then [nav.html] else []),
            },
            { element: 'script', children: [{ html: sortScript }] },
          ],
        },
      tree:
        local style = |||
          @scope (.tree) {
            :scope {
              font-family: monospace;
              display: block;
              overflow-x: auto;
              line-height: 1.3;
            }
            ul {
              list-style: none;
              margin: 0;
              padding: 0;
            }
            li {
              white-space: pre;
            }
            a {
              color: var(--primary-color);
            }
            a:hover {
              text-decoration: none;
            }
            .prefix {
              opacity: 0.4;
              user-select: none;
            }
            .detail {
              opacity: 0.55;
              margin-left: 0.75em;
              font-size: 0.85em;
            }
          }
        |||;

        local link = {
          local c = self,
          node:: error 'Link requires a node',
          html: {
            element: 'a',
            attributes: { href: c.node.link },
            children: [c.node.text],
          },
        };

        local rowsOf(nodes, indent, root) = std.flatMap(
          function(i)
            local node = nodes[i];
            local last = i == std.length(nodes) - 1;
            [{
              node: node,
              prefix: if root then '' else indent + (if last then '╰─ ' else '├─ '),
            }] + rowsOf(
              std.get(node, 'children', []),
              if root then '' else indent + (if last then '   ' else '│  '),
              false,
            ),
          std.range(0, std.length(nodes) - 1)
        );

        local row = {
          local c = self,
          prefix:: error 'Row requires a prefix',
          item:: error 'Row requires an item',
          html: {
            element: 'li',
            children: [
              { element: 'span', attributes: { class: 'prefix' }, children: [c.prefix] },
              c.item,
            ],
          },
        };

        local rowList = {
          local c = self,
          rows:: error 'RowList requires rows',
          item:: error 'RowList requires an item',
          html: {
            element: 'ul',
            children: [
              row { prefix:: r.prefix, item:: c.item { node:: r.node } }
              for r in c.rows
            ],
          },
        };

        {
          local c = self,
          nodes:: error 'Tree requires nodes',
          item:: link,
          html: [
            { element: 'style', children: [style] },
            {
              element: 'section',
              attributes: { class: 'tree card' },
              children: [rowList { rows:: rowsOf(c.nodes, '', true), item:: c.item }],
            },
          ],
        },
      yaml:
        local yaml = {
          local c = self,

          indent(depth)::
            std.join('', std.makeArray(depth * 2, function(_) ' ')),

          scalar(v)::
            if std.type(v) == 'null' then 'null'
            else if std.type(v) == 'boolean' then (if v then 'true' else 'false')
            else if std.type(v) == 'object' then '{}'
            else if std.type(v) == 'array' then '[]'
            else '%s' % v,

          at(links, k)::
            if std.isObject(links) && std.isString(k) then std.get(links, k, null)
            else if std.isArray(links) && std.isNumber(k) && k < std.length(links) then links[k]
            else null,

          href(target)::
            if std.isString(target) then target
            else if std.isObject(target) && std.objectHasAll(target, '_queryPath') then target._queryPath
            else null,

          link(target, children, style)::
            local href = c.href(target);
            if href == null then { element: 'span', attributes: { style: style }, children: children }
            else { element: 'a', attributes: { href: href, style: style }, children: children },

          key(k, target)::
            c.link(target, [k], 'color: var(--primary-color); font-weight: bold'),

          value(v, target)::
            if c.href(target) == null then c.scalar(v)
            else c.link(target, [c.scalar(v)], 'color: inherit'),

          isMultiline(v)::
            std.isString(v) && std.length(std.findSubstr('\n', v)) > 0,

          leaf:: {
            local l = self,
            prefix:: [],
            data:: error 'leaf requires data',
            target:: null,
            depth:: 0,
            html:
              if !c.isMultiline(l.data) then
                [{ element: 'div', children: l.prefix + [c.value(l.data, l.target)] }]
              else
                local trailing = std.length(l.data) - std.length(std.rstripChars(l.data, '\n'));
                local indicator = if trailing == 0 then '|-' else if trailing == 1 then '|' else '|+';
                local lines = std.split(if trailing > 0 then std.substr(l.data, 0, std.length(l.data) - 1) else l.data, '\n');
                [{ element: 'div', children: l.prefix + [indicator] }] + [
                  { element: 'div', children: [c.indent(l.depth + 1), c.value(line, l.target)] }
                  for line in lines
                ],
          },

          isLeaf(value)::
            !((std.type(value) == 'object' || std.type(value) == 'array') && std.length(value) > 0),

          mapLeaves(value, fn, path=[])::
            if c.isLeaf(value) then fn(path, value)
            else if std.isObject(value) then { [k]: c.mapLeaves(value[k], fn, path + [k]) for k in std.objectFields(value) }
            else [c.mapLeaves(value[i], fn, path + [i]) for i in std.range(0, std.length(value) - 1)],

          row(key, value, links, depth, bullet)::
            if !c.isLeaf(value) then
              [{ element: 'div', children: [
                c.indent(depth),
                bullet,
                c.key(key, null),
                ':',
              ] }] + c.children(value, links, depth + 1)
            else
              (c.leaf {
                 prefix:: [
                   c.indent(depth),
                   bullet,
                   c.key(key, c.at(links, 'key')),
                   ': ',
                 ],
                 data:: value,
                 target:: c.at(links, 'value'),
                 depth:: depth,
               }).html,

          children(value, links, depth)::
            if std.type(value) == 'object' then
              std.flatMap(
                function(kv) c.row(kv.key, kv.value, c.at(links, kv.key), depth, ''),
                std.objectKeysValues(value)
              )
            else
              std.flatMap(
                function(i)
                  local item = value[i];
                  local itemLinks = c.at(links, i);
                  if std.type(item) == 'object' then
                    local kvs = std.objectKeysValues(item);
                    c.row(kvs[0].key, kvs[0].value, c.at(itemLinks, kvs[0].key), depth, '- ') +
                    std.flatMap(function(kv) c.row(kv.key, kv.value, c.at(itemLinks, kv.key), depth, '  '), kvs[1:])
                  else
                    (c.leaf {
                       prefix:: [c.indent(depth), '- '],
                       data:: item,
                       target:: c.at(itemLinks, 'value'),
                       depth:: depth,
                     }).html,
                std.range(0, std.length(value) - 1)
              ),
        };

        local style = |||
          .yaml {
            white-space: pre-wrap;
            word-break: break-all;
          }
          .yaml a {
            text-decoration: none;
          }
          .yaml a:hover {
            text-decoration: underline;
          }
        |||;

        {
          local c = self,
          data:: error 'Yaml requires data',
          embeddedLinks:: null,
          mapLeaves(value, fn):: yaml.mapLeaves(value, fn),
          html: [
            { element: 'style', children: [style] },
            { element: 'pre', attributes: { class: 'yaml card' }, children: yaml.children(c.data, c.embeddedLinks, 0) },
          ],
        },
      page:
        local pageStyle = |||
          * {
            margin: 0;
            padding: 0;
          }
          :root {
            color-scheme: light dark;
            --primary-color: light-dark(#0451a5, #569cd6);
            --error-color: light-dark(#c62828, #f48771);
            --on-background-color: light-dark(
              color-mix(in srgb, var(--primary-color) 12%, black),
              color-mix(in srgb, var(--primary-color) 12%, white)
            );
            --background-color: light-dark(
              color-mix(in srgb, var(--primary-color) 3%, white),
              color-mix(in srgb, var(--primary-color) 8%, black)
            );
            --container-low-color: light-dark(
              color-mix(in srgb, var(--primary-color) 8%, white),
              color-mix(in srgb, var(--primary-color) 15%, black)
            );
            --border-color: light-dark(
              color-mix(in srgb, var(--primary-color) 20%, white),
              color-mix(in srgb, var(--primary-color) 30%, black)
            );
          }
          body {
            background-color: var(--background-color);
            color: var(--on-background-color);
            padding: 0.5em;
          }
          .card {
            display: inline-block;
            border: 1px solid var(--border-color);
            border-radius: 0.5em;
            padding: 0.75em;
          }
          .deck {
            display: contents;
          }
          .deck:has(.breadcrumbs),
          .deck:has(.card ~ .card),
          .deck:has(.list):has(.yaml) {
            display: inline-flex;
            flex-direction: column;
            align-items: flex-start;
            gap: 0.25em;
            border: 1px solid var(--border-color);
            border-radius: 0.5em;
            padding: 0.25em;
          }
        |||;

        local hashScript = |||
          (function () {
            if (window.hashParams) return;

            function read() {
              return new URLSearchParams(window.location.hash.slice(1));
            }

            function serialize(p) {
              var parts = [];
              p.forEach(function (value, key) {
                parts.push(value === '' ? encodeURIComponent(key) : encodeURIComponent(key) + '=' + encodeURIComponent(value));
              });
              return parts.join('&');
            }

            function write(p) {
              var s = serialize(p);
              var base = window.location.pathname + window.location.search;
              history.replaceState(null, '', s ? base + '#' + s : base);
            }

            window.hashParams = {
              get: function (key) {
                return read().get(key);
              },
              has: function (key) {
                return read().has(key);
              },
              set: function (key, value) {
                var p = read();
                if (value === null || value === undefined) p.delete(key);
                else p.set(key, value);
                write(p);
              },
              remove: function (key) {
                this.set(key, null);
              },
            };
          })();
        |||;
        local navScript = |||
          (function () {
            if (typeof HTMLElement === 'undefined') return;

            var GROUPS = [
              { key: 'breadcrumbs', title: 'breadcrumbs' },
              { key: 'links', title: 'links' },
              { key: 'table', title: 'table' },
            ];

            function scrapeItems() {
              var items = [];
              document.querySelectorAll('.breadcrumbs a[href]').forEach(function (a) {
                var text = a.textContent.trim();
                if (text) items.push({ text: text, link: a.href, group: 'breadcrumbs' });
              });
              document.querySelectorAll('.list a[href]').forEach(function (a) {
                var text = a.textContent.trim();
                if (text) items.push({ text: text, link: a.href, group: 'links' });
              });
              document.querySelectorAll('.table tbody tr').forEach(function (tr) {
                var a = tr.querySelector('a[href]');
                if (!a) return;
                var text = Array.prototype.map
                  .call(tr.querySelectorAll('td'), function (td) { return td.textContent.trim(); })
                  .filter(Boolean)
                  .join('  ');
                if (text) items.push({ text: text, link: a.href, group: 'table' });
              });
              return items;
            }

            function isBoundary(ch) {
              return ch === undefined || /[\s_\/\-.]/.test(ch);
            }

            function fuzzyScore(query, text) {
              if (!query) return 0;
              var q = query.toLowerCase();
              var t = text.toLowerCase();
              var score = 0;
              var qi = 0;
              var prev = -2;
              for (var ti = 0; ti < t.length && qi < q.length; ti++) {
                if (t[ti] === q[qi]) {
                  score += ti === prev + 1 ? 3 : 1;
                  if (isBoundary(t[ti - 1])) score += 2;
                  prev = ti;
                  qi++;
                }
              }
              return qi === q.length ? score : -1;
            }

            function rank(query, items) {
              if (!query) return items.slice();
              var scored = [];
              for (var i = 0; i < items.length; i++) {
                var s = fuzzyScore(query, items[i].text);
                if (s >= 0) scored.push({ item: items[i], score: s, index: i });
              }
              scored.sort(function (a, b) { return b.score - a.score || a.index - b.index; });
              return scored.map(function (e) { return e.item; });
            }

            var template = `
              <style>
                :host { font-family: monospace; }
                dialog {
                  border: 1px solid var(--border-color);
                  border-radius: 0.5em;
                  background: var(--background-color);
                  color: var(--on-background-color);
                  padding: 0;
                  width: min(90vw, 42em);
                  margin-top: 12vh;
                  box-shadow: 0 0.5em 2em rgba(0, 0, 0, 0.35);
                }
                dialog::backdrop { background: rgba(0, 0, 0, 0.4); }
                input {
                  width: 100%;
                  box-sizing: border-box;
                  font: inherit;
                  padding: 0.6em 0.75em;
                  border: none;
                  border-bottom: 1px solid var(--border-color);
                  background: transparent;
                  color: inherit;
                  outline: none;
                }
                ul { list-style: none; margin: 0; padding: 0.25em; max-height: 50vh; overflow-y: auto; }
                li {
                  padding: 0.35em 0.5em;
                  border-radius: 0.25em;
                  cursor: pointer;
                  white-space: nowrap;
                  overflow: hidden;
                  text-overflow: ellipsis;
                }
                li.selected { background: var(--container-low-color); }
                li.empty { opacity: 0.6; cursor: default; }
                li.group {
                  cursor: default;
                  padding: 0.5em 0.5em 0.15em;
                  opacity: 0.5;
                  font-size: 0.85em;
                  text-transform: uppercase;
                  letter-spacing: 0.05em;
                }
                li.group:first-child { padding-top: 0.15em; }
              </style>
              <dialog part="modal">
                <input type="text" autocomplete="off" spellcheck="false" placeholder="Jump to…" />
                <ul></ul>
              </dialog>
            `;

            class QuickNav extends HTMLElement {
              connectedCallback() {
                if (!this.shadowRoot) this.attachShadow({ mode: 'open' });
                this.shadowRoot.innerHTML = template;
                this.modal = this.shadowRoot.querySelector('dialog');
                this.input = this.shadowRoot.querySelector('input');
                this.results = this.shadowRoot.querySelector('ul');
                this.items = [];
                this.matches = [];
                this.itemEls = [];
                this.selected = 0;

                this.input.addEventListener('input', function () {
                  this.selected = 0;
                  this.render();
                }.bind(this));

                this.modal.addEventListener('keydown', this.onKeydown.bind(this));
                this.modal.addEventListener('click', function (e) {
                  if (e.target === this.modal) this.closeModal();
                }.bind(this));
                this.modal.addEventListener('close', function () {
                  window.hashParams.remove('quick-nav');
                });

                if (!window.__quickNavBound) {
                  window.__quickNavBound = true;
                  document.addEventListener('keydown', function (e) {
                    if (e.key !== '/' || e.metaKey || e.ctrlKey || e.altKey) return;
                    var el = document.activeElement;
                    while (el && el.shadowRoot && el.shadowRoot.activeElement) el = el.shadowRoot.activeElement;
                    var tag = el && el.tagName;
                    if (tag === 'INPUT' || tag === 'TEXTAREA' || (el && el.isContentEditable)) return;
                    var nav = document.querySelector('quick-nav');
                    if (nav && !nav.isOpen()) {
                      e.preventDefault();
                      nav.openModal();
                    }
                  }, true);
                }

                if (window.hashParams.has('quick-nav')) {
                  requestAnimationFrame(function () { this.openModal(); }.bind(this));
                }
              }

              isOpen() {
                return !!(this.modal && this.modal.open);
              }

              openModal() {
                this.items = scrapeItems();
                this.input.value = '';
                this.selected = 0;
                this.render();
                this.modal.showModal();
                this.input.focus();
                window.hashParams.set('quick-nav', '');
              }

              closeModal() {
                if (this.modal.open) this.modal.close();
              }

              onKeydown(e) {
                if (e.key === 'ArrowDown') {
                  e.preventDefault();
                  this.move(1);
                } else if (e.key === 'ArrowUp') {
                  e.preventDefault();
                  this.move(-1);
                } else if (e.key === 'Enter') {
                  e.preventDefault();
                  this.choose(e.shiftKey);
                }
              }

              move(delta) {
                if (this.matches.length === 0) return;
                this.selected = (this.selected + delta + this.matches.length) % this.matches.length;
                this.highlight();
              }

              choose(keepOpen) {
                var match = this.matches[this.selected];
                if (!match) return;
                window.hashParams.remove('quick-nav');
                var url = new URL(match.link, window.location.href);
                url.hash = keepOpen ? 'quick-nav' : '';
                window.location.href = url.toString();
              }

              highlight() {
                for (var i = 0; i < this.itemEls.length; i++) {
                  var on = i === this.selected;
                  this.itemEls[i].classList.toggle('selected', on);
                  if (on) this.itemEls[i].scrollIntoView({ block: 'nearest' });
                }
              }

              render() {
                var self = this;
                var ranked = rank(this.input.value.trim(), this.items);
                this.results.innerHTML = '';
                this.matches = [];
                this.itemEls = [];

                GROUPS.forEach(function (group) {
                  var groupItems = ranked.filter(function (m) { return m.group === group.key; });
                  if (groupItems.length === 0) return;
                  var header = document.createElement('li');
                  header.className = 'group';
                  header.textContent = group.title;
                  self.results.appendChild(header);
                  groupItems.forEach(function (match) {
                    var index = self.matches.length;
                    self.matches.push(match);
                    var li = document.createElement('li');
                    li.textContent = match.text;
                    if (index === self.selected) li.classList.add('selected');
                    li.addEventListener('mousemove', function () {
                      self.selected = index;
                      self.highlight();
                    });
                    li.addEventListener('click', function () {
                      self.selected = index;
                      self.choose();
                    });
                    self.results.appendChild(li);
                    self.itemEls.push(li);
                  });
                });

                if (this.matches.length === 0) {
                  var empty = document.createElement('li');
                  empty.className = 'empty';
                  empty.textContent = 'No matches';
                  this.results.appendChild(empty);
                }
              }
            }

            if (!customElements.get('quick-nav')) customElements.define('quick-nav', QuickNav);
          })();
        |||;

        {
          local c = self,
          fragment:: error 'HtmlPage requires a fragment',
          breadcrumbs:: { html: [] },
          html: [
            { doctype: 'html' },
            {
              element: 'html',
              children: [
                {
                  element: 'head',
                  children: [
                    { element: 'style', children: [pageStyle] },
                    { element: 'script', children: [{ html: hashScript }] },
                  ],
                },
                {
                  element: 'body',
                  children: [
                    { element: 'div', attributes: { class: 'deck' }, children: [c.breadcrumbs, c.fragment] },
                    { element: 'quick-nav' },
                    { element: 'script', children: [{ html: navScript }] },
                  ],
                },
              ],
            },
          ],
        },
      resource:
        local list =
          local style = |||
            @scope (.list) {
              :scope {
                font-family: monospace;
                display: inline-flex;
                flex-direction: column;
                gap: 0.25em;
              }
              a {
                color: var(--primary-color);
                border-radius: 0.5em;
              }
              a:hover {
                text-decoration: none;
              }
              a:focus {
                outline: 2px solid var(--primary-color);
                outline-offset: 2px;
              }
              ul {
                list-style: none;
                margin: 0;
                padding: 0;
              }
              :scope.columns {
                flex-direction: row;
                flex-wrap: wrap;
                align-items: flex-start;
              }
              .list-column {
                display: flex;
                flex-direction: column;
                gap: 0.25em;
              }
            }
          |||;

          local itemList = {
            local c = self,
            items:: error 'ItemList requires items',
            html: {
              element: 'ul',
              children: [
                {
                  element: 'li',
                  children: [{
                    element: 'a',
                    attributes: { href: item.link } + (
                      if std.get(item, 'external', false)
                      then { target: '_blank', rel: 'noopener noreferrer' }
                      else {}
                    ),
                    children: [item.text],
                  }],
                }
                for item in c.items
              ],
            },
          };

          local card = {
            local c = self,
            title:: null,
            items:: error 'Card requires items',
            lines:: std.length(c.items) + (if c.title == null then 0 else 1),
            html: {
              element: 'nav',
              attributes: { class: 'card' },
              children:
                (if c.title == null then [] else [{ element: 'strong', children: [c.title] }])
                + [itemList { items:: c.items }],
            },
          };

          local column = {
            local c = self,
            cards:: error 'Column requires cards',
            html: {
              element: 'div',
              attributes: { class: 'list-column' },
              children: [card.html for card in c.cards],
            },
          };

          local lineCount(cards) = std.foldl(function(acc, card) acc + card.lines, cards, 0);

          local distribute(cards, count) =
            local target = lineCount(cards) / count;
            std.foldl(
              function(columns, card)
                local last = columns[std.length(columns) - 1];
                if std.length(last) > 0 && std.length(columns) < count && lineCount(last) + card.lines / 2 > target
                then columns + [[card]]
                else columns[:std.length(columns) - 1] + [last + [card]],
              cards,
              [[]]
            );

          {
            local c = self,
            items:: error 'List requires items',
            groups:: [],
            columns:: 1,
            style:: '',
            local cards =
              (if std.length(c.items) > 0 then [card { items:: c.items }] else [])
              + [card { title:: group.title, items:: group.items } for group in c.groups],
            html: [
              { element: 'style', children: [style] },
              {
                element: 'aside',
                attributes: { class: if c.columns > 1 then 'list columns' else 'list' } + (if c.style != '' then { style: c.style } else {}),
                children:
                  if c.columns > 1 then [column { cards:: cards }.html for cards in distribute(cards, c.columns)]
                  else [card.html for card in cards],
              },
            ],
          };
        local yaml =
          local yaml = {
            local c = self,

            indent(depth)::
              std.join('', std.makeArray(depth * 2, function(_) ' ')),

            scalar(v)::
              if std.type(v) == 'null' then 'null'
              else if std.type(v) == 'boolean' then (if v then 'true' else 'false')
              else if std.type(v) == 'object' then '{}'
              else if std.type(v) == 'array' then '[]'
              else '%s' % v,

            at(links, k)::
              if std.isObject(links) && std.isString(k) then std.get(links, k, null)
              else if std.isArray(links) && std.isNumber(k) && k < std.length(links) then links[k]
              else null,

            href(target)::
              if std.isString(target) then target
              else if std.isObject(target) && std.objectHasAll(target, '_queryPath') then target._queryPath
              else null,

            link(target, children, style)::
              local href = c.href(target);
              if href == null then { element: 'span', attributes: { style: style }, children: children }
              else { element: 'a', attributes: { href: href, style: style }, children: children },

            key(k, target)::
              c.link(target, [k], 'color: var(--primary-color); font-weight: bold'),

            value(v, target)::
              if c.href(target) == null then c.scalar(v)
              else c.link(target, [c.scalar(v)], 'color: inherit'),

            isMultiline(v)::
              std.isString(v) && std.length(std.findSubstr('\n', v)) > 0,

            leaf:: {
              local l = self,
              prefix:: [],
              data:: error 'leaf requires data',
              target:: null,
              depth:: 0,
              html:
                if !c.isMultiline(l.data) then
                  [{ element: 'div', children: l.prefix + [c.value(l.data, l.target)] }]
                else
                  local trailing = std.length(l.data) - std.length(std.rstripChars(l.data, '\n'));
                  local indicator = if trailing == 0 then '|-' else if trailing == 1 then '|' else '|+';
                  local lines = std.split(if trailing > 0 then std.substr(l.data, 0, std.length(l.data) - 1) else l.data, '\n');
                  [{ element: 'div', children: l.prefix + [indicator] }] + [
                    { element: 'div', children: [c.indent(l.depth + 1), c.value(line, l.target)] }
                    for line in lines
                  ],
            },

            isLeaf(value)::
              !((std.type(value) == 'object' || std.type(value) == 'array') && std.length(value) > 0),

            mapLeaves(value, fn, path=[])::
              if c.isLeaf(value) then fn(path, value)
              else if std.isObject(value) then { [k]: c.mapLeaves(value[k], fn, path + [k]) for k in std.objectFields(value) }
              else [c.mapLeaves(value[i], fn, path + [i]) for i in std.range(0, std.length(value) - 1)],

            row(key, value, links, depth, bullet)::
              if !c.isLeaf(value) then
                [{ element: 'div', children: [
                  c.indent(depth),
                  bullet,
                  c.key(key, null),
                  ':',
                ] }] + c.children(value, links, depth + 1)
              else
                (c.leaf {
                   prefix:: [
                     c.indent(depth),
                     bullet,
                     c.key(key, c.at(links, 'key')),
                     ': ',
                   ],
                   data:: value,
                   target:: c.at(links, 'value'),
                   depth:: depth,
                 }).html,

            children(value, links, depth)::
              if std.type(value) == 'object' then
                std.flatMap(
                  function(kv) c.row(kv.key, kv.value, c.at(links, kv.key), depth, ''),
                  std.objectKeysValues(value)
                )
              else
                std.flatMap(
                  function(i)
                    local item = value[i];
                    local itemLinks = c.at(links, i);
                    if std.type(item) == 'object' then
                      local kvs = std.objectKeysValues(item);
                      c.row(kvs[0].key, kvs[0].value, c.at(itemLinks, kvs[0].key), depth, '- ') +
                      std.flatMap(function(kv) c.row(kv.key, kv.value, c.at(itemLinks, kv.key), depth, '  '), kvs[1:])
                    else
                      (c.leaf {
                         prefix:: [c.indent(depth), '- '],
                         data:: item,
                         target:: c.at(itemLinks, 'value'),
                         depth:: depth,
                       }).html,
                  std.range(0, std.length(value) - 1)
                ),
          };

          local style = |||
            .yaml {
              white-space: pre-wrap;
              word-break: break-all;
            }
            .yaml a {
              text-decoration: none;
            }
            .yaml a:hover {
              text-decoration: underline;
            }
          |||;

          {
            local c = self,
            data:: error 'Yaml requires data',
            embeddedLinks:: null,
            mapLeaves(value, fn):: yaml.mapLeaves(value, fn),
            html: [
              { element: 'style', children: [style] },
              { element: 'pre', attributes: { class: 'yaml card' }, children: yaml.children(c.data, c.embeddedLinks, 0) },
            ],
          };

        local style = |||
          .resource {
            display: flex;
            flex-wrap: wrap;
            align-items: flex-start;
            gap: 0.25em;
          }
          .resource > .yaml,
          .resource > .tree {
            flex: 1 1 0;
            min-width: 0;
          }
          .resource.stacked {
            flex-direction: column;
            flex-wrap: nowrap;
          }
          .resource.stacked > .yaml,
          .resource.stacked > .tree {
            flex: none;
          }
        |||;

        {
          local c = self,
          data:: error 'Resource requires data',
          content:: yaml { data:: c.data },
          items:: [],
          groups:: [],
          columns:: 1,
          stacked:: false,
          local links =
            if std.length(c.items) > 0 || std.length(c.groups) > 0 then
              [list { items:: c.items, groups:: c.groups, columns:: c.columns, style:: ' min-width: 8em;' }]
            else [],
          html: [
            { element: 'style', children: [style] },
            {
              element: 'div',
              attributes: { class: if c.stacked then 'resource stacked' else 'resource' },
              children: if c.stacked then [c.content] + links else links + [c.content],
            },
          ],
        },
      breadcrumbs:
        local isVar(seg) = std.length(seg) > 0 && seg[0] == '$';
        local varName(seg) = std.substr(seg, 1, std.length(seg) - 1);

        local style = |||
          @scope (.breadcrumbs) {
            :scope {
              font-family: monospace;
              display: flex;
              flex-wrap: wrap;
              align-items: center;
              gap: 0.4em;
              width: fit-content;
              border: 1px solid var(--border-color);
              border-radius: 0.5em;
              padding: 0.5em 0.75em;
            }
            a {
              color: var(--primary-color);
              text-decoration: none;
              border-radius: 0.5em;
            }
            a:hover {
              text-decoration: underline;
            }
            a:focus {
              outline: 2px solid var(--primary-color);
              outline-offset: 2px;
            }
            .key {
              opacity: 0.55;
            }
            .sep {
              opacity: 0.4;
            }
            .current {
              color: var(--on-background-color);
            }
          }
        |||;

        local crumbInner = {
          local c = self,
          name:: null,
          value:: error 'crumbInner requires value',
          html:
            if c.name == null then [c.value]
            else [{ element: 'span', attributes: { class: 'key' }, children: [c.name + '/'] }, c.value],
        };

        {
          local c = self,
          pathTemplate:: [],
          node:: {},
          local crumbs =
            std.foldl(
              function(acc, seg)
                local entry =
                  if isVar(seg) then
                    local v = varName(seg);
                    local val = std.toString(std.get(c.node, v, ''));
                    { url: acc.url + '/' + v + '/' + val, name: v, value: val }
                  else
                    { url: acc.url + '/' + seg, name: null, value: seg };
                {
                  url: entry.url,
                  crumbs: acc.crumbs + [{ name: entry.name, value: entry.value, queryPath: entry.url }],
                },
              c.pathTemplate,
              { url: '/root', crumbs: [{ name: null, value: 'root', queryPath: '/root' }] }
            ).crumbs,
          html:
            if std.length(c.pathTemplate) == 0 then []
            else [
              { element: 'style', children: [style] },
              {
                element: 'nav',
                attributes: { class: 'breadcrumbs' },
                children: std.flattenArrays([
                  (if i > 0 then [{ element: 'span', attributes: { class: 'sep' }, children: ['›'] }] else []) +
                  [
                    if i == std.length(crumbs) - 1
                    then { element: 'span', attributes: { class: 'current' }, children: [crumbInner { name:: crumbs[i].name, value:: crumbs[i].value }] }
                    else { element: 'a', attributes: { href: crumbs[i].queryPath }, children: [crumbInner { name:: crumbs[i].name, value:: crumbs[i].value }] },
                  ]
                  for i in std.range(0, std.length(crumbs) - 1)
                ]),
              },
            ],
        },
      action:
        local script = |||
          function isDirty(controls) {
            return Array.prototype.some.call(controls, function (control) {
              if (control.options) {
                const defaultIndex = Array.prototype.findIndex.call(control.options, function (option) {
                  return option.defaultSelected;
                });
                return control.selectedIndex !== Math.max(defaultIndex, 0);
              }
              return control.value !== control.defaultValue;
            });
          }

          if (typeof HTMLElement !== 'undefined') {
            class ActionCard extends HTMLElement {
              connectedCallback() {
                this.update = this.update.bind(this);
                this.addEventListener('input', this.update);
                this.addEventListener('change', this.update);
                window.addEventListener('pageshow', this.update);
                this.update();
              }

              disconnectedCallback() {
                window.removeEventListener('pageshow', this.update);
              }

              update() {
                const apply = this.querySelector('form.apply button');
                if (!apply) return;
                apply.disabled = isDirty(this.querySelectorAll('form.params input, form.params select'));
              }
            }

            if (!customElements.get('action-card')) customElements.define('action-card', ActionCard);
          }

          if (typeof module !== 'undefined' && module.exports) {
            module.exports = { isDirty };
          }
        |||;

        local style = |||
          @scope (.action) {
            :scope {
              font-family: monospace;
              display: inline-flex;
              flex-direction: column;
              align-items: flex-start;
              gap: 0.75em;
              padding: 0.5em;
            }
            p {
              margin: 0;
            }
            form {
              margin: 0;
            }
            form.params {
              display: flex;
              flex-direction: column;
              gap: 0.5em;
            }
            label {
              display: flex;
              align-items: baseline;
              gap: 0.75em;
            }
            input, select {
              font-family: inherit;
              font-size: inherit;
              color: var(--on-background-color);
              background-color: var(--container-low-color);
              border: 1px solid var(--border-color);
              border-radius: 0.5em;
              padding: 0.3em 0.6em;
            }
            input:focus, select:focus {
              outline: 2px solid var(--primary-color);
              outline-offset: 2px;
            }
            .issue {
              color: var(--error-color);
            }
            .issue.hint {
              color: inherit;
              opacity: 0.6;
            }
            .buttons {
              display: flex;
              gap: 0.5em;
              align-self: flex-end;
            }
            button {
              font-family: inherit;
              font-size: inherit;
              color: var(--on-background-color);
              background-color: var(--container-low-color);
              border: 1px solid var(--border-color);
              border-radius: 0.5em;
              padding: 0.4em 1em;
              cursor: pointer;
            }
            button:hover {
              color: var(--primary-color);
              border-color: var(--primary-color);
            }
            button:focus {
              outline: 2px solid var(--primary-color);
              outline-offset: 2px;
            }
            button:disabled {
              opacity: 0.4;
              cursor: not-allowed;
            }
            button:disabled:hover {
              color: var(--on-background-color);
              border-color: var(--border-color);
            }
          }
        |||;

        local paramsFormId = 'action-params';

        local issue = {
          local c = self,
          message:: error 'issue requires a message',
          hint:: false,
          html: {
            element: 'p',
            attributes: { class: if c.hint then 'issue hint' else 'issue' },
            children: [c.message],
          },
        };

        local numberControl = {
          local c = self,
          name:: error 'numberControl requires a name',
          value:: null,
          html: {
            element: 'input',
            attributes: { type: 'number', step: 'any', name: c.name, value: if c.value == null then null else std.toString(c.value) },
          },
        };

        local textControl = {
          local c = self,
          name:: error 'textControl requires a name',
          value:: null,
          html: {
            element: 'input',
            attributes: { type: 'text', name: c.name, value: c.value },
          },
        };

        local booleanOption = {
          local c = self,
          value:: error 'booleanOption requires a value',
          selected:: false,
          html: {
            element: 'option',
            attributes: { value: c.value, selected: c.selected },
            children: [c.value],
          },
        };

        local booleanControl = {
          local c = self,
          name:: error 'booleanControl requires a name',
          value:: null,
          local current = if c.value == null then '' else std.toString(c.value),
          html: {
            element: 'select',
            attributes: { name: c.name },
            children: [
              booleanOption { value:: v, selected:: v == current }
              for v in ['', 'true', 'false']
            ],
          },
        };

        local hiddenControl = {
          local c = self,
          name:: error 'hiddenControl requires a name',
          value:: null,
          html:
            if c.value == null then []
            else [{
              element: 'input',
              attributes: { type: 'hidden', name: c.name, value: std.manifestJsonMinified(c.value) },
            }],
        };

        local controls = {
          number: numberControl,
          string: textControl,
          boolean: booleanControl,
        };

        local field = {
          local c = self,
          spec:: error 'field requires a spec',
          params:: {},
          initialValues:: {},
          issues:: [],
          local name = c.spec.name,
          local present = std.objectHas(c.params, name),
          local initial = std.objectHas(c.initialValues, name),
          local value = if present then c.params[name] else if initial then c.initialValues[name] else null,
          html:
            if std.objectHas(controls, c.spec.type) then [{
              element: 'label',
              children: [
                { element: 'span', children: [name] },
                controls[c.spec.type] { name:: name, value:: value },
              ],
            }] + [
              issue { message:: i.message, hint:: !present }
              for i in c.issues
              if present || !initial
            ]
            else hiddenControl { name:: name, value:: value },
        };

        local paramsForm = {
          local c = self,
          paramSpecs:: [],
          params:: {},
          initialValues:: {},
          issues:: [],
          html: {
            element: 'form',
            attributes: { id: paramsFormId, class: 'params', method: 'get' },
            children: [
              field {
                spec:: spec,
                params:: c.params,
                initialValues:: c.initialValues,
                issues:: [i for i in c.issues if std.get(i, 'param', null) == spec.name],
              }
              for spec in c.paramSpecs
            ],
          },
        };

        local planButton = {
          html: {
            element: 'button',
            attributes: { type: 'submit', form: paramsFormId },
            children: ['Plan'],
          },
        };

        local applyForm = {
          local c = self,
          evaluationId:: error 'applyForm requires an evaluationId',
          label:: 'Apply',
          html: {
            element: 'form',
            attributes: { class: 'apply', method: 'post', action: '/exec' },
            children: [
              { element: 'input', attributes: { type: 'hidden', name: 'evaluationId', value: c.evaluationId } },
              { element: 'button', attributes: { type: 'submit' }, children: [c.label] },
            ],
          },
        };

        {
          local c = self,
          evaluationId:: error 'Action requires an evaluationId',
          summary:: '',
          label:: 'Apply',
          paramSpecs:: [],
          params:: {},
          initialValues:: {},
          action:: null,
          local hasParams = std.length(c.paramSpecs) > 0,
          local issues = if c.action != null && std.objectHas(c.action, 'issues') then c.action.issues else [],
          local applicable = c.action != null && !std.objectHas(c.action, 'issues'),
          local paramNames = [spec.name for spec in c.paramSpecs if std.objectHas(controls, spec.type)],
          local formIssues = [i for i in issues if !std.member(paramNames, std.get(i, 'param', null))],
          html: [
            { element: 'style', children: [style] },
          ] + (if hasParams then [{ element: 'script', children: [{ html: script }] }] else []) + [
            {
              element: 'action-card',
              attributes: { class: 'action card' },
              children:
                (if c.summary != '' then [{ element: 'p', children: [c.summary] }] else []) +
                [
                  issue { message:: if std.objectHas(i, 'param') then '%s: %s' % [i.param, i.message] else i.message }
                  for i in formIssues
                ] +
                (if hasParams then [paramsForm { paramSpecs:: c.paramSpecs, params:: c.params, initialValues:: c.initialValues, issues:: issues }] else []) +
                [{
                  element: 'div',
                  attributes: { class: 'buttons' },
                  children:
                    (if hasParams then [planButton] else []) +
                    (if applicable then [applyForm { evaluationId:: c.evaluationId, label:: c.label }] else []),
                }],
            },
          ],
        },
    };
    local html = {
      manifestHtml(tree): std.native('invoke:html')('manifestHtml', [tree]),
    };

    local isNode(value) =
      std.type(value) == 'object' && std.objectHas(value, '_node') && std.objectHasAll(value, '_queryPath');

    local collectNeighbors(obj, textPrefix='', exclude=[], linkStrings=false) =
      std.flatMap(
        function(k)
          if std.member(exclude, k) || std.substr(k, 0, 1) == '_' then []
          else
            local value = obj[k];
            local textPath = if textPrefix == '' then k else '%s/%s' % [textPrefix, k];
            if isNode(value) then [{ link: value._queryPath, text: textPath }]
            else if std.type(value) == 'object' then collectNeighbors(value, textPath, exclude, linkStrings)
            else if linkStrings && std.type(value) == 'string' then [{ link: value, text: textPath, external: true }]
            else [],
        std.objectFields(obj)
      );

    local linksItems(obj) =
      local links = std.get(obj, 'links', {});
      if std.type(links) != 'object' then []
      else std.flatMap(
        function(k)
          local value = links[k];
          if isNode(value) then [{ link: value._queryPath, text: k }]
          else if std.type(value) == 'string' then [{ link: value, text: k, external: true }]
          else [],
        std.objectFields(links)
      );

    local linksGroups(obj) =
      local links = std.get(obj, 'links', {});
      if std.type(links) != 'object' then []
      else std.flatMap(
        function(k)
          local value = links[k];
          if std.type(value) == 'object' && !isNode(value) then [{ title: k, items: collectNeighbors(value, linkStrings=true) }]
          else [],
        std.objectFields(links)
      );

    local curatedLinks(obj) =
      std.set([
        item.link
        for item in linksItems(obj) + std.flatMap(function(group) group.items, linksGroups(obj))
      ]);

    local neighborKeys(obj) = [
      k
      for k in std.objectFields(obj)
      if !std.member(['data', '_view', 'links'], k) && std.substr(k, 0, 1) != '_' && std.type(obj[k]) == 'object'
    ];

    local nodeGroupsSpec(obj) = std.get(std.get(obj, 'list', {}), 'nodeGroups', {});

    local nodeGroupedKeys(obj) =
      local spec = nodeGroupsSpec(obj);
      std.set(std.flattenArrays([spec[title] for title in std.objectFields(spec)]));

    local neighborItems(obj) =
      local curated = curatedLinks(obj);
      local grouped = nodeGroupedKeys(obj);
      [
        { link: obj[k]._queryPath, text: k }
        for k in neighborKeys(obj)
        if isNode(obj[k]) && !std.setMember(obj[k]._queryPath, curated) && !std.setMember(k, grouped)
      ] + linksItems(obj);

    local nodeGroups(obj) =
      local spec = nodeGroupsSpec(obj);
      local curated = curatedLinks(obj);
      [
        group
        for title in std.objectFields(spec)
        for group in [{
          title: title,
          items: [
            { link: obj[k]._queryPath, text: k }
            for k in spec[title]
            if std.objectHas(obj, k) && isNode(obj[k]) && !std.setMember(obj[k]._queryPath, curated)
          ],
        }]
        if std.length(group.items) > 0
      ];

    local childGroups(obj) =
      local curated = curatedLinks(obj);
      [
        group
        for k in neighborKeys(obj)
        if !isNode(obj[k])
        for group in [{ title: k, items: [item for item in collectNeighbors(obj[k]) if !std.setMember(item.link, curated)] }]
        if std.length(group.items) > 0
      ];

    local orderGroups(groups, order) =
      local rank = { [order[i]]: i for i in std.range(0, std.length(order) - 1) };
      local keyed = [
        { group: groups[i], key: std.get(rank, groups[i].title, std.length(order) + i) }
        for i in std.range(0, std.length(groups) - 1)
      ];
      [entry.group for entry in std.sort(keyed, function(entry) entry.key)];

    local neighborGroups(obj) =
      linksGroups(obj) + orderGroups(childGroups(obj) + nodeGroups(obj), std.get(std.get(obj, 'list', {}), 'groupOrder', []));

    local safeGet(obj, path) =
      std.foldl(
        function(acc, k)
          if acc != null && std.isObject(acc) && std.objectHasAll(acc, k) then acc[k] else null,
        path,
        obj
      );

    local baseView = {
      local n = self,
      _view:: {
        fragment: error 'view requires a fragment',
        page: c.page {
          fragment:: n._view.fragment,
          breadcrumbs:: c.breadcrumbs { pathTemplate:: std.get($, '_pathTemplate', []), node:: $ },
        },
        html: html.manifestHtml(self.page),
      },
    };

    local listView = baseView {
      _view+:: {
        fragment: c.list {
          items:: neighborItems($),
          groups:: neighborGroups($),
          columns:: std.get(std.get($, 'list', {}), 'columns', 1),
        },
      },
    };

    local yamlView = baseView {
      _view+:: {
        fragment: c.yaml { data:: $.data },
      },
    };

    local columnValue(item, col) =
      if std.objectHasAll(col, 'value') then col.value(item) else safeGet(item, col.path);

    local isAlphanumeric(ch) =
      (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9');

    local labelWords(label) = [
      word
      for word in std.split(std.join('', [if isAlphanumeric(ch) then ch else ' ' for ch in std.stringChars(label)]), ' ')
      if word != ''
    ];

    local lowerCamelCase(label) =
      local parts = labelWords(std.toString(label));
      if std.length(parts) == 0 then ''
      else std.asciiLower(parts[0]) + std.join('', [std.asciiUpper(part[0]) + part[1:] for part in parts[1:]]);

    local columnKey(col) = std.get(col, 'key', lowerCamelCase(col.label));

    local projectItem(item, columns) = {
      [col.key]: value
      for col in columns
      for value in [columnValue(item, col)]
      if value != null
    };

    local tableView = baseView {
      data:: error 'table requires data',
      local table = std.get($, 'table', {}),
      local at = std.get(table, 'at', ['items']),
      local columns = [col { key: columnKey(col) } for col in std.get(table, 'columns', [])],
      local found = safeGet($.data, at),
      local dataItems = if std.isArray(found) then found else [],
      items: [projectItem(item, columns) for item in dataItems],
      _view+:: {
        fragment:
          local rowLink = linkspecs.rowLinkFor($, std.get($, 'linkSpecs', []), at);
          c.table {
            items:: $.items,
            columns:: columns,
            rowLinks:: if rowLink == null then [] else [rowLink(item) for item in dataItems],
            pagination:: std.get(std.get($, 'links', {}), 'pagination', null),
          },
      },
    };

    local treeView = baseView {
      _view+:: {
        fragment:
          local tree = std.get($, 'tree', {});
          c.resource {
            items:: neighborItems($),
            groups:: neighborGroups($),
            columns:: std.get(std.get($, 'list', {}), 'columns', 1),
            content:: c.tree {
              nodes:: std.get(tree, 'nodes', []),
              item:: std.get(tree, 'item', super.item),
            },
          },
      },
    };

    local resourceView = baseView {
      _view+:: {
        fragment: c.resource {
          data:: $.data,
          items:: neighborItems($),
          groups:: neighborGroups($),
          columns:: std.get(std.get($, 'list', {}), 'columns', 1),
          stacked:: std.get(std.get($, 'resource', {}), 'stacked', false),
        },
      },
    };

    local actionView = baseView {
      _view+:: {
        fragment: c.action {
          evaluationId:: std.get($, '_evaluationId', ''),
          summary:: std.get($, '_summary', ''),
          paramSpecs:: std.get($, '_paramSpecs', []),
          params:: std.get($, '_params', {}),
          initialValues:: std.get($, '_paramInitialValues', {}),
          action:: std.get($, '_action', null),
        },
      },
    };

    local withNode = { node: self.view + linkspecs.withLinkSpecs };

    {
      default: { view: listView } + withNode,
      list: { view: listView } + withNode,
      table: { view: tableView } + withNode,
      tree: { view: treeView } + withNode,
      yaml: { view: yamlView } + withNode,
      resource: { view: resourceView } + withNode,
      action: { view: actionView } + withNode,
    };
  local coreLib = {
    podTableNode:: {
      table+:: {
        columns: [
          { label: 'Name', path: ['metadata', 'name'] },
          { label: 'Namespace', path: ['metadata', 'namespace'] },
          {
            label: 'Ready',
            paths: [['spec', 'containers'], ['status', 'containerStatuses']],
            value(item)::
              local statuses = std.get(item.status, 'containerStatuses', []);
              '%d/%d' % [std.length([s for s in statuses if s.ready]), std.length(item.spec.containers)],
          },
          { label: 'Status', path: ['status', 'phase'] },
          {
            label: 'Restarts',
            paths: [['status', 'containerStatuses']],
            value(item)::
              std.foldl(function(acc, s) acc + s.restartCount, std.get(item.status, 'containerStatuses', []), 0),
          },
          { label: 'Node', path: ['spec', 'nodeName'] },
          { label: 'Pod IP', path: ['status', 'podIP'] },
          { label: 'Created', path: ['metadata', 'creationTimestamp'] },
        ],
      },
    },
    nodeList: [
      [['kubernetes']],
      [['kubernetes', '$context', 'pods'], $.podTableNode],
      [['kubernetes', '$context', '$namespace', 'pods'], $.podTableNode],
    ],
  };
  local kubernetes = {
    contexts(): std.native('invoke:kubernetes')('contexts', []),
    get(ctx, path, fields=[]): std.native('invoke:kubernetes')('get', [ctx, path, fields]),
    neat: {
      get(ctx, path, fields=[]): std.native('invoke:kubernetes')('neatGet', [ctx, path, fields]),
    },
  };
  local time = {
    now(): std.native('invoke:time')('now', []),
    addDuration(epochMs, spec): std.native('invoke:time')('addDuration', [epochMs, spec]),
    parse(value, layout): std.native('invoke:time')('parse', [value, layout]),
    format(epochMs, layout): std.native('invoke:time')('format', [epochMs, layout]),
  };
  local root = import 'root';

  local podSelectorTable = a.table.node + coreLib.podTableNode {
    allPods:: kubernetes.get($.context, std.format('/api/v1/namespaces/%s/pods', [std.toString($.namespace)])).items,
    data:: {
      items: [
        p
        for p in $.allPods
        if std.all([std.objectHas(p.metadata.labels, k) && p.metadata.labels[k] == $.selector[k] for k in std.objectFields($.selector)])
      ],
    },
    linkSpecs:: [
      {
        at: ['items'],
        keys: [{ path: ['metadata', 'name'] }],
        value: [{ const: 'kubernetes' }, { origin: 'context' }, { origin: 'namespace' }, { param: 'pod', path: ['metadata', 'name'] }],
      },
    ],
  };

  local restartNode = a.action.node {
    resource:: error 'restartNode requires a resource',
    resourceName:: error 'restartNode requires a resourceName',
    redirectTo:: error 'restartNode requires a redirectTo',
    _summary: 'Restart %s/%s in %s' % [$.resource, $.resourceName, $.namespace],
    _action: {
      plugin: 'kubernetes',
      name: 'patch',
      data: {
        ctx: $.context,
        path: std.format('/apis/apps/v1/namespaces/%s/%s/%s', [std.toString($.namespace), $.resource, $.resourceName]),
        patch: {
          spec: {
            template: {
              metadata: {
                annotations: {
                  'kubectl.kubernetes.io/restartedAt': time.format(time.now(), '2006-01-02T15:04:05Z07:00'),
                },
              },
            },
          },
        },
      },
      redirect: $.redirectTo,
    },
  };

  local scaleNode = a.action.node {
    resource:: error 'scaleNode requires a resource',
    resourceName:: error 'scaleNode requires a resourceName',
    redirectTo:: error 'scaleNode requires a redirectTo',
    local path = std.format('/apis/apps/v1/namespaces/%s/%s/%s', [std.toString($.namespace), $.resource, $.resourceName]),
    local replicas = std.get($._params, 'replicas', null),
    _paramSpecs: [{ name: 'replicas', type: 'number', default: null }],
    _paramInitialValues:: {
      replicas: std.get(kubernetes.neat.get($.context, path).spec, 'replicas', 1),
    },
    _summary:
      if replicas == null then 'Scale %s/%s in %s' % [$.resource, $.resourceName, $.namespace]
      else 'Scale %s/%s in %s to %s replicas' % [$.resource, $.resourceName, $.namespace, std.toString(replicas)],
    _action:
      if replicas == null then { issues: [{ param: 'replicas', message: 'is required' }] }
      else if replicas < 0 || std.floor(replicas) != replicas then { issues: [{ param: 'replicas', message: 'must be a whole number of at least 0' }] }
      else {
        plugin: 'kubernetes',
        name: 'patch',
        data: {
          ctx: $.context,
          path: path,
          patch: { spec: { replicas: replicas } },
        },
        redirect: $.redirectTo,
      },
  };

  local nodeList = [
    [['kubernetes', '$context', '$namespace', 'apps', '$deployment', 'pods'], podSelectorTable {
      selector: kubernetes.neat.get($.context, std.format('/apis/apps/v1/namespaces/%s/deployments/%s', [std.toString($.namespace), std.toString($.deployment)])).spec.selector.matchLabels,
    }],
    [['kubernetes', '$context', '$namespace', 'apps', '$statefulset', 'pods'], podSelectorTable {
      selector: kubernetes.neat.get($.context, std.format('/apis/apps/v1/namespaces/%s/statefulsets/%s', [std.toString($.namespace), std.toString($.statefulset)])).spec.selector.matchLabels,
    }],
    [['kubernetes', '$context', '$namespace', 'apps', '$daemonset', 'pods'], podSelectorTable {
      selector: kubernetes.neat.get($.context, std.format('/apis/apps/v1/namespaces/%s/daemonsets/%s', [std.toString($.namespace), std.toString($.daemonset)])).spec.selector.matchLabels,
    }],
    [['kubernetes', '$context', '$namespace', 'apps', '$deployment', 'action', 'restart'], restartNode {
      resource:: 'deployments',
      resourceName:: $.deployment,
      redirectTo:: root.kubernetes.context($.context).namespace($.namespace).apps.deployment($.deployment).pods,
    }],
    [['kubernetes', '$context', '$namespace', 'apps', '$statefulset', 'action', 'restart'], restartNode {
      resource:: 'statefulsets',
      resourceName:: $.statefulset,
      redirectTo:: root.kubernetes.context($.context).namespace($.namespace).apps.statefulset($.statefulset).pods,
    }],
    [['kubernetes', '$context', '$namespace', 'apps', '$deployment', 'action', 'scale'], scaleNode {
      resource:: 'deployments',
      resourceName:: $.deployment,
      redirectTo:: root.kubernetes.context($.context).namespace($.namespace).apps.deployment($.deployment).pods,
    }],
    [['kubernetes', '$context', '$namespace', 'apps', '$statefulset', 'action', 'scale'], scaleNode {
      resource:: 'statefulsets',
      resourceName:: $.statefulset,
      redirectTo:: root.kubernetes.context($.context).namespace($.namespace).apps.statefulset($.statefulset).pods,
    }],
    [['kubernetes', '$context', '$namespace', 'apps', '$daemonset', 'action', 'restart'], restartNode {
      resource:: 'daemonsets',
      resourceName:: $.daemonset,
      redirectTo:: root.kubernetes.context($.context).namespace($.namespace).apps.daemonset($.daemonset).pods,
    }],
  ];

  {
    nodeList: nodeList,
  };
local nodeListsCoreLib = {
  podTableNode:: {
    table+:: {
      columns: [
        { label: 'Name', path: ['metadata', 'name'] },
        { label: 'Namespace', path: ['metadata', 'namespace'] },
        {
          label: 'Ready',
          paths: [['spec', 'containers'], ['status', 'containerStatuses']],
          value(item)::
            local statuses = std.get(item.status, 'containerStatuses', []);
            '%d/%d' % [std.length([s for s in statuses if s.ready]), std.length(item.spec.containers)],
        },
        { label: 'Status', path: ['status', 'phase'] },
        {
          label: 'Restarts',
          paths: [['status', 'containerStatuses']],
          value(item)::
            std.foldl(function(acc, s) acc + s.restartCount, std.get(item.status, 'containerStatuses', []), 0),
        },
        { label: 'Node', path: ['spec', 'nodeName'] },
        { label: 'Pod IP', path: ['status', 'podIP'] },
        { label: 'Created', path: ['metadata', 'creationTimestamp'] },
      ],
    },
  },
  nodeList: [
    [['kubernetes']],
    [['kubernetes', '$context', 'pods'], $.podTableNode],
    [['kubernetes', '$context', '$namespace', 'pods'], $.podTableNode],
  ],
};
local nodeListsNetworkingK8sIoLib =
  local nodeList = [
    [['kubernetes', '$context', '$namespace', 'networking.k8s.io', '$ingress'], {
      linkSpecs+:: [
        {
          at: ['spec', 'rules'],
          keys: [{ const: 'external' }, { path: ['host'] }],
          value: { scheme: 'https', host: [{ path: ['host'] }] },
        },
      ],
    }],
  ];

  {
    nodeList: nodeList,
  };

{
  graph: graphLib,
  core: nodeListsCoreLib,
  apps: nodeListsAppsLib,
  'networking.k8s.io': nodeListsNetworkingK8sIoLib,
}
