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
    source: 'registry.terraform.io/hashicorp/archive',
    version: '2.7.0',
  },
  local provider = providerTemplate('archive', requirements, configuration),
  resource: {
    local blockType = provider.blockType('resource'),
    file(name, block): {
      local resource = blockType.resource('archive_file', name),
      _: resource._(block, {
        exclude_symlink_directories: build.template(std.get(block, 'exclude_symlink_directories', null)),
        excludes: build.template(std.get(block, 'excludes', null)),
        id: build.template(std.get(block, 'id', null)),
        output_base64sha256: build.template(std.get(block, 'output_base64sha256', null)),
        output_base64sha512: build.template(std.get(block, 'output_base64sha512', null)),
        output_file_mode: build.template(std.get(block, 'output_file_mode', null)),
        output_md5: build.template(std.get(block, 'output_md5', null)),
        output_path: build.template(block.output_path),
        output_sha: build.template(std.get(block, 'output_sha', null)),
        output_sha256: build.template(std.get(block, 'output_sha256', null)),
        output_sha512: build.template(std.get(block, 'output_sha512', null)),
        output_size: build.template(std.get(block, 'output_size', null)),
        source_content: build.template(std.get(block, 'source_content', null)),
        source_content_filename: build.template(std.get(block, 'source_content_filename', null)),
        source_dir: build.template(std.get(block, 'source_dir', null)),
        source_file: build.template(std.get(block, 'source_file', null)),
        type: build.template(block.type),
      }),
      exclude_symlink_directories: resource.field('exclude_symlink_directories'),
      excludes: resource.field('excludes'),
      id: resource.field('id'),
      output_base64sha256: resource.field('output_base64sha256'),
      output_base64sha512: resource.field('output_base64sha512'),
      output_file_mode: resource.field('output_file_mode'),
      output_md5: resource.field('output_md5'),
      output_path: resource.field('output_path'),
      output_sha: resource.field('output_sha'),
      output_sha256: resource.field('output_sha256'),
      output_sha512: resource.field('output_sha512'),
      output_size: resource.field('output_size'),
      source_content: resource.field('source_content'),
      source_content_filename: resource.field('source_content_filename'),
      source_dir: resource.field('source_dir'),
      source_file: resource.field('source_file'),
      type: resource.field('type'),
    },
  },
  data: {
    local blockType = provider.blockType('data'),
    file(name, block): {
      local resource = blockType.resource('archive_file', name),
      _: resource._(block, {
        exclude_symlink_directories: build.template(std.get(block, 'exclude_symlink_directories', null)),
        excludes: build.template(std.get(block, 'excludes', null)),
        id: build.template(std.get(block, 'id', null)),
        output_base64sha256: build.template(std.get(block, 'output_base64sha256', null)),
        output_base64sha512: build.template(std.get(block, 'output_base64sha512', null)),
        output_file_mode: build.template(std.get(block, 'output_file_mode', null)),
        output_md5: build.template(std.get(block, 'output_md5', null)),
        output_path: build.template(block.output_path),
        output_sha: build.template(std.get(block, 'output_sha', null)),
        output_sha256: build.template(std.get(block, 'output_sha256', null)),
        output_sha512: build.template(std.get(block, 'output_sha512', null)),
        output_size: build.template(std.get(block, 'output_size', null)),
        source_content: build.template(std.get(block, 'source_content', null)),
        source_content_filename: build.template(std.get(block, 'source_content_filename', null)),
        source_dir: build.template(std.get(block, 'source_dir', null)),
        source_file: build.template(std.get(block, 'source_file', null)),
        type: build.template(block.type),
      }),
      exclude_symlink_directories: resource.field('exclude_symlink_directories'),
      excludes: resource.field('excludes'),
      id: resource.field('id'),
      output_base64sha256: resource.field('output_base64sha256'),
      output_base64sha512: resource.field('output_base64sha512'),
      output_file_mode: resource.field('output_file_mode'),
      output_md5: resource.field('output_md5'),
      output_path: resource.field('output_path'),
      output_sha: resource.field('output_sha'),
      output_sha256: resource.field('output_sha256'),
      output_sha512: resource.field('output_sha512'),
      output_size: resource.field('output_size'),
      source_content: resource.field('source_content'),
      source_content_filename: resource.field('source_content_filename'),
      source_dir: resource.field('source_dir'),
      source_file: resource.field('source_file'),
      type: resource.field('type'),
    },
  },
};

local providerWithConfiguration = provider(null) + {
  withConfiguration(alias, block): provider(std.prune({
    alias: alias,
  })),
};

providerWithConfiguration
