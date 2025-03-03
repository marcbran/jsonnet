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
    source: 'registry.terraform.io/hashicorp/tfmigrate',
    version: '1.0.0',
  },
  local provider = providerTemplate('tfmigrate', requirements, configuration),
  resource: {
    local blockType = provider.blockType('resource'),
    git_commit_push(name, block): {
      local resource = blockType.resource('tfmigrate_git_commit_push', name),
      _: resource._(block, {
        branch_name: build.template(block.branch_name),
        commit_hash: build.template(std.get(block, 'commit_hash', null)),
        commit_message: build.template(block.commit_message),
        directory_path: build.template(block.directory_path),
        enable_push: build.template(block.enable_push),
        remote_name: build.template(block.remote_name),
        summary: build.template(std.get(block, 'summary', null)),
      }),
      branch_name: resource.field('branch_name'),
      commit_hash: resource.field('commit_hash'),
      commit_message: resource.field('commit_message'),
      directory_path: resource.field('directory_path'),
      enable_push: resource.field('enable_push'),
      remote_name: resource.field('remote_name'),
      summary: resource.field('summary'),
    },
    git_reset(name, block): {
      local resource = blockType.resource('tfmigrate_git_reset', name),
      _: resource._(block, {
        directory_path: build.template(block.directory_path),
      }),
      directory_path: resource.field('directory_path'),
    },
    github_pr(name, block): {
      local resource = blockType.resource('tfmigrate_github_pr', name),
      _: resource._(block, {
        destin_branch: build.template(block.destin_branch),
        pr_body: build.template(block.pr_body),
        pr_title: build.template(block.pr_title),
        pull_request_url: build.template(std.get(block, 'pull_request_url', null)),
        repo_identifier: build.template(block.repo_identifier),
        source_branch: build.template(block.source_branch),
        summary: build.template(std.get(block, 'summary', null)),
      }),
      destin_branch: resource.field('destin_branch'),
      pr_body: resource.field('pr_body'),
      pr_title: resource.field('pr_title'),
      pull_request_url: resource.field('pull_request_url'),
      repo_identifier: resource.field('repo_identifier'),
      source_branch: resource.field('source_branch'),
      summary: resource.field('summary'),
    },
    state_migration(name, block): {
      local resource = blockType.resource('tfmigrate_state_migration', name),
      _: resource._(block, {
        directory_path: build.template(block.directory_path),
        local_workspace: build.template(block.local_workspace),
        org: build.template(block.org),
        tfc_workspace: build.template(block.tfc_workspace),
      }),
      directory_path: resource.field('directory_path'),
      local_workspace: resource.field('local_workspace'),
      org: resource.field('org'),
      tfc_workspace: resource.field('tfc_workspace'),
    },
    terraform_init(name, block): {
      local resource = blockType.resource('tfmigrate_terraform_init', name),
      _: resource._(block, {
        directory_path: build.template(block.directory_path),
        summary: build.template(std.get(block, 'summary', null)),
      }),
      directory_path: resource.field('directory_path'),
      summary: resource.field('summary'),
    },
    terraform_plan(name, block): {
      local resource = blockType.resource('tfmigrate_terraform_plan', name),
      _: resource._(block, {
        directory_path: build.template(block.directory_path),
        summary: build.template(std.get(block, 'summary', null)),
      }),
      directory_path: resource.field('directory_path'),
      summary: resource.field('summary'),
    },
    update_backend(name, block): {
      local resource = blockType.resource('tfmigrate_update_backend', name),
      _: resource._(block, {
        backend_file_name: build.template(block.backend_file_name),
        directory_path: build.template(block.directory_path),
        org: build.template(block.org),
        project: build.template(block.project),
        tags: build.template(block.tags),
        workspace_map: build.template(block.workspace_map),
      }),
      backend_file_name: resource.field('backend_file_name'),
      directory_path: resource.field('directory_path'),
      org: resource.field('org'),
      project: resource.field('project'),
      tags: resource.field('tags'),
      workspace_map: resource.field('workspace_map'),
    },
  },
};

local providerWithConfiguration = provider(null) + {
  withConfiguration(alias, block): provider(std.prune({
    alias: alias,
    git_pat_token: build.template(std.get(block, 'git_pat_token', null)),
    hostname: build.template(std.get(block, 'hostname', null)),
  })),
};

providerWithConfiguration
