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

local providerTemplate(provider, requirements, configuration) = {
  local providerRequirements = { ['terraform.required_providers.%s' % [provider]]: requirements },
  local providerAlias = if configuration == null then null else configuration.alias,
  local providerRef = if configuration == null then null else '%s.%s' % [provider, providerAlias],
  local providerConfiguration = if configuration == null then {} else { [providerRef]: { provider: { [provider]: configuration } } },
  local providerRefBlock = if configuration == null then {} else { provider: providerRef },
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
              [name]: std.prune(metaBlock + block + providerRefBlock),
            },
          },
        },
        blocks: build.blocks(rawBlock) + providerRequirements + providerConfiguration + {
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
      blocks: build.blocks(parameters) + providerRequirements + providerConfiguration,
    },
  },
};

local provider(configuration) = {
  local requirements = {
    source: 'registry.terraform.io/hashicorp/local',
    version: '2.5.2',
  },
  local provider = providerTemplate('local', requirements, configuration),
  resource: {
    local blockType = provider.blockType('resource'),
    file(name, block): {
      local resource = blockType.resource('local_file', name),
      _: resource._(block, {
        content: build.template(std.get(block, 'content', null)),
        content_base64: build.template(std.get(block, 'content_base64', null)),
        content_base64sha256: build.template(std.get(block, 'content_base64sha256', null)),
        content_base64sha512: build.template(std.get(block, 'content_base64sha512', null)),
        content_md5: build.template(std.get(block, 'content_md5', null)),
        content_sha1: build.template(std.get(block, 'content_sha1', null)),
        content_sha256: build.template(std.get(block, 'content_sha256', null)),
        content_sha512: build.template(std.get(block, 'content_sha512', null)),
        directory_permission: build.template(std.get(block, 'directory_permission', null)),
        file_permission: build.template(std.get(block, 'file_permission', null)),
        filename: build.template(block.filename),
        id: build.template(std.get(block, 'id', null)),
        sensitive_content: build.template(std.get(block, 'sensitive_content', null)),
        source: build.template(std.get(block, 'source', null)),
      }),
      content: resource.field(self._.blocks, 'content'),
      content_base64: resource.field(self._.blocks, 'content_base64'),
      content_base64sha256: resource.field(self._.blocks, 'content_base64sha256'),
      content_base64sha512: resource.field(self._.blocks, 'content_base64sha512'),
      content_md5: resource.field(self._.blocks, 'content_md5'),
      content_sha1: resource.field(self._.blocks, 'content_sha1'),
      content_sha256: resource.field(self._.blocks, 'content_sha256'),
      content_sha512: resource.field(self._.blocks, 'content_sha512'),
      directory_permission: resource.field(self._.blocks, 'directory_permission'),
      file_permission: resource.field(self._.blocks, 'file_permission'),
      filename: resource.field(self._.blocks, 'filename'),
      id: resource.field(self._.blocks, 'id'),
      sensitive_content: resource.field(self._.blocks, 'sensitive_content'),
      source: resource.field(self._.blocks, 'source'),
    },
    sensitive_file(name, block): {
      local resource = blockType.resource('local_sensitive_file', name),
      _: resource._(block, {
        content: build.template(std.get(block, 'content', null)),
        content_base64: build.template(std.get(block, 'content_base64', null)),
        content_base64sha256: build.template(std.get(block, 'content_base64sha256', null)),
        content_base64sha512: build.template(std.get(block, 'content_base64sha512', null)),
        content_md5: build.template(std.get(block, 'content_md5', null)),
        content_sha1: build.template(std.get(block, 'content_sha1', null)),
        content_sha256: build.template(std.get(block, 'content_sha256', null)),
        content_sha512: build.template(std.get(block, 'content_sha512', null)),
        directory_permission: build.template(std.get(block, 'directory_permission', null)),
        file_permission: build.template(std.get(block, 'file_permission', null)),
        filename: build.template(block.filename),
        id: build.template(std.get(block, 'id', null)),
        source: build.template(std.get(block, 'source', null)),
      }),
      content: resource.field(self._.blocks, 'content'),
      content_base64: resource.field(self._.blocks, 'content_base64'),
      content_base64sha256: resource.field(self._.blocks, 'content_base64sha256'),
      content_base64sha512: resource.field(self._.blocks, 'content_base64sha512'),
      content_md5: resource.field(self._.blocks, 'content_md5'),
      content_sha1: resource.field(self._.blocks, 'content_sha1'),
      content_sha256: resource.field(self._.blocks, 'content_sha256'),
      content_sha512: resource.field(self._.blocks, 'content_sha512'),
      directory_permission: resource.field(self._.blocks, 'directory_permission'),
      file_permission: resource.field(self._.blocks, 'file_permission'),
      filename: resource.field(self._.blocks, 'filename'),
      id: resource.field(self._.blocks, 'id'),
      source: resource.field(self._.blocks, 'source'),
    },
  },
  data: {
    local blockType = provider.blockType('data'),
    file(name, block): {
      local resource = blockType.resource('local_file', name),
      _: resource._(block, {
        content: build.template(std.get(block, 'content', null)),
        content_base64: build.template(std.get(block, 'content_base64', null)),
        content_base64sha256: build.template(std.get(block, 'content_base64sha256', null)),
        content_base64sha512: build.template(std.get(block, 'content_base64sha512', null)),
        content_md5: build.template(std.get(block, 'content_md5', null)),
        content_sha1: build.template(std.get(block, 'content_sha1', null)),
        content_sha256: build.template(std.get(block, 'content_sha256', null)),
        content_sha512: build.template(std.get(block, 'content_sha512', null)),
        filename: build.template(block.filename),
        id: build.template(std.get(block, 'id', null)),
      }),
      content: resource.field(self._.blocks, 'content'),
      content_base64: resource.field(self._.blocks, 'content_base64'),
      content_base64sha256: resource.field(self._.blocks, 'content_base64sha256'),
      content_base64sha512: resource.field(self._.blocks, 'content_base64sha512'),
      content_md5: resource.field(self._.blocks, 'content_md5'),
      content_sha1: resource.field(self._.blocks, 'content_sha1'),
      content_sha256: resource.field(self._.blocks, 'content_sha256'),
      content_sha512: resource.field(self._.blocks, 'content_sha512'),
      filename: resource.field(self._.blocks, 'filename'),
      id: resource.field(self._.blocks, 'id'),
    },
    sensitive_file(name, block): {
      local resource = blockType.resource('local_sensitive_file', name),
      _: resource._(block, {
        content: build.template(std.get(block, 'content', null)),
        content_base64: build.template(std.get(block, 'content_base64', null)),
        content_base64sha256: build.template(std.get(block, 'content_base64sha256', null)),
        content_base64sha512: build.template(std.get(block, 'content_base64sha512', null)),
        content_md5: build.template(std.get(block, 'content_md5', null)),
        content_sha1: build.template(std.get(block, 'content_sha1', null)),
        content_sha256: build.template(std.get(block, 'content_sha256', null)),
        content_sha512: build.template(std.get(block, 'content_sha512', null)),
        filename: build.template(block.filename),
        id: build.template(std.get(block, 'id', null)),
      }),
      content: resource.field(self._.blocks, 'content'),
      content_base64: resource.field(self._.blocks, 'content_base64'),
      content_base64sha256: resource.field(self._.blocks, 'content_base64sha256'),
      content_base64sha512: resource.field(self._.blocks, 'content_base64sha512'),
      content_md5: resource.field(self._.blocks, 'content_md5'),
      content_sha1: resource.field(self._.blocks, 'content_sha1'),
      content_sha256: resource.field(self._.blocks, 'content_sha256'),
      content_sha512: resource.field(self._.blocks, 'content_sha512'),
      filename: resource.field(self._.blocks, 'filename'),
      id: resource.field(self._.blocks, 'id'),
    },
  },
  func: {
    direxists(path): provider.func('direxists', [path]),
  },
};

local providerWithConfiguration = provider(null) + {
  withConfiguration(alias, block): provider(std.prune({
    alias: alias,
  })),
};

providerWithConfiguration
