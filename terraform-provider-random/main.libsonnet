local build = {
  expression(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_')
      then
        if std.objectHas(val._, 'ref')
        then val._.ref
        else '"%s"' % [val._.str]
      else '{%s}' % [std.join(',', std.map(function(key) '%s:%s' % [self.expression(key), self.expression(val[key])], std.objectFields(val)))]
    else if std.type(val) == 'array' then '[%s]' % [std.join(',', std.map(function(element) self.expression(element), val))]
    else if std.type(val) == 'string' then '"%s"' % [val]
    else '"%s"' % [val],
  template(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_')
      then
        if std.objectHas(val._, 'ref')
        then std.strReplace(self.string(val), '\n', '\\n')
        else val._.str
      else std.mapWithKey(function(key, value) self.template(value), val)
    else if std.type(val) == 'array' then std.map(function(element) self.template(element), val)
    else if std.type(val) == 'string' then std.strReplace(self.string(val), '\n', '\\n')
    else val,
  string(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_')
      then
        if std.objectHas(val._, 'ref')
        then '${%s}' % [val._.ref]
        else val._.str
      else '${%s}' % [self.expression(val)]
    else if std.type(val) == 'array' then '${%s}' % [self.expression(val)]
    else if std.type(val) == 'string' then val
    else val,
  providerRequirements(val):
    if std.type(val) == 'object'
    then
      if std.objectHas(val, '_')
      then std.get(val._, 'providerRequirements', {})
      else std.foldl(function(acc, val) std.mergePatch(acc, val), std.map(function(key) build.providerRequirements(val[key]), std.objectFields(val)), {})
    else if std.type(val) == 'array'
    then std.foldl(function(acc, val) std.mergePatch(acc, val), std.map(function(element) build.providerRequirements(element), val), {})
    else {},
};

local providerTemplate(provider, requirements, configuration) = {
  local providerRequirements = { [provider]: requirements },
  local providerAlias = if configuration == null then null else configuration.alias,
  local providerWithAlias = if configuration == null then null else '%s.%s' % [provider, providerAlias],
  local providerConfiguration = if configuration == null then {} else { [providerWithAlias]: { provider: { [provider]: configuration } } },
  local providerReference = if configuration == null then {} else { provider: providerWithAlias },
  blockType(blockType): {
    local blockTypePath = if blockType == 'resource' then [] else ['data'],
    resource(type, name): {
      local resourceType = std.substr(type, std.length(provider) + 1, std.length(type)),
      local resourcePath = blockTypePath + [type, name],
      _(rawBlock, block): {
        local metaBlock = {
          depends_on: build.template(std.get(rawBlock, 'depends_on', null)),
          count: build.template(std.get(rawBlock, 'count', null)),
          for_each: build.template(std.get(rawBlock, 'for_each', null)),
        },
        type: if std.objectHas(rawBlock, 'for_each') then 'map' else if std.objectHas(rawBlock, 'count') then 'list' else 'object',
        providerRequirements: build.providerRequirements(rawBlock) + providerRequirements,
        providerConfiguration: providerConfiguration,
        provider: provider,
        providerAlias: providerAlias,
        resourceType: resourceType,
        name: name,
        ref: std.join('.', resourcePath),
        block: {
          [blockType]: {
            [type]: {
              [name]: std.prune(metaBlock + block + providerReference),
            },
          },
        },
      },
      field(fieldName): {
        local fieldPath = resourcePath + [fieldName],
        _: {
          ref: std.join('.', fieldPath),
        },
      },
    },
  },
  func(name, parameters=[]): {
    local parameterString = std.join(', ', [build.expression(parameter) for parameter in parameters]),
    _: {
      providerRequirements: build.providerRequirements(parameters) + providerRequirements,
      providerConfiguration: providerConfiguration,
      ref: 'provider::%s::%s(%s)' % [provider, name, parameterString],
    },
  },
};

local provider(configuration) = {
  local requirements = {
    source: 'registry.terraform.io/hashicorp/random',
    version: '3.7.1',
  },
  local provider = providerTemplate('random', requirements, configuration),
  resource: {
    local blockType = provider.blockType('resource'),
    bytes(name, block): {
      local resource = blockType.resource('random_bytes', name),
      _: resource._(block, {
        base64: build.template(std.get(block, 'base64', null)),
        hex: build.template(std.get(block, 'hex', null)),
        keepers: build.template(std.get(block, 'keepers', null)),
        length: build.template(block.length),
      }),
      base64: resource.field('base64'),
      hex: resource.field('hex'),
      keepers: resource.field('keepers'),
      length: resource.field('length'),
    },
    id(name, block): {
      local resource = blockType.resource('random_id', name),
      _: resource._(block, {
        b64_std: build.template(std.get(block, 'b64_std', null)),
        b64_url: build.template(std.get(block, 'b64_url', null)),
        byte_length: build.template(block.byte_length),
        dec: build.template(std.get(block, 'dec', null)),
        hex: build.template(std.get(block, 'hex', null)),
        id: build.template(std.get(block, 'id', null)),
        keepers: build.template(std.get(block, 'keepers', null)),
        prefix: build.template(std.get(block, 'prefix', null)),
      }),
      b64_std: resource.field('b64_std'),
      b64_url: resource.field('b64_url'),
      byte_length: resource.field('byte_length'),
      dec: resource.field('dec'),
      hex: resource.field('hex'),
      id: resource.field('id'),
      keepers: resource.field('keepers'),
      prefix: resource.field('prefix'),
    },
    integer(name, block): {
      local resource = blockType.resource('random_integer', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        keepers: build.template(std.get(block, 'keepers', null)),
        max: build.template(block.max),
        min: build.template(block.min),
        result: build.template(std.get(block, 'result', null)),
        seed: build.template(std.get(block, 'seed', null)),
      }),
      id: resource.field('id'),
      keepers: resource.field('keepers'),
      max: resource.field('max'),
      min: resource.field('min'),
      result: resource.field('result'),
      seed: resource.field('seed'),
    },
    password(name, block): {
      local resource = blockType.resource('random_password', name),
      _: resource._(block, {
        bcrypt_hash: build.template(std.get(block, 'bcrypt_hash', null)),
        id: build.template(std.get(block, 'id', null)),
        keepers: build.template(std.get(block, 'keepers', null)),
        length: build.template(block.length),
        lower: build.template(std.get(block, 'lower', null)),
        min_lower: build.template(std.get(block, 'min_lower', null)),
        min_numeric: build.template(std.get(block, 'min_numeric', null)),
        min_special: build.template(std.get(block, 'min_special', null)),
        min_upper: build.template(std.get(block, 'min_upper', null)),
        number: build.template(std.get(block, 'number', null)),
        numeric: build.template(std.get(block, 'numeric', null)),
        override_special: build.template(std.get(block, 'override_special', null)),
        result: build.template(std.get(block, 'result', null)),
        special: build.template(std.get(block, 'special', null)),
        upper: build.template(std.get(block, 'upper', null)),
      }),
      bcrypt_hash: resource.field('bcrypt_hash'),
      id: resource.field('id'),
      keepers: resource.field('keepers'),
      length: resource.field('length'),
      lower: resource.field('lower'),
      min_lower: resource.field('min_lower'),
      min_numeric: resource.field('min_numeric'),
      min_special: resource.field('min_special'),
      min_upper: resource.field('min_upper'),
      number: resource.field('number'),
      numeric: resource.field('numeric'),
      override_special: resource.field('override_special'),
      result: resource.field('result'),
      special: resource.field('special'),
      upper: resource.field('upper'),
    },
    pet(name, block): {
      local resource = blockType.resource('random_pet', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        keepers: build.template(std.get(block, 'keepers', null)),
        length: build.template(std.get(block, 'length', null)),
        prefix: build.template(std.get(block, 'prefix', null)),
        separator: build.template(std.get(block, 'separator', null)),
      }),
      id: resource.field('id'),
      keepers: resource.field('keepers'),
      length: resource.field('length'),
      prefix: resource.field('prefix'),
      separator: resource.field('separator'),
    },
    shuffle(name, block): {
      local resource = blockType.resource('random_shuffle', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        input: build.template(block.input),
        keepers: build.template(std.get(block, 'keepers', null)),
        result: build.template(std.get(block, 'result', null)),
        result_count: build.template(std.get(block, 'result_count', null)),
        seed: build.template(std.get(block, 'seed', null)),
      }),
      id: resource.field('id'),
      input: resource.field('input'),
      keepers: resource.field('keepers'),
      result: resource.field('result'),
      result_count: resource.field('result_count'),
      seed: resource.field('seed'),
    },
    string(name, block): {
      local resource = blockType.resource('random_string', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        keepers: build.template(std.get(block, 'keepers', null)),
        length: build.template(block.length),
        lower: build.template(std.get(block, 'lower', null)),
        min_lower: build.template(std.get(block, 'min_lower', null)),
        min_numeric: build.template(std.get(block, 'min_numeric', null)),
        min_special: build.template(std.get(block, 'min_special', null)),
        min_upper: build.template(std.get(block, 'min_upper', null)),
        number: build.template(std.get(block, 'number', null)),
        numeric: build.template(std.get(block, 'numeric', null)),
        override_special: build.template(std.get(block, 'override_special', null)),
        result: build.template(std.get(block, 'result', null)),
        special: build.template(std.get(block, 'special', null)),
        upper: build.template(std.get(block, 'upper', null)),
      }),
      id: resource.field('id'),
      keepers: resource.field('keepers'),
      length: resource.field('length'),
      lower: resource.field('lower'),
      min_lower: resource.field('min_lower'),
      min_numeric: resource.field('min_numeric'),
      min_special: resource.field('min_special'),
      min_upper: resource.field('min_upper'),
      number: resource.field('number'),
      numeric: resource.field('numeric'),
      override_special: resource.field('override_special'),
      result: resource.field('result'),
      special: resource.field('special'),
      upper: resource.field('upper'),
    },
    uuid(name, block): {
      local resource = blockType.resource('random_uuid', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        keepers: build.template(std.get(block, 'keepers', null)),
        result: build.template(std.get(block, 'result', null)),
      }),
      id: resource.field('id'),
      keepers: resource.field('keepers'),
      result: resource.field('result'),
    },
  },
};

local providerWithConfiguration = provider(null) + {
  withConfiguration(alias, block): provider(std.prune({
    alias: alias,
  })),
};

providerWithConfiguration
