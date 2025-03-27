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
  blocks(val):
    if std.type(val) == 'object'
    then
      if std.objectHas(val, '_')
      then
        if std.objectHas(val._, 'blocks')
        then val._.blocks
        else
          if std.objectHas(val._, 'block')
          then { [val._.ref]: val._.block }
          else {}
      else std.foldl(function(acc, val) std.mergePatch(acc, val), std.map(function(key) build.blocks(val[key]), std.objectFields(val)), {})
    else if std.type(val) == 'array'
    then std.foldl(function(acc, val) std.mergePatch(acc, val), std.map(function(element) build.blocks(element), val), {})
    else {},
};

local providerTemplate(provider, requirements, rawConfiguration, configuration) = {
  local providerRequirements = {
    ['terraform.required_providers.%s' % [provider]]: requirements,
  },
  local providerAlias = if configuration == null then null else std.get(configuration, 'alias', null),
  local providerConfiguration =
    if configuration == null then { _: { refBlock: {}, blocks: [] } } else {
      _: {
        local _ = self,
        ref: '%s.%s' % [provider, configuration.alias],
        refBlock: {
          provider: _.ref,
        },
        block: {
          provider: {
            [provider]: std.prune(configuration),
          },
        },
        blocks: build.blocks(rawConfiguration) + {
          [_.ref]: _.block,
        },
      },
    },
  blockType(blockType): {
    local blockTypePath = if blockType == 'resource' then [] else ['data'],
    resource(type, name): {
      local resourceType = std.substr(type, std.length(provider) + 1, std.length(type)),
      local resourcePath = blockTypePath + [type, name],
      _(rawBlock, block): {
        local _ = self,
        local metaBlock = {
          depends_on: build.template(std.get(rawBlock, 'depends_on', null)),
          count: build.template(std.get(rawBlock, 'count', null)),
          for_each: build.template(std.get(rawBlock, 'for_each', null)),
        },
        type: if std.objectHas(rawBlock, 'for_each') then 'map' else if std.objectHas(rawBlock, 'count') then 'list' else 'object',
        provider: provider,
        providerAlias: providerAlias,
        resourceType: resourceType,
        name: name,
        ref: std.join('.', resourcePath),
        block: {
          [blockType]: {
            [type]: {
              [name]: std.prune(providerConfiguration._.refBlock + metaBlock + block),
            },
          },
        },
        blocks: build.blocks([providerConfiguration] + [rawBlock]) + providerRequirements + {
          [_.ref]: _.block,
        },
      },
      field(blocks, fieldName): {
        local fieldPath = resourcePath + [fieldName],
        _: {
          ref: std.join('.', fieldPath),
          blocks: blocks,
        },
      },
    },
  },
  func(name, parameters=[]): {
    local parameterString = std.join(', ', [build.expression(parameter) for parameter in parameters]),
    _: {
      ref: 'provider::%s::%s(%s)' % [provider, name, parameterString],
      blocks: build.blocks([providerConfiguration] + [parameters]) + providerRequirements,
    },
  },
};

local provider(rawConfiguration, configuration) = {
  local requirements = {
    source: 'registry.terraform.io/hashicorp/random',
    version: '3.7.1',
  },
  local provider = providerTemplate('random', requirements, rawConfiguration, configuration),
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
      base64: resource.field(self._.blocks, 'base64'),
      hex: resource.field(self._.blocks, 'hex'),
      keepers: resource.field(self._.blocks, 'keepers'),
      length: resource.field(self._.blocks, 'length'),
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
      b64_std: resource.field(self._.blocks, 'b64_std'),
      b64_url: resource.field(self._.blocks, 'b64_url'),
      byte_length: resource.field(self._.blocks, 'byte_length'),
      dec: resource.field(self._.blocks, 'dec'),
      hex: resource.field(self._.blocks, 'hex'),
      id: resource.field(self._.blocks, 'id'),
      keepers: resource.field(self._.blocks, 'keepers'),
      prefix: resource.field(self._.blocks, 'prefix'),
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
      id: resource.field(self._.blocks, 'id'),
      keepers: resource.field(self._.blocks, 'keepers'),
      max: resource.field(self._.blocks, 'max'),
      min: resource.field(self._.blocks, 'min'),
      result: resource.field(self._.blocks, 'result'),
      seed: resource.field(self._.blocks, 'seed'),
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
      bcrypt_hash: resource.field(self._.blocks, 'bcrypt_hash'),
      id: resource.field(self._.blocks, 'id'),
      keepers: resource.field(self._.blocks, 'keepers'),
      length: resource.field(self._.blocks, 'length'),
      lower: resource.field(self._.blocks, 'lower'),
      min_lower: resource.field(self._.blocks, 'min_lower'),
      min_numeric: resource.field(self._.blocks, 'min_numeric'),
      min_special: resource.field(self._.blocks, 'min_special'),
      min_upper: resource.field(self._.blocks, 'min_upper'),
      number: resource.field(self._.blocks, 'number'),
      numeric: resource.field(self._.blocks, 'numeric'),
      override_special: resource.field(self._.blocks, 'override_special'),
      result: resource.field(self._.blocks, 'result'),
      special: resource.field(self._.blocks, 'special'),
      upper: resource.field(self._.blocks, 'upper'),
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
      id: resource.field(self._.blocks, 'id'),
      keepers: resource.field(self._.blocks, 'keepers'),
      length: resource.field(self._.blocks, 'length'),
      prefix: resource.field(self._.blocks, 'prefix'),
      separator: resource.field(self._.blocks, 'separator'),
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
      id: resource.field(self._.blocks, 'id'),
      input: resource.field(self._.blocks, 'input'),
      keepers: resource.field(self._.blocks, 'keepers'),
      result: resource.field(self._.blocks, 'result'),
      result_count: resource.field(self._.blocks, 'result_count'),
      seed: resource.field(self._.blocks, 'seed'),
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
      id: resource.field(self._.blocks, 'id'),
      keepers: resource.field(self._.blocks, 'keepers'),
      length: resource.field(self._.blocks, 'length'),
      lower: resource.field(self._.blocks, 'lower'),
      min_lower: resource.field(self._.blocks, 'min_lower'),
      min_numeric: resource.field(self._.blocks, 'min_numeric'),
      min_special: resource.field(self._.blocks, 'min_special'),
      min_upper: resource.field(self._.blocks, 'min_upper'),
      number: resource.field(self._.blocks, 'number'),
      numeric: resource.field(self._.blocks, 'numeric'),
      override_special: resource.field(self._.blocks, 'override_special'),
      result: resource.field(self._.blocks, 'result'),
      special: resource.field(self._.blocks, 'special'),
      upper: resource.field(self._.blocks, 'upper'),
    },
    uuid(name, block): {
      local resource = blockType.resource('random_uuid', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        keepers: build.template(std.get(block, 'keepers', null)),
        result: build.template(std.get(block, 'result', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      keepers: resource.field(self._.blocks, 'keepers'),
      result: resource.field(self._.blocks, 'result'),
    },
  },
};

local providerWithConfiguration = provider(null, null) + {
  withConfiguration(alias, block): provider(block, {
    alias: alias,
  }),
};

providerWithConfiguration
