local build = {
  expression(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_') then
        if std.objectHas(val._, 'ref')
        then val._.ref
        else '"%s"' % [val._.str]
      else '{%s}' % [std.join(',', std.map(function(key) '%s:%s' % [self.expression(key), self.expression(val[key])], std.objectFields(val)))]
    else if std.type(val) == 'array' then '[%s]' % [std.join(',', std.map(function(element) self.expression(element), val))]
    else if std.type(val) == 'string' then '"%s"' % [val]
    else '"%s"' % [val],
  template(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_') then
        if std.objectHas(val._, 'ref')
        then std.strReplace(self.string(val), '\n', '\\n')
        else val._.str
      else std.mapWithKey(function(key, value) self.template(value), val)
    else if std.type(val) == 'array' then std.map(function(element) self.template(element), val)
    else if std.type(val) == 'string' then std.strReplace(self.string(val), '\n', '\\n')
    else val,
  string(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_') then
        if std.objectHas(val._, 'ref')
        then '${%s}' % [val._.ref]
        else val._.str
      else '${%s}' % [self.expression(val)]
    else if std.type(val) == 'array' then '${%s}' % [self.expression(val)]
    else if std.type(val) == 'string' then val
    else val,
  blocks(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_') then
        if std.objectHas(val._, 'blocks')
        then val._.blocks
        else
          if std.objectHas(val._, 'block')
          then { [val._.ref]: val._.block }
          else {}
      else std.foldl(
        function(acc, val) std.mergePatch(acc, val),
        std.map(function(key) build.blocks(val[key]), std.objectFields(val)),
        {}
      )
    else
      if std.type(val) == 'array' then std.foldl(
        function(acc, val) std.mergePatch(acc, val),
        std.map(function(element) build.blocks(element), val),
        {}
      )
      else {},
};
local providerTemplate(provider, requirements, rawConfiguration, configuration) = {
  local providerRequirements = { ['terraform.required_providers.%s' % [provider]]: requirements },
  local providerAlias = if configuration == null then null else std.get(configuration, 'alias', null),
  local providerConfiguration = if configuration == null then { _: { refBlock: {}, blocks: [] } } else {
    _: {
      local _ = self,
      ref: '%s.%s' % [provider, configuration.alias],
      refBlock: {
        provider: _.ref,
      },
      block: {
        provider: {
          provider: std.prune(configuration),
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
              [name]: providerConfiguration._.refBlock + metaBlock + block,
            },
          },
        },
        blocks: build.blocks([providerConfiguration] + [rawBlock]) + providerRequirements + { [_.ref]: _.block },
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
local attribute(block, name, required=false) = if !required && !std.objectHas(block, name) then {} else {
  [name]: build.template(block[name]),
};
local blockObj(block, name, body, nestingMode, required=false) = if !required && !std.objectHas(block, name) then {} else {
  [name]: if nestingMode == 'list' then [body(block) for block in block[name]] else body(block[name]),
};
local provider(rawConfiguration, configuration) = {
  local requirements = {
    source: 'registry.terraform.io/integrations/github',
    version: '6.6.0',
  },
  local provider = providerTemplate('github', requirements, rawConfiguration, configuration),
  resource: {
    local blockType = provider.blockType('resource'),
    actions_environment_secret(name, block): {
      local resource = blockType.resource('github_actions_environment_secret', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'encrypted_value') +
        attribute(block, 'environment', true) +
        attribute(block, 'id') +
        attribute(block, 'plaintext_value') +
        attribute(block, 'repository', true) +
        attribute(block, 'secret_name', true) +
        attribute(block, 'updated_at')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      encrypted_value: resource.field(self._.blocks, 'encrypted_value'),
      environment: resource.field(self._.blocks, 'environment'),
      id: resource.field(self._.blocks, 'id'),
      plaintext_value: resource.field(self._.blocks, 'plaintext_value'),
      repository: resource.field(self._.blocks, 'repository'),
      secret_name: resource.field(self._.blocks, 'secret_name'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    actions_environment_variable(name, block): {
      local resource = blockType.resource('github_actions_environment_variable', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'environment', true) +
        attribute(block, 'id') +
        attribute(block, 'repository', true) +
        attribute(block, 'updated_at') +
        attribute(block, 'value', true) +
        attribute(block, 'variable_name', true)
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      environment: resource.field(self._.blocks, 'environment'),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      value: resource.field(self._.blocks, 'value'),
      variable_name: resource.field(self._.blocks, 'variable_name'),
    },
    actions_organization_oidc_subject_claim_customization_template(name, block): {
      local resource = blockType.resource('github_actions_organization_oidc_subject_claim_customization_template', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'include_claim_keys', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      include_claim_keys: resource.field(self._.blocks, 'include_claim_keys'),
    },
    actions_organization_permissions(name, block): {
      local resource = blockType.resource('github_actions_organization_permissions', name),
      _: resource._(
        block,
        attribute(block, 'allowed_actions') +
        attribute(block, 'enabled_repositories', true) +
        attribute(block, 'id') +
        blockObj(block, 'allowed_actions_config', function(block)
          attribute(block, 'github_owned_allowed', true) +
          attribute(block, 'patterns_allowed') +
          attribute(block, 'verified_allowed'), 'list') +
        blockObj(block, 'enabled_repositories_config', function(block)
          attribute(block, 'repository_ids', true), 'list')
      ),
      allowed_actions: resource.field(self._.blocks, 'allowed_actions'),
      enabled_repositories: resource.field(self._.blocks, 'enabled_repositories'),
      id: resource.field(self._.blocks, 'id'),
    },
    actions_organization_secret(name, block): {
      local resource = blockType.resource('github_actions_organization_secret', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'encrypted_value') +
        attribute(block, 'id') +
        attribute(block, 'plaintext_value') +
        attribute(block, 'secret_name', true) +
        attribute(block, 'selected_repository_ids') +
        attribute(block, 'updated_at') +
        attribute(block, 'visibility', true)
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      encrypted_value: resource.field(self._.blocks, 'encrypted_value'),
      id: resource.field(self._.blocks, 'id'),
      plaintext_value: resource.field(self._.blocks, 'plaintext_value'),
      secret_name: resource.field(self._.blocks, 'secret_name'),
      selected_repository_ids: resource.field(self._.blocks, 'selected_repository_ids'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      visibility: resource.field(self._.blocks, 'visibility'),
    },
    actions_organization_secret_repositories(name, block): {
      local resource = blockType.resource('github_actions_organization_secret_repositories', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'secret_name', true) +
        attribute(block, 'selected_repository_ids', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      secret_name: resource.field(self._.blocks, 'secret_name'),
      selected_repository_ids: resource.field(self._.blocks, 'selected_repository_ids'),
    },
    actions_organization_variable(name, block): {
      local resource = blockType.resource('github_actions_organization_variable', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'selected_repository_ids') +
        attribute(block, 'updated_at') +
        attribute(block, 'value', true) +
        attribute(block, 'variable_name', true) +
        attribute(block, 'visibility', true)
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      selected_repository_ids: resource.field(self._.blocks, 'selected_repository_ids'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      value: resource.field(self._.blocks, 'value'),
      variable_name: resource.field(self._.blocks, 'variable_name'),
      visibility: resource.field(self._.blocks, 'visibility'),
    },
    actions_repository_access_level(name, block): {
      local resource = blockType.resource('github_actions_repository_access_level', name),
      _: resource._(
        block,
        attribute(block, 'access_level', true) +
        attribute(block, 'id') +
        attribute(block, 'repository', true)
      ),
      access_level: resource.field(self._.blocks, 'access_level'),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    actions_repository_oidc_subject_claim_customization_template(name, block): {
      local resource = blockType.resource('github_actions_repository_oidc_subject_claim_customization_template', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'include_claim_keys') +
        attribute(block, 'repository', true) +
        attribute(block, 'use_default', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      include_claim_keys: resource.field(self._.blocks, 'include_claim_keys'),
      repository: resource.field(self._.blocks, 'repository'),
      use_default: resource.field(self._.blocks, 'use_default'),
    },
    actions_repository_permissions(name, block): {
      local resource = blockType.resource('github_actions_repository_permissions', name),
      _: resource._(
        block,
        attribute(block, 'allowed_actions') +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'repository', true) +
        blockObj(block, 'allowed_actions_config', function(block)
          attribute(block, 'github_owned_allowed', true) +
          attribute(block, 'patterns_allowed') +
          attribute(block, 'verified_allowed'), 'list')
      ),
      allowed_actions: resource.field(self._.blocks, 'allowed_actions'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    actions_runner_group(name, block): {
      local resource = blockType.resource('github_actions_runner_group', name),
      _: resource._(
        block,
        attribute(block, 'allows_public_repositories') +
        attribute(block, 'default') +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'inherited') +
        attribute(block, 'name', true) +
        attribute(block, 'restricted_to_workflows') +
        attribute(block, 'runners_url') +
        attribute(block, 'selected_repositories_url') +
        attribute(block, 'selected_repository_ids') +
        attribute(block, 'selected_workflows') +
        attribute(block, 'visibility', true)
      ),
      allows_public_repositories: resource.field(self._.blocks, 'allows_public_repositories'),
      default: resource.field(self._.blocks, 'default'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      inherited: resource.field(self._.blocks, 'inherited'),
      name: resource.field(self._.blocks, 'name'),
      restricted_to_workflows: resource.field(self._.blocks, 'restricted_to_workflows'),
      runners_url: resource.field(self._.blocks, 'runners_url'),
      selected_repositories_url: resource.field(self._.blocks, 'selected_repositories_url'),
      selected_repository_ids: resource.field(self._.blocks, 'selected_repository_ids'),
      selected_workflows: resource.field(self._.blocks, 'selected_workflows'),
      visibility: resource.field(self._.blocks, 'visibility'),
    },
    actions_secret(name, block): {
      local resource = blockType.resource('github_actions_secret', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'encrypted_value') +
        attribute(block, 'id') +
        attribute(block, 'plaintext_value') +
        attribute(block, 'repository', true) +
        attribute(block, 'secret_name', true) +
        attribute(block, 'updated_at')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      encrypted_value: resource.field(self._.blocks, 'encrypted_value'),
      id: resource.field(self._.blocks, 'id'),
      plaintext_value: resource.field(self._.blocks, 'plaintext_value'),
      repository: resource.field(self._.blocks, 'repository'),
      secret_name: resource.field(self._.blocks, 'secret_name'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    actions_variable(name, block): {
      local resource = blockType.resource('github_actions_variable', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'repository', true) +
        attribute(block, 'updated_at') +
        attribute(block, 'value', true) +
        attribute(block, 'variable_name', true)
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      value: resource.field(self._.blocks, 'value'),
      variable_name: resource.field(self._.blocks, 'variable_name'),
    },
    app_installation_repositories(name, block): {
      local resource = blockType.resource('github_app_installation_repositories', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'installation_id', true) +
        attribute(block, 'selected_repositories', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      installation_id: resource.field(self._.blocks, 'installation_id'),
      selected_repositories: resource.field(self._.blocks, 'selected_repositories'),
    },
    app_installation_repository(name, block): {
      local resource = blockType.resource('github_app_installation_repository', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'installation_id', true) +
        attribute(block, 'repo_id') +
        attribute(block, 'repository', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      installation_id: resource.field(self._.blocks, 'installation_id'),
      repo_id: resource.field(self._.blocks, 'repo_id'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    branch(name, block): {
      local resource = blockType.resource('github_branch', name),
      _: resource._(
        block,
        attribute(block, 'branch', true) +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'ref') +
        attribute(block, 'repository', true) +
        attribute(block, 'sha') +
        attribute(block, 'source_branch') +
        attribute(block, 'source_sha')
      ),
      branch: resource.field(self._.blocks, 'branch'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      ref: resource.field(self._.blocks, 'ref'),
      repository: resource.field(self._.blocks, 'repository'),
      sha: resource.field(self._.blocks, 'sha'),
      source_branch: resource.field(self._.blocks, 'source_branch'),
      source_sha: resource.field(self._.blocks, 'source_sha'),
    },
    branch_default(name, block): {
      local resource = blockType.resource('github_branch_default', name),
      _: resource._(
        block,
        attribute(block, 'branch', true) +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'rename') +
        attribute(block, 'repository', true)
      ),
      branch: resource.field(self._.blocks, 'branch'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      rename: resource.field(self._.blocks, 'rename'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    branch_protection(name, block): {
      local resource = blockType.resource('github_branch_protection', name),
      _: resource._(
        block,
        attribute(block, 'allows_deletions') +
        attribute(block, 'allows_force_pushes') +
        attribute(block, 'enforce_admins') +
        attribute(block, 'force_push_bypassers') +
        attribute(block, 'id') +
        attribute(block, 'lock_branch') +
        attribute(block, 'pattern', true) +
        attribute(block, 'repository_id', true) +
        attribute(block, 'require_conversation_resolution') +
        attribute(block, 'require_signed_commits') +
        attribute(block, 'required_linear_history') +
        blockObj(block, 'required_pull_request_reviews', function(block)
          attribute(block, 'dismiss_stale_reviews') +
          attribute(block, 'dismissal_restrictions') +
          attribute(block, 'pull_request_bypassers') +
          attribute(block, 'require_code_owner_reviews') +
          attribute(block, 'require_last_push_approval') +
          attribute(block, 'required_approving_review_count') +
          attribute(block, 'restrict_dismissals'), 'list') +
        blockObj(block, 'required_status_checks', function(block)
          attribute(block, 'contexts') +
          attribute(block, 'strict'), 'list') +
        blockObj(block, 'restrict_pushes', function(block)
          attribute(block, 'blocks_creations') +
          attribute(block, 'push_allowances'), 'list')
      ),
      allows_deletions: resource.field(self._.blocks, 'allows_deletions'),
      allows_force_pushes: resource.field(self._.blocks, 'allows_force_pushes'),
      enforce_admins: resource.field(self._.blocks, 'enforce_admins'),
      force_push_bypassers: resource.field(self._.blocks, 'force_push_bypassers'),
      id: resource.field(self._.blocks, 'id'),
      lock_branch: resource.field(self._.blocks, 'lock_branch'),
      pattern: resource.field(self._.blocks, 'pattern'),
      repository_id: resource.field(self._.blocks, 'repository_id'),
      require_conversation_resolution: resource.field(self._.blocks, 'require_conversation_resolution'),
      require_signed_commits: resource.field(self._.blocks, 'require_signed_commits'),
      required_linear_history: resource.field(self._.blocks, 'required_linear_history'),
    },
    branch_protection_v3(name, block): {
      local resource = blockType.resource('github_branch_protection_v3', name),
      _: resource._(
        block,
        attribute(block, 'branch', true) +
        attribute(block, 'enforce_admins') +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'repository', true) +
        attribute(block, 'require_conversation_resolution') +
        attribute(block, 'require_signed_commits') +
        blockObj(block, 'required_pull_request_reviews', function(block)
          attribute(block, 'dismiss_stale_reviews') +
          attribute(block, 'dismissal_apps') +
          attribute(block, 'dismissal_teams') +
          attribute(block, 'dismissal_users') +
          attribute(block, 'include_admins') +
          attribute(block, 'require_code_owner_reviews') +
          attribute(block, 'require_last_push_approval') +
          attribute(block, 'required_approving_review_count') +
          blockObj(block, 'bypass_pull_request_allowances', function(block)
            attribute(block, 'apps') +
            attribute(block, 'teams') +
            attribute(block, 'users'), 'list'), 'list') +
        blockObj(block, 'required_status_checks', function(block)
          attribute(block, 'checks') +
          attribute(block, 'contexts') +
          attribute(block, 'include_admins') +
          attribute(block, 'strict'), 'list') +
        blockObj(block, 'restrictions', function(block)
          attribute(block, 'apps') +
          attribute(block, 'teams') +
          attribute(block, 'users'), 'list')
      ),
      branch: resource.field(self._.blocks, 'branch'),
      enforce_admins: resource.field(self._.blocks, 'enforce_admins'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
      require_conversation_resolution: resource.field(self._.blocks, 'require_conversation_resolution'),
      require_signed_commits: resource.field(self._.blocks, 'require_signed_commits'),
    },
    codespaces_organization_secret(name, block): {
      local resource = blockType.resource('github_codespaces_organization_secret', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'encrypted_value') +
        attribute(block, 'id') +
        attribute(block, 'plaintext_value') +
        attribute(block, 'secret_name', true) +
        attribute(block, 'selected_repository_ids') +
        attribute(block, 'updated_at') +
        attribute(block, 'visibility', true)
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      encrypted_value: resource.field(self._.blocks, 'encrypted_value'),
      id: resource.field(self._.blocks, 'id'),
      plaintext_value: resource.field(self._.blocks, 'plaintext_value'),
      secret_name: resource.field(self._.blocks, 'secret_name'),
      selected_repository_ids: resource.field(self._.blocks, 'selected_repository_ids'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      visibility: resource.field(self._.blocks, 'visibility'),
    },
    codespaces_organization_secret_repositories(name, block): {
      local resource = blockType.resource('github_codespaces_organization_secret_repositories', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'secret_name', true) +
        attribute(block, 'selected_repository_ids', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      secret_name: resource.field(self._.blocks, 'secret_name'),
      selected_repository_ids: resource.field(self._.blocks, 'selected_repository_ids'),
    },
    codespaces_secret(name, block): {
      local resource = blockType.resource('github_codespaces_secret', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'encrypted_value') +
        attribute(block, 'id') +
        attribute(block, 'plaintext_value') +
        attribute(block, 'repository', true) +
        attribute(block, 'secret_name', true) +
        attribute(block, 'updated_at')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      encrypted_value: resource.field(self._.blocks, 'encrypted_value'),
      id: resource.field(self._.blocks, 'id'),
      plaintext_value: resource.field(self._.blocks, 'plaintext_value'),
      repository: resource.field(self._.blocks, 'repository'),
      secret_name: resource.field(self._.blocks, 'secret_name'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    codespaces_user_secret(name, block): {
      local resource = blockType.resource('github_codespaces_user_secret', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'encrypted_value') +
        attribute(block, 'id') +
        attribute(block, 'plaintext_value') +
        attribute(block, 'secret_name', true) +
        attribute(block, 'selected_repository_ids') +
        attribute(block, 'updated_at')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      encrypted_value: resource.field(self._.blocks, 'encrypted_value'),
      id: resource.field(self._.blocks, 'id'),
      plaintext_value: resource.field(self._.blocks, 'plaintext_value'),
      secret_name: resource.field(self._.blocks, 'secret_name'),
      selected_repository_ids: resource.field(self._.blocks, 'selected_repository_ids'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    dependabot_organization_secret(name, block): {
      local resource = blockType.resource('github_dependabot_organization_secret', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'encrypted_value') +
        attribute(block, 'id') +
        attribute(block, 'plaintext_value') +
        attribute(block, 'secret_name', true) +
        attribute(block, 'selected_repository_ids') +
        attribute(block, 'updated_at') +
        attribute(block, 'visibility', true)
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      encrypted_value: resource.field(self._.blocks, 'encrypted_value'),
      id: resource.field(self._.blocks, 'id'),
      plaintext_value: resource.field(self._.blocks, 'plaintext_value'),
      secret_name: resource.field(self._.blocks, 'secret_name'),
      selected_repository_ids: resource.field(self._.blocks, 'selected_repository_ids'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      visibility: resource.field(self._.blocks, 'visibility'),
    },
    dependabot_organization_secret_repositories(name, block): {
      local resource = blockType.resource('github_dependabot_organization_secret_repositories', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'secret_name', true) +
        attribute(block, 'selected_repository_ids', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      secret_name: resource.field(self._.blocks, 'secret_name'),
      selected_repository_ids: resource.field(self._.blocks, 'selected_repository_ids'),
    },
    dependabot_secret(name, block): {
      local resource = blockType.resource('github_dependabot_secret', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'encrypted_value') +
        attribute(block, 'id') +
        attribute(block, 'plaintext_value') +
        attribute(block, 'repository', true) +
        attribute(block, 'secret_name', true) +
        attribute(block, 'updated_at')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      encrypted_value: resource.field(self._.blocks, 'encrypted_value'),
      id: resource.field(self._.blocks, 'id'),
      plaintext_value: resource.field(self._.blocks, 'plaintext_value'),
      repository: resource.field(self._.blocks, 'repository'),
      secret_name: resource.field(self._.blocks, 'secret_name'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    emu_group_mapping(name, block): {
      local resource = blockType.resource('github_emu_group_mapping', name),
      _: resource._(
        block,
        attribute(block, 'etag') +
        attribute(block, 'group_id', true) +
        attribute(block, 'id') +
        attribute(block, 'team_slug', true)
      ),
      etag: resource.field(self._.blocks, 'etag'),
      group_id: resource.field(self._.blocks, 'group_id'),
      id: resource.field(self._.blocks, 'id'),
      team_slug: resource.field(self._.blocks, 'team_slug'),
    },
    enterprise_actions_permissions(name, block): {
      local resource = blockType.resource('github_enterprise_actions_permissions', name),
      _: resource._(
        block,
        attribute(block, 'allowed_actions') +
        attribute(block, 'enabled_organizations', true) +
        attribute(block, 'enterprise_slug', true) +
        attribute(block, 'id') +
        blockObj(block, 'allowed_actions_config', function(block)
          attribute(block, 'github_owned_allowed', true) +
          attribute(block, 'patterns_allowed') +
          attribute(block, 'verified_allowed'), 'list') +
        blockObj(block, 'enabled_organizations_config', function(block)
          attribute(block, 'organization_ids', true), 'list')
      ),
      allowed_actions: resource.field(self._.blocks, 'allowed_actions'),
      enabled_organizations: resource.field(self._.blocks, 'enabled_organizations'),
      enterprise_slug: resource.field(self._.blocks, 'enterprise_slug'),
      id: resource.field(self._.blocks, 'id'),
    },
    enterprise_actions_runner_group(name, block): {
      local resource = blockType.resource('github_enterprise_actions_runner_group', name),
      _: resource._(
        block,
        attribute(block, 'allows_public_repositories') +
        attribute(block, 'default') +
        attribute(block, 'enterprise_slug', true) +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'restricted_to_workflows') +
        attribute(block, 'runners_url') +
        attribute(block, 'selected_organization_ids') +
        attribute(block, 'selected_organizations_url') +
        attribute(block, 'selected_workflows') +
        attribute(block, 'visibility', true)
      ),
      allows_public_repositories: resource.field(self._.blocks, 'allows_public_repositories'),
      default: resource.field(self._.blocks, 'default'),
      enterprise_slug: resource.field(self._.blocks, 'enterprise_slug'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      restricted_to_workflows: resource.field(self._.blocks, 'restricted_to_workflows'),
      runners_url: resource.field(self._.blocks, 'runners_url'),
      selected_organization_ids: resource.field(self._.blocks, 'selected_organization_ids'),
      selected_organizations_url: resource.field(self._.blocks, 'selected_organizations_url'),
      selected_workflows: resource.field(self._.blocks, 'selected_workflows'),
      visibility: resource.field(self._.blocks, 'visibility'),
    },
    enterprise_organization(name, block): {
      local resource = blockType.resource('github_enterprise_organization', name),
      _: resource._(
        block,
        attribute(block, 'admin_logins', true) +
        attribute(block, 'billing_email', true) +
        attribute(block, 'database_id') +
        attribute(block, 'description') +
        attribute(block, 'display_name') +
        attribute(block, 'enterprise_id', true) +
        attribute(block, 'id') +
        attribute(block, 'name', true)
      ),
      admin_logins: resource.field(self._.blocks, 'admin_logins'),
      billing_email: resource.field(self._.blocks, 'billing_email'),
      database_id: resource.field(self._.blocks, 'database_id'),
      description: resource.field(self._.blocks, 'description'),
      display_name: resource.field(self._.blocks, 'display_name'),
      enterprise_id: resource.field(self._.blocks, 'enterprise_id'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
    },
    issue(name, block): {
      local resource = blockType.resource('github_issue', name),
      _: resource._(
        block,
        attribute(block, 'assignees') +
        attribute(block, 'body') +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'issue_id') +
        attribute(block, 'labels') +
        attribute(block, 'milestone_number') +
        attribute(block, 'number') +
        attribute(block, 'repository', true) +
        attribute(block, 'title', true)
      ),
      assignees: resource.field(self._.blocks, 'assignees'),
      body: resource.field(self._.blocks, 'body'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      issue_id: resource.field(self._.blocks, 'issue_id'),
      labels: resource.field(self._.blocks, 'labels'),
      milestone_number: resource.field(self._.blocks, 'milestone_number'),
      number: resource.field(self._.blocks, 'number'),
      repository: resource.field(self._.blocks, 'repository'),
      title: resource.field(self._.blocks, 'title'),
    },
    issue_label(name, block): {
      local resource = blockType.resource('github_issue_label', name),
      _: resource._(
        block,
        attribute(block, 'color', true) +
        attribute(block, 'description') +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'repository', true) +
        attribute(block, 'url')
      ),
      color: resource.field(self._.blocks, 'color'),
      description: resource.field(self._.blocks, 'description'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      repository: resource.field(self._.blocks, 'repository'),
      url: resource.field(self._.blocks, 'url'),
    },
    issue_labels(name, block): {
      local resource = blockType.resource('github_issue_labels', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'repository', true) +
        blockObj(block, 'label', function(block)
          attribute(block, 'color', true) +
          attribute(block, 'description') +
          attribute(block, 'name', true) +
          attribute(block, 'url'), 'set')
      ),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    membership(name, block): {
      local resource = blockType.resource('github_membership', name),
      _: resource._(
        block,
        attribute(block, 'downgrade_on_destroy') +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'role') +
        attribute(block, 'username', true)
      ),
      downgrade_on_destroy: resource.field(self._.blocks, 'downgrade_on_destroy'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      role: resource.field(self._.blocks, 'role'),
      username: resource.field(self._.blocks, 'username'),
    },
    organization_block(name, block): {
      local resource = blockType.resource('github_organization_block', name),
      _: resource._(
        block,
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'username', true)
      ),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      username: resource.field(self._.blocks, 'username'),
    },
    organization_custom_role(name, block): {
      local resource = blockType.resource('github_organization_custom_role', name),
      _: resource._(
        block,
        attribute(block, 'base_role', true) +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'permissions', true)
      ),
      base_role: resource.field(self._.blocks, 'base_role'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      permissions: resource.field(self._.blocks, 'permissions'),
    },
    organization_project(name, block): {
      local resource = blockType.resource('github_organization_project', name),
      _: resource._(
        block,
        attribute(block, 'body') +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'url')
      ),
      body: resource.field(self._.blocks, 'body'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      url: resource.field(self._.blocks, 'url'),
    },
    organization_ruleset(name, block): {
      local resource = blockType.resource('github_organization_ruleset', name),
      _: resource._(
        block,
        attribute(block, 'enforcement', true) +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'node_id') +
        attribute(block, 'ruleset_id') +
        attribute(block, 'target', true) +
        blockObj(block, 'bypass_actors', function(block)
          attribute(block, 'actor_id', true) +
          attribute(block, 'actor_type', true) +
          attribute(block, 'bypass_mode', true), 'list') +
        blockObj(block, 'conditions', function(block)
          attribute(block, 'repository_id') +
          blockObj(block, 'ref_name', function(block)
            attribute(block, 'exclude', true) +
            attribute(block, 'include', true), 'list') +
          blockObj(block, 'repository_name', function(block)
            attribute(block, 'exclude', true) +
            attribute(block, 'include', true) +
            attribute(block, 'protected'), 'list'), 'list') +
        blockObj(block, 'rules', function(block)
          attribute(block, 'creation') +
          attribute(block, 'deletion') +
          attribute(block, 'non_fast_forward') +
          attribute(block, 'required_linear_history') +
          attribute(block, 'required_signatures') +
          attribute(block, 'update') +
          blockObj(block, 'branch_name_pattern', function(block)
            attribute(block, 'name') +
            attribute(block, 'negate') +
            attribute(block, 'operator', true) +
            attribute(block, 'pattern', true), 'list') +
          blockObj(block, 'commit_author_email_pattern', function(block)
            attribute(block, 'name') +
            attribute(block, 'negate') +
            attribute(block, 'operator', true) +
            attribute(block, 'pattern', true), 'list') +
          blockObj(block, 'commit_message_pattern', function(block)
            attribute(block, 'name') +
            attribute(block, 'negate') +
            attribute(block, 'operator', true) +
            attribute(block, 'pattern', true), 'list') +
          blockObj(block, 'committer_email_pattern', function(block)
            attribute(block, 'name') +
            attribute(block, 'negate') +
            attribute(block, 'operator', true) +
            attribute(block, 'pattern', true), 'list') +
          blockObj(block, 'pull_request', function(block)
            attribute(block, 'dismiss_stale_reviews_on_push') +
            attribute(block, 'require_code_owner_review') +
            attribute(block, 'require_last_push_approval') +
            attribute(block, 'required_approving_review_count') +
            attribute(block, 'required_review_thread_resolution'), 'list') +
          blockObj(block, 'required_code_scanning', function(block)
            blockObj(block, 'required_code_scanning_tool', function(block)
              attribute(block, 'alerts_threshold', true) +
              attribute(block, 'security_alerts_threshold', true) +
              attribute(block, 'tool', true), 'set'), 'list') +
          blockObj(block, 'required_status_checks', function(block)
            attribute(block, 'strict_required_status_checks_policy') +
            blockObj(block, 'required_check', function(block)
              attribute(block, 'context', true) +
              attribute(block, 'integration_id'), 'set'), 'list') +
          blockObj(block, 'required_workflows', function(block)
            blockObj(block, 'required_workflow', function(block)
              attribute(block, 'path', true) +
              attribute(block, 'ref') +
              attribute(block, 'repository_id', true), 'set'), 'list') +
          blockObj(block, 'tag_name_pattern', function(block)
            attribute(block, 'name') +
            attribute(block, 'negate') +
            attribute(block, 'operator', true) +
            attribute(block, 'pattern', true), 'list'), 'list')
      ),
      enforcement: resource.field(self._.blocks, 'enforcement'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      node_id: resource.field(self._.blocks, 'node_id'),
      ruleset_id: resource.field(self._.blocks, 'ruleset_id'),
      target: resource.field(self._.blocks, 'target'),
    },
    organization_security_manager(name, block): {
      local resource = blockType.resource('github_organization_security_manager', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'team_slug', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      team_slug: resource.field(self._.blocks, 'team_slug'),
    },
    organization_settings(name, block): {
      local resource = blockType.resource('github_organization_settings', name),
      _: resource._(
        block,
        attribute(block, 'advanced_security_enabled_for_new_repositories') +
        attribute(block, 'billing_email', true) +
        attribute(block, 'blog') +
        attribute(block, 'company') +
        attribute(block, 'default_repository_permission') +
        attribute(block, 'dependabot_alerts_enabled_for_new_repositories') +
        attribute(block, 'dependabot_security_updates_enabled_for_new_repositories') +
        attribute(block, 'dependency_graph_enabled_for_new_repositories') +
        attribute(block, 'description') +
        attribute(block, 'email') +
        attribute(block, 'has_organization_projects') +
        attribute(block, 'has_repository_projects') +
        attribute(block, 'id') +
        attribute(block, 'location') +
        attribute(block, 'members_can_create_internal_repositories') +
        attribute(block, 'members_can_create_pages') +
        attribute(block, 'members_can_create_private_pages') +
        attribute(block, 'members_can_create_private_repositories') +
        attribute(block, 'members_can_create_public_pages') +
        attribute(block, 'members_can_create_public_repositories') +
        attribute(block, 'members_can_create_repositories') +
        attribute(block, 'members_can_fork_private_repositories') +
        attribute(block, 'name') +
        attribute(block, 'secret_scanning_enabled_for_new_repositories') +
        attribute(block, 'secret_scanning_push_protection_enabled_for_new_repositories') +
        attribute(block, 'twitter_username') +
        attribute(block, 'web_commit_signoff_required')
      ),
      advanced_security_enabled_for_new_repositories: resource.field(self._.blocks, 'advanced_security_enabled_for_new_repositories'),
      billing_email: resource.field(self._.blocks, 'billing_email'),
      blog: resource.field(self._.blocks, 'blog'),
      company: resource.field(self._.blocks, 'company'),
      default_repository_permission: resource.field(self._.blocks, 'default_repository_permission'),
      dependabot_alerts_enabled_for_new_repositories: resource.field(self._.blocks, 'dependabot_alerts_enabled_for_new_repositories'),
      dependabot_security_updates_enabled_for_new_repositories: resource.field(self._.blocks, 'dependabot_security_updates_enabled_for_new_repositories'),
      dependency_graph_enabled_for_new_repositories: resource.field(self._.blocks, 'dependency_graph_enabled_for_new_repositories'),
      description: resource.field(self._.blocks, 'description'),
      email: resource.field(self._.blocks, 'email'),
      has_organization_projects: resource.field(self._.blocks, 'has_organization_projects'),
      has_repository_projects: resource.field(self._.blocks, 'has_repository_projects'),
      id: resource.field(self._.blocks, 'id'),
      location: resource.field(self._.blocks, 'location'),
      members_can_create_internal_repositories: resource.field(self._.blocks, 'members_can_create_internal_repositories'),
      members_can_create_pages: resource.field(self._.blocks, 'members_can_create_pages'),
      members_can_create_private_pages: resource.field(self._.blocks, 'members_can_create_private_pages'),
      members_can_create_private_repositories: resource.field(self._.blocks, 'members_can_create_private_repositories'),
      members_can_create_public_pages: resource.field(self._.blocks, 'members_can_create_public_pages'),
      members_can_create_public_repositories: resource.field(self._.blocks, 'members_can_create_public_repositories'),
      members_can_create_repositories: resource.field(self._.blocks, 'members_can_create_repositories'),
      members_can_fork_private_repositories: resource.field(self._.blocks, 'members_can_fork_private_repositories'),
      name: resource.field(self._.blocks, 'name'),
      secret_scanning_enabled_for_new_repositories: resource.field(self._.blocks, 'secret_scanning_enabled_for_new_repositories'),
      secret_scanning_push_protection_enabled_for_new_repositories: resource.field(self._.blocks, 'secret_scanning_push_protection_enabled_for_new_repositories'),
      twitter_username: resource.field(self._.blocks, 'twitter_username'),
      web_commit_signoff_required: resource.field(self._.blocks, 'web_commit_signoff_required'),
    },
    organization_webhook(name, block): {
      local resource = blockType.resource('github_organization_webhook', name),
      _: resource._(
        block,
        attribute(block, 'active') +
        attribute(block, 'etag') +
        attribute(block, 'events', true) +
        attribute(block, 'id') +
        attribute(block, 'url') +
        blockObj(block, 'configuration', function(block)
          attribute(block, 'content_type') +
          attribute(block, 'insecure_ssl') +
          attribute(block, 'secret') +
          attribute(block, 'url', true), 'list')
      ),
      active: resource.field(self._.blocks, 'active'),
      etag: resource.field(self._.blocks, 'etag'),
      events: resource.field(self._.blocks, 'events'),
      id: resource.field(self._.blocks, 'id'),
      url: resource.field(self._.blocks, 'url'),
    },
    project_card(name, block): {
      local resource = blockType.resource('github_project_card', name),
      _: resource._(
        block,
        attribute(block, 'card_id') +
        attribute(block, 'column_id', true) +
        attribute(block, 'content_id') +
        attribute(block, 'content_type') +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'note')
      ),
      card_id: resource.field(self._.blocks, 'card_id'),
      column_id: resource.field(self._.blocks, 'column_id'),
      content_id: resource.field(self._.blocks, 'content_id'),
      content_type: resource.field(self._.blocks, 'content_type'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      note: resource.field(self._.blocks, 'note'),
    },
    project_column(name, block): {
      local resource = blockType.resource('github_project_column', name),
      _: resource._(
        block,
        attribute(block, 'column_id') +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'project_id', true)
      ),
      column_id: resource.field(self._.blocks, 'column_id'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      project_id: resource.field(self._.blocks, 'project_id'),
    },
    release(name, block): {
      local resource = blockType.resource('github_release', name),
      _: resource._(
        block,
        attribute(block, 'assets_url') +
        attribute(block, 'body') +
        attribute(block, 'created_at') +
        attribute(block, 'discussion_category_name') +
        attribute(block, 'draft') +
        attribute(block, 'etag') +
        attribute(block, 'generate_release_notes') +
        attribute(block, 'html_url') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'node_id') +
        attribute(block, 'prerelease') +
        attribute(block, 'published_at') +
        attribute(block, 'release_id') +
        attribute(block, 'repository', true) +
        attribute(block, 'tag_name', true) +
        attribute(block, 'tarball_url') +
        attribute(block, 'target_commitish') +
        attribute(block, 'upload_url') +
        attribute(block, 'url') +
        attribute(block, 'zipball_url')
      ),
      assets_url: resource.field(self._.blocks, 'assets_url'),
      body: resource.field(self._.blocks, 'body'),
      created_at: resource.field(self._.blocks, 'created_at'),
      discussion_category_name: resource.field(self._.blocks, 'discussion_category_name'),
      draft: resource.field(self._.blocks, 'draft'),
      etag: resource.field(self._.blocks, 'etag'),
      generate_release_notes: resource.field(self._.blocks, 'generate_release_notes'),
      html_url: resource.field(self._.blocks, 'html_url'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      node_id: resource.field(self._.blocks, 'node_id'),
      prerelease: resource.field(self._.blocks, 'prerelease'),
      published_at: resource.field(self._.blocks, 'published_at'),
      release_id: resource.field(self._.blocks, 'release_id'),
      repository: resource.field(self._.blocks, 'repository'),
      tag_name: resource.field(self._.blocks, 'tag_name'),
      tarball_url: resource.field(self._.blocks, 'tarball_url'),
      target_commitish: resource.field(self._.blocks, 'target_commitish'),
      upload_url: resource.field(self._.blocks, 'upload_url'),
      url: resource.field(self._.blocks, 'url'),
      zipball_url: resource.field(self._.blocks, 'zipball_url'),
    },
    repository(name, block): {
      local resource = blockType.resource('github_repository', name),
      _: resource._(
        block,
        attribute(block, 'allow_auto_merge') +
        attribute(block, 'allow_merge_commit') +
        attribute(block, 'allow_rebase_merge') +
        attribute(block, 'allow_squash_merge') +
        attribute(block, 'allow_update_branch') +
        attribute(block, 'archive_on_destroy') +
        attribute(block, 'archived') +
        attribute(block, 'auto_init') +
        attribute(block, 'default_branch') +
        attribute(block, 'delete_branch_on_merge') +
        attribute(block, 'description') +
        attribute(block, 'etag') +
        attribute(block, 'full_name') +
        attribute(block, 'git_clone_url') +
        attribute(block, 'gitignore_template') +
        attribute(block, 'has_discussions') +
        attribute(block, 'has_downloads') +
        attribute(block, 'has_issues') +
        attribute(block, 'has_projects') +
        attribute(block, 'has_wiki') +
        attribute(block, 'homepage_url') +
        attribute(block, 'html_url') +
        attribute(block, 'http_clone_url') +
        attribute(block, 'id') +
        attribute(block, 'ignore_vulnerability_alerts_during_read') +
        attribute(block, 'is_template') +
        attribute(block, 'license_template') +
        attribute(block, 'merge_commit_message') +
        attribute(block, 'merge_commit_title') +
        attribute(block, 'name', true) +
        attribute(block, 'node_id') +
        attribute(block, 'primary_language') +
        attribute(block, 'private') +
        attribute(block, 'repo_id') +
        attribute(block, 'squash_merge_commit_message') +
        attribute(block, 'squash_merge_commit_title') +
        attribute(block, 'ssh_clone_url') +
        attribute(block, 'svn_url') +
        attribute(block, 'topics') +
        attribute(block, 'visibility') +
        attribute(block, 'vulnerability_alerts') +
        attribute(block, 'web_commit_signoff_required') +
        blockObj(block, 'pages', function(block)
          attribute(block, 'build_type') +
          attribute(block, 'cname') +
          attribute(block, 'custom_404') +
          attribute(block, 'html_url') +
          attribute(block, 'status') +
          attribute(block, 'url') +
          blockObj(block, 'source', function(block)
            attribute(block, 'branch', true) +
            attribute(block, 'path'), 'list'), 'list') +
        blockObj(block, 'security_and_analysis', function(block)
          blockObj(block, 'advanced_security', function(block)
            attribute(block, 'status', true), 'list') +
          blockObj(block, 'secret_scanning', function(block)
            attribute(block, 'status', true), 'list') +
          blockObj(block, 'secret_scanning_push_protection', function(block)
            attribute(block, 'status', true), 'list'), 'list') +
        blockObj(block, 'template', function(block)
          attribute(block, 'include_all_branches') +
          attribute(block, 'owner', true) +
          attribute(block, 'repository', true), 'list')
      ),
      allow_auto_merge: resource.field(self._.blocks, 'allow_auto_merge'),
      allow_merge_commit: resource.field(self._.blocks, 'allow_merge_commit'),
      allow_rebase_merge: resource.field(self._.blocks, 'allow_rebase_merge'),
      allow_squash_merge: resource.field(self._.blocks, 'allow_squash_merge'),
      allow_update_branch: resource.field(self._.blocks, 'allow_update_branch'),
      archive_on_destroy: resource.field(self._.blocks, 'archive_on_destroy'),
      archived: resource.field(self._.blocks, 'archived'),
      auto_init: resource.field(self._.blocks, 'auto_init'),
      default_branch: resource.field(self._.blocks, 'default_branch'),
      delete_branch_on_merge: resource.field(self._.blocks, 'delete_branch_on_merge'),
      description: resource.field(self._.blocks, 'description'),
      etag: resource.field(self._.blocks, 'etag'),
      full_name: resource.field(self._.blocks, 'full_name'),
      git_clone_url: resource.field(self._.blocks, 'git_clone_url'),
      gitignore_template: resource.field(self._.blocks, 'gitignore_template'),
      has_discussions: resource.field(self._.blocks, 'has_discussions'),
      has_downloads: resource.field(self._.blocks, 'has_downloads'),
      has_issues: resource.field(self._.blocks, 'has_issues'),
      has_projects: resource.field(self._.blocks, 'has_projects'),
      has_wiki: resource.field(self._.blocks, 'has_wiki'),
      homepage_url: resource.field(self._.blocks, 'homepage_url'),
      html_url: resource.field(self._.blocks, 'html_url'),
      http_clone_url: resource.field(self._.blocks, 'http_clone_url'),
      id: resource.field(self._.blocks, 'id'),
      ignore_vulnerability_alerts_during_read: resource.field(self._.blocks, 'ignore_vulnerability_alerts_during_read'),
      is_template: resource.field(self._.blocks, 'is_template'),
      license_template: resource.field(self._.blocks, 'license_template'),
      merge_commit_message: resource.field(self._.blocks, 'merge_commit_message'),
      merge_commit_title: resource.field(self._.blocks, 'merge_commit_title'),
      name: resource.field(self._.blocks, 'name'),
      node_id: resource.field(self._.blocks, 'node_id'),
      primary_language: resource.field(self._.blocks, 'primary_language'),
      private: resource.field(self._.blocks, 'private'),
      repo_id: resource.field(self._.blocks, 'repo_id'),
      squash_merge_commit_message: resource.field(self._.blocks, 'squash_merge_commit_message'),
      squash_merge_commit_title: resource.field(self._.blocks, 'squash_merge_commit_title'),
      ssh_clone_url: resource.field(self._.blocks, 'ssh_clone_url'),
      svn_url: resource.field(self._.blocks, 'svn_url'),
      topics: resource.field(self._.blocks, 'topics'),
      visibility: resource.field(self._.blocks, 'visibility'),
      vulnerability_alerts: resource.field(self._.blocks, 'vulnerability_alerts'),
      web_commit_signoff_required: resource.field(self._.blocks, 'web_commit_signoff_required'),
    },
    repository_autolink_reference(name, block): {
      local resource = blockType.resource('github_repository_autolink_reference', name),
      _: resource._(
        block,
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'is_alphanumeric') +
        attribute(block, 'key_prefix', true) +
        attribute(block, 'repository', true) +
        attribute(block, 'target_url_template', true)
      ),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      is_alphanumeric: resource.field(self._.blocks, 'is_alphanumeric'),
      key_prefix: resource.field(self._.blocks, 'key_prefix'),
      repository: resource.field(self._.blocks, 'repository'),
      target_url_template: resource.field(self._.blocks, 'target_url_template'),
    },
    repository_collaborator(name, block): {
      local resource = blockType.resource('github_repository_collaborator', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'invitation_id') +
        attribute(block, 'permission') +
        attribute(block, 'permission_diff_suppression') +
        attribute(block, 'repository', true) +
        attribute(block, 'username', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      invitation_id: resource.field(self._.blocks, 'invitation_id'),
      permission: resource.field(self._.blocks, 'permission'),
      permission_diff_suppression: resource.field(self._.blocks, 'permission_diff_suppression'),
      repository: resource.field(self._.blocks, 'repository'),
      username: resource.field(self._.blocks, 'username'),
    },
    repository_collaborators(name, block): {
      local resource = blockType.resource('github_repository_collaborators', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'invitation_ids') +
        attribute(block, 'repository', true) +
        blockObj(block, 'ignore_team', function(block)
          attribute(block, 'team_id', true), 'set') +
        blockObj(block, 'team', function(block)
          attribute(block, 'permission') +
          attribute(block, 'team_id', true), 'set') +
        blockObj(block, 'user', function(block)
          attribute(block, 'permission') +
          attribute(block, 'username', true), 'set')
      ),
      id: resource.field(self._.blocks, 'id'),
      invitation_ids: resource.field(self._.blocks, 'invitation_ids'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    repository_custom_property(name, block): {
      local resource = blockType.resource('github_repository_custom_property', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'property_name', true) +
        attribute(block, 'property_type', true) +
        attribute(block, 'property_value', true) +
        attribute(block, 'repository', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      property_name: resource.field(self._.blocks, 'property_name'),
      property_type: resource.field(self._.blocks, 'property_type'),
      property_value: resource.field(self._.blocks, 'property_value'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    repository_dependabot_security_updates(name, block): {
      local resource = blockType.resource('github_repository_dependabot_security_updates', name),
      _: resource._(
        block,
        attribute(block, 'enabled', true) +
        attribute(block, 'id') +
        attribute(block, 'repository', true)
      ),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    repository_deploy_key(name, block): {
      local resource = blockType.resource('github_repository_deploy_key', name),
      _: resource._(
        block,
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'key', true) +
        attribute(block, 'read_only') +
        attribute(block, 'repository', true) +
        attribute(block, 'title', true)
      ),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      key: resource.field(self._.blocks, 'key'),
      read_only: resource.field(self._.blocks, 'read_only'),
      repository: resource.field(self._.blocks, 'repository'),
      title: resource.field(self._.blocks, 'title'),
    },
    repository_deployment_branch_policy(name, block): {
      local resource = blockType.resource('github_repository_deployment_branch_policy', name),
      _: resource._(
        block,
        attribute(block, 'environment_name', true) +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'repository', true)
      ),
      environment_name: resource.field(self._.blocks, 'environment_name'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    repository_environment(name, block): {
      local resource = blockType.resource('github_repository_environment', name),
      _: resource._(
        block,
        attribute(block, 'can_admins_bypass') +
        attribute(block, 'environment', true) +
        attribute(block, 'id') +
        attribute(block, 'prevent_self_review') +
        attribute(block, 'repository', true) +
        attribute(block, 'wait_timer') +
        blockObj(block, 'deployment_branch_policy', function(block)
          attribute(block, 'custom_branch_policies', true) +
          attribute(block, 'protected_branches', true), 'list') +
        blockObj(block, 'reviewers', function(block)
          attribute(block, 'teams') +
          attribute(block, 'users'), 'list')
      ),
      can_admins_bypass: resource.field(self._.blocks, 'can_admins_bypass'),
      environment: resource.field(self._.blocks, 'environment'),
      id: resource.field(self._.blocks, 'id'),
      prevent_self_review: resource.field(self._.blocks, 'prevent_self_review'),
      repository: resource.field(self._.blocks, 'repository'),
      wait_timer: resource.field(self._.blocks, 'wait_timer'),
    },
    repository_environment_deployment_policy(name, block): {
      local resource = blockType.resource('github_repository_environment_deployment_policy', name),
      _: resource._(
        block,
        attribute(block, 'branch_pattern') +
        attribute(block, 'environment', true) +
        attribute(block, 'id') +
        attribute(block, 'repository', true) +
        attribute(block, 'tag_pattern')
      ),
      branch_pattern: resource.field(self._.blocks, 'branch_pattern'),
      environment: resource.field(self._.blocks, 'environment'),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
      tag_pattern: resource.field(self._.blocks, 'tag_pattern'),
    },
    repository_file(name, block): {
      local resource = blockType.resource('github_repository_file', name),
      _: resource._(
        block,
        attribute(block, 'autocreate_branch') +
        attribute(block, 'autocreate_branch_source_branch') +
        attribute(block, 'autocreate_branch_source_sha') +
        attribute(block, 'branch') +
        attribute(block, 'commit_author') +
        attribute(block, 'commit_email') +
        attribute(block, 'commit_message') +
        attribute(block, 'commit_sha') +
        attribute(block, 'content', true) +
        attribute(block, 'file', true) +
        attribute(block, 'id') +
        attribute(block, 'overwrite_on_create') +
        attribute(block, 'ref') +
        attribute(block, 'repository', true) +
        attribute(block, 'sha')
      ),
      autocreate_branch: resource.field(self._.blocks, 'autocreate_branch'),
      autocreate_branch_source_branch: resource.field(self._.blocks, 'autocreate_branch_source_branch'),
      autocreate_branch_source_sha: resource.field(self._.blocks, 'autocreate_branch_source_sha'),
      branch: resource.field(self._.blocks, 'branch'),
      commit_author: resource.field(self._.blocks, 'commit_author'),
      commit_email: resource.field(self._.blocks, 'commit_email'),
      commit_message: resource.field(self._.blocks, 'commit_message'),
      commit_sha: resource.field(self._.blocks, 'commit_sha'),
      content: resource.field(self._.blocks, 'content'),
      file: resource.field(self._.blocks, 'file'),
      id: resource.field(self._.blocks, 'id'),
      overwrite_on_create: resource.field(self._.blocks, 'overwrite_on_create'),
      ref: resource.field(self._.blocks, 'ref'),
      repository: resource.field(self._.blocks, 'repository'),
      sha: resource.field(self._.blocks, 'sha'),
    },
    repository_milestone(name, block): {
      local resource = blockType.resource('github_repository_milestone', name),
      _: resource._(
        block,
        attribute(block, 'description') +
        attribute(block, 'due_date') +
        attribute(block, 'id') +
        attribute(block, 'number') +
        attribute(block, 'owner', true) +
        attribute(block, 'repository', true) +
        attribute(block, 'state') +
        attribute(block, 'title', true)
      ),
      description: resource.field(self._.blocks, 'description'),
      due_date: resource.field(self._.blocks, 'due_date'),
      id: resource.field(self._.blocks, 'id'),
      number: resource.field(self._.blocks, 'number'),
      owner: resource.field(self._.blocks, 'owner'),
      repository: resource.field(self._.blocks, 'repository'),
      state: resource.field(self._.blocks, 'state'),
      title: resource.field(self._.blocks, 'title'),
    },
    repository_project(name, block): {
      local resource = blockType.resource('github_repository_project', name),
      _: resource._(
        block,
        attribute(block, 'body') +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'repository', true) +
        attribute(block, 'url')
      ),
      body: resource.field(self._.blocks, 'body'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      repository: resource.field(self._.blocks, 'repository'),
      url: resource.field(self._.blocks, 'url'),
    },
    repository_pull_request(name, block): {
      local resource = blockType.resource('github_repository_pull_request', name),
      _: resource._(
        block,
        attribute(block, 'base_ref', true) +
        attribute(block, 'base_repository', true) +
        attribute(block, 'base_sha') +
        attribute(block, 'body') +
        attribute(block, 'draft') +
        attribute(block, 'head_ref', true) +
        attribute(block, 'head_sha') +
        attribute(block, 'id') +
        attribute(block, 'labels') +
        attribute(block, 'maintainer_can_modify') +
        attribute(block, 'number') +
        attribute(block, 'opened_at') +
        attribute(block, 'opened_by') +
        attribute(block, 'owner') +
        attribute(block, 'state') +
        attribute(block, 'title', true) +
        attribute(block, 'updated_at')
      ),
      base_ref: resource.field(self._.blocks, 'base_ref'),
      base_repository: resource.field(self._.blocks, 'base_repository'),
      base_sha: resource.field(self._.blocks, 'base_sha'),
      body: resource.field(self._.blocks, 'body'),
      draft: resource.field(self._.blocks, 'draft'),
      head_ref: resource.field(self._.blocks, 'head_ref'),
      head_sha: resource.field(self._.blocks, 'head_sha'),
      id: resource.field(self._.blocks, 'id'),
      labels: resource.field(self._.blocks, 'labels'),
      maintainer_can_modify: resource.field(self._.blocks, 'maintainer_can_modify'),
      number: resource.field(self._.blocks, 'number'),
      opened_at: resource.field(self._.blocks, 'opened_at'),
      opened_by: resource.field(self._.blocks, 'opened_by'),
      owner: resource.field(self._.blocks, 'owner'),
      state: resource.field(self._.blocks, 'state'),
      title: resource.field(self._.blocks, 'title'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    repository_ruleset(name, block): {
      local resource = blockType.resource('github_repository_ruleset', name),
      _: resource._(
        block,
        attribute(block, 'enforcement', true) +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'node_id') +
        attribute(block, 'repository') +
        attribute(block, 'ruleset_id') +
        attribute(block, 'target', true) +
        blockObj(block, 'bypass_actors', function(block)
          attribute(block, 'actor_id', true) +
          attribute(block, 'actor_type', true) +
          attribute(block, 'bypass_mode', true), 'list') +
        blockObj(block, 'conditions', function(block)
          blockObj(block, 'ref_name', function(block)
            attribute(block, 'exclude', true) +
            attribute(block, 'include', true), 'list'), 'list') +
        blockObj(block, 'rules', function(block)
          attribute(block, 'creation') +
          attribute(block, 'deletion') +
          attribute(block, 'non_fast_forward') +
          attribute(block, 'required_linear_history') +
          attribute(block, 'required_signatures') +
          attribute(block, 'update') +
          attribute(block, 'update_allows_fetch_and_merge') +
          blockObj(block, 'branch_name_pattern', function(block)
            attribute(block, 'name') +
            attribute(block, 'negate') +
            attribute(block, 'operator', true) +
            attribute(block, 'pattern', true), 'list') +
          blockObj(block, 'commit_author_email_pattern', function(block)
            attribute(block, 'name') +
            attribute(block, 'negate') +
            attribute(block, 'operator', true) +
            attribute(block, 'pattern', true), 'list') +
          blockObj(block, 'commit_message_pattern', function(block)
            attribute(block, 'name') +
            attribute(block, 'negate') +
            attribute(block, 'operator', true) +
            attribute(block, 'pattern', true), 'list') +
          blockObj(block, 'committer_email_pattern', function(block)
            attribute(block, 'name') +
            attribute(block, 'negate') +
            attribute(block, 'operator', true) +
            attribute(block, 'pattern', true), 'list') +
          blockObj(block, 'merge_queue', function(block)
            attribute(block, 'check_response_timeout_minutes') +
            attribute(block, 'grouping_strategy') +
            attribute(block, 'max_entries_to_build') +
            attribute(block, 'max_entries_to_merge') +
            attribute(block, 'merge_method') +
            attribute(block, 'min_entries_to_merge') +
            attribute(block, 'min_entries_to_merge_wait_minutes'), 'list') +
          blockObj(block, 'pull_request', function(block)
            attribute(block, 'dismiss_stale_reviews_on_push') +
            attribute(block, 'require_code_owner_review') +
            attribute(block, 'require_last_push_approval') +
            attribute(block, 'required_approving_review_count') +
            attribute(block, 'required_review_thread_resolution'), 'list') +
          blockObj(block, 'required_code_scanning', function(block)
            blockObj(block, 'required_code_scanning_tool', function(block)
              attribute(block, 'alerts_threshold', true) +
              attribute(block, 'security_alerts_threshold', true) +
              attribute(block, 'tool', true), 'set'), 'list') +
          blockObj(block, 'required_deployments', function(block)
            attribute(block, 'required_deployment_environments', true), 'list') +
          blockObj(block, 'required_status_checks', function(block)
            attribute(block, 'do_not_enforce_on_create') +
            attribute(block, 'strict_required_status_checks_policy') +
            blockObj(block, 'required_check', function(block)
              attribute(block, 'context', true) +
              attribute(block, 'integration_id'), 'set'), 'list') +
          blockObj(block, 'tag_name_pattern', function(block)
            attribute(block, 'name') +
            attribute(block, 'negate') +
            attribute(block, 'operator', true) +
            attribute(block, 'pattern', true), 'list'), 'list')
      ),
      enforcement: resource.field(self._.blocks, 'enforcement'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      node_id: resource.field(self._.blocks, 'node_id'),
      repository: resource.field(self._.blocks, 'repository'),
      ruleset_id: resource.field(self._.blocks, 'ruleset_id'),
      target: resource.field(self._.blocks, 'target'),
    },
    repository_topics(name, block): {
      local resource = blockType.resource('github_repository_topics', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'repository', true) +
        attribute(block, 'topics', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
      topics: resource.field(self._.blocks, 'topics'),
    },
    repository_webhook(name, block): {
      local resource = blockType.resource('github_repository_webhook', name),
      _: resource._(
        block,
        attribute(block, 'active') +
        attribute(block, 'etag') +
        attribute(block, 'events', true) +
        attribute(block, 'id') +
        attribute(block, 'repository', true) +
        attribute(block, 'url') +
        blockObj(block, 'configuration', function(block)
          attribute(block, 'content_type') +
          attribute(block, 'insecure_ssl') +
          attribute(block, 'secret') +
          attribute(block, 'url', true), 'list')
      ),
      active: resource.field(self._.blocks, 'active'),
      etag: resource.field(self._.blocks, 'etag'),
      events: resource.field(self._.blocks, 'events'),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
      url: resource.field(self._.blocks, 'url'),
    },
    team(name, block): {
      local resource = blockType.resource('github_team', name),
      _: resource._(
        block,
        attribute(block, 'create_default_maintainer') +
        attribute(block, 'description') +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'ldap_dn') +
        attribute(block, 'members_count') +
        attribute(block, 'name', true) +
        attribute(block, 'node_id') +
        attribute(block, 'parent_team_id') +
        attribute(block, 'parent_team_read_id') +
        attribute(block, 'parent_team_read_slug') +
        attribute(block, 'privacy') +
        attribute(block, 'slug')
      ),
      create_default_maintainer: resource.field(self._.blocks, 'create_default_maintainer'),
      description: resource.field(self._.blocks, 'description'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      ldap_dn: resource.field(self._.blocks, 'ldap_dn'),
      members_count: resource.field(self._.blocks, 'members_count'),
      name: resource.field(self._.blocks, 'name'),
      node_id: resource.field(self._.blocks, 'node_id'),
      parent_team_id: resource.field(self._.blocks, 'parent_team_id'),
      parent_team_read_id: resource.field(self._.blocks, 'parent_team_read_id'),
      parent_team_read_slug: resource.field(self._.blocks, 'parent_team_read_slug'),
      privacy: resource.field(self._.blocks, 'privacy'),
      slug: resource.field(self._.blocks, 'slug'),
    },
    team_members(name, block): {
      local resource = blockType.resource('github_team_members', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'team_id', true) +
        blockObj(block, 'members', function(block)
          attribute(block, 'role') +
          attribute(block, 'username', true), 'set')
      ),
      id: resource.field(self._.blocks, 'id'),
      team_id: resource.field(self._.blocks, 'team_id'),
    },
    team_membership(name, block): {
      local resource = blockType.resource('github_team_membership', name),
      _: resource._(
        block,
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'role') +
        attribute(block, 'team_id', true) +
        attribute(block, 'username', true)
      ),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      role: resource.field(self._.blocks, 'role'),
      team_id: resource.field(self._.blocks, 'team_id'),
      username: resource.field(self._.blocks, 'username'),
    },
    team_repository(name, block): {
      local resource = blockType.resource('github_team_repository', name),
      _: resource._(
        block,
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'permission') +
        attribute(block, 'repository', true) +
        attribute(block, 'team_id', true)
      ),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      permission: resource.field(self._.blocks, 'permission'),
      repository: resource.field(self._.blocks, 'repository'),
      team_id: resource.field(self._.blocks, 'team_id'),
    },
    team_settings(name, block): {
      local resource = blockType.resource('github_team_settings', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'team_id', true) +
        attribute(block, 'team_slug') +
        attribute(block, 'team_uid') +
        blockObj(block, 'review_request_delegation', function(block)
          attribute(block, 'algorithm') +
          attribute(block, 'member_count') +
          attribute(block, 'notify'), 'list')
      ),
      id: resource.field(self._.blocks, 'id'),
      team_id: resource.field(self._.blocks, 'team_id'),
      team_slug: resource.field(self._.blocks, 'team_slug'),
      team_uid: resource.field(self._.blocks, 'team_uid'),
    },
    team_sync_group_mapping(name, block): {
      local resource = blockType.resource('github_team_sync_group_mapping', name),
      _: resource._(
        block,
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'team_slug', true) +
        blockObj(block, 'group', function(block)
          attribute(block, 'group_description', true) +
          attribute(block, 'group_id', true) +
          attribute(block, 'group_name', true), 'set')
      ),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      team_slug: resource.field(self._.blocks, 'team_slug'),
    },
    user_gpg_key(name, block): {
      local resource = blockType.resource('github_user_gpg_key', name),
      _: resource._(
        block,
        attribute(block, 'armored_public_key', true) +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'key_id')
      ),
      armored_public_key: resource.field(self._.blocks, 'armored_public_key'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      key_id: resource.field(self._.blocks, 'key_id'),
    },
    user_invitation_accepter(name, block): {
      local resource = blockType.resource('github_user_invitation_accepter', name),
      _: resource._(
        block,
        attribute(block, 'allow_empty_id') +
        attribute(block, 'id') +
        attribute(block, 'invitation_id')
      ),
      allow_empty_id: resource.field(self._.blocks, 'allow_empty_id'),
      id: resource.field(self._.blocks, 'id'),
      invitation_id: resource.field(self._.blocks, 'invitation_id'),
    },
    user_ssh_key(name, block): {
      local resource = blockType.resource('github_user_ssh_key', name),
      _: resource._(
        block,
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'key', true) +
        attribute(block, 'title', true) +
        attribute(block, 'url')
      ),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      key: resource.field(self._.blocks, 'key'),
      title: resource.field(self._.blocks, 'title'),
      url: resource.field(self._.blocks, 'url'),
    },
  },
  data: {
    local blockType = provider.blockType('data'),
    actions_environment_secrets(name, block): {
      local resource = blockType.resource('github_actions_environment_secrets', name),
      _: resource._(
        block,
        attribute(block, 'environment', true) +
        attribute(block, 'full_name') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'secrets')
      ),
      environment: resource.field(self._.blocks, 'environment'),
      full_name: resource.field(self._.blocks, 'full_name'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      secrets: resource.field(self._.blocks, 'secrets'),
    },
    actions_environment_variables(name, block): {
      local resource = blockType.resource('github_actions_environment_variables', name),
      _: resource._(
        block,
        attribute(block, 'environment', true) +
        attribute(block, 'full_name') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'variables')
      ),
      environment: resource.field(self._.blocks, 'environment'),
      full_name: resource.field(self._.blocks, 'full_name'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      variables: resource.field(self._.blocks, 'variables'),
    },
    actions_organization_oidc_subject_claim_customization_template(name, block): {
      local resource = blockType.resource('github_actions_organization_oidc_subject_claim_customization_template', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'include_claim_keys')
      ),
      id: resource.field(self._.blocks, 'id'),
      include_claim_keys: resource.field(self._.blocks, 'include_claim_keys'),
    },
    actions_organization_public_key(name, block): {
      local resource = blockType.resource('github_actions_organization_public_key', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'key') +
        attribute(block, 'key_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      key: resource.field(self._.blocks, 'key'),
      key_id: resource.field(self._.blocks, 'key_id'),
    },
    actions_organization_registration_token(name, block): {
      local resource = blockType.resource('github_actions_organization_registration_token', name),
      _: resource._(
        block,
        attribute(block, 'expires_at') +
        attribute(block, 'id') +
        attribute(block, 'token')
      ),
      expires_at: resource.field(self._.blocks, 'expires_at'),
      id: resource.field(self._.blocks, 'id'),
      token: resource.field(self._.blocks, 'token'),
    },
    actions_organization_secrets(name, block): {
      local resource = blockType.resource('github_actions_organization_secrets', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'secrets')
      ),
      id: resource.field(self._.blocks, 'id'),
      secrets: resource.field(self._.blocks, 'secrets'),
    },
    actions_organization_variables(name, block): {
      local resource = blockType.resource('github_actions_organization_variables', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'variables')
      ),
      id: resource.field(self._.blocks, 'id'),
      variables: resource.field(self._.blocks, 'variables'),
    },
    actions_public_key(name, block): {
      local resource = blockType.resource('github_actions_public_key', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'key') +
        attribute(block, 'key_id') +
        attribute(block, 'repository', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      key: resource.field(self._.blocks, 'key'),
      key_id: resource.field(self._.blocks, 'key_id'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    actions_registration_token(name, block): {
      local resource = blockType.resource('github_actions_registration_token', name),
      _: resource._(
        block,
        attribute(block, 'expires_at') +
        attribute(block, 'id') +
        attribute(block, 'repository', true) +
        attribute(block, 'token')
      ),
      expires_at: resource.field(self._.blocks, 'expires_at'),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
      token: resource.field(self._.blocks, 'token'),
    },
    actions_repository_oidc_subject_claim_customization_template(name, block): {
      local resource = blockType.resource('github_actions_repository_oidc_subject_claim_customization_template', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'include_claim_keys') +
        attribute(block, 'name', true) +
        attribute(block, 'use_default')
      ),
      id: resource.field(self._.blocks, 'id'),
      include_claim_keys: resource.field(self._.blocks, 'include_claim_keys'),
      name: resource.field(self._.blocks, 'name'),
      use_default: resource.field(self._.blocks, 'use_default'),
    },
    actions_secrets(name, block): {
      local resource = blockType.resource('github_actions_secrets', name),
      _: resource._(
        block,
        attribute(block, 'full_name') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'secrets')
      ),
      full_name: resource.field(self._.blocks, 'full_name'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      secrets: resource.field(self._.blocks, 'secrets'),
    },
    actions_variables(name, block): {
      local resource = blockType.resource('github_actions_variables', name),
      _: resource._(
        block,
        attribute(block, 'full_name') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'variables')
      ),
      full_name: resource.field(self._.blocks, 'full_name'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      variables: resource.field(self._.blocks, 'variables'),
    },
    app(name, block): {
      local resource = blockType.resource('github_app', name),
      _: resource._(
        block,
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'node_id') +
        attribute(block, 'slug', true)
      ),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      node_id: resource.field(self._.blocks, 'node_id'),
      slug: resource.field(self._.blocks, 'slug'),
    },
    app_token(name, block): {
      local resource = blockType.resource('github_app_token', name),
      _: resource._(
        block,
        attribute(block, 'app_id', true) +
        attribute(block, 'id') +
        attribute(block, 'installation_id', true) +
        attribute(block, 'pem_file', true) +
        attribute(block, 'token')
      ),
      app_id: resource.field(self._.blocks, 'app_id'),
      id: resource.field(self._.blocks, 'id'),
      installation_id: resource.field(self._.blocks, 'installation_id'),
      pem_file: resource.field(self._.blocks, 'pem_file'),
      token: resource.field(self._.blocks, 'token'),
    },
    branch(name, block): {
      local resource = blockType.resource('github_branch', name),
      _: resource._(
        block,
        attribute(block, 'branch', true) +
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'ref') +
        attribute(block, 'repository', true) +
        attribute(block, 'sha')
      ),
      branch: resource.field(self._.blocks, 'branch'),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      ref: resource.field(self._.blocks, 'ref'),
      repository: resource.field(self._.blocks, 'repository'),
      sha: resource.field(self._.blocks, 'sha'),
    },
    branch_protection_rules(name, block): {
      local resource = blockType.resource('github_branch_protection_rules', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'repository', true) +
        attribute(block, 'rules')
      ),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
      rules: resource.field(self._.blocks, 'rules'),
    },
    codespaces_organization_public_key(name, block): {
      local resource = blockType.resource('github_codespaces_organization_public_key', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'key') +
        attribute(block, 'key_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      key: resource.field(self._.blocks, 'key'),
      key_id: resource.field(self._.blocks, 'key_id'),
    },
    codespaces_organization_secrets(name, block): {
      local resource = blockType.resource('github_codespaces_organization_secrets', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'secrets')
      ),
      id: resource.field(self._.blocks, 'id'),
      secrets: resource.field(self._.blocks, 'secrets'),
    },
    codespaces_public_key(name, block): {
      local resource = blockType.resource('github_codespaces_public_key', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'key') +
        attribute(block, 'key_id') +
        attribute(block, 'repository', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      key: resource.field(self._.blocks, 'key'),
      key_id: resource.field(self._.blocks, 'key_id'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    codespaces_secrets(name, block): {
      local resource = blockType.resource('github_codespaces_secrets', name),
      _: resource._(
        block,
        attribute(block, 'full_name') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'secrets')
      ),
      full_name: resource.field(self._.blocks, 'full_name'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      secrets: resource.field(self._.blocks, 'secrets'),
    },
    codespaces_user_public_key(name, block): {
      local resource = blockType.resource('github_codespaces_user_public_key', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'key') +
        attribute(block, 'key_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      key: resource.field(self._.blocks, 'key'),
      key_id: resource.field(self._.blocks, 'key_id'),
    },
    codespaces_user_secrets(name, block): {
      local resource = blockType.resource('github_codespaces_user_secrets', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'secrets')
      ),
      id: resource.field(self._.blocks, 'id'),
      secrets: resource.field(self._.blocks, 'secrets'),
    },
    collaborators(name, block): {
      local resource = blockType.resource('github_collaborators', name),
      _: resource._(
        block,
        attribute(block, 'affiliation') +
        attribute(block, 'collaborator') +
        attribute(block, 'id') +
        attribute(block, 'owner', true) +
        attribute(block, 'permission') +
        attribute(block, 'repository', true)
      ),
      affiliation: resource.field(self._.blocks, 'affiliation'),
      collaborator: resource.field(self._.blocks, 'collaborator'),
      id: resource.field(self._.blocks, 'id'),
      owner: resource.field(self._.blocks, 'owner'),
      permission: resource.field(self._.blocks, 'permission'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    dependabot_organization_public_key(name, block): {
      local resource = blockType.resource('github_dependabot_organization_public_key', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'key') +
        attribute(block, 'key_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      key: resource.field(self._.blocks, 'key'),
      key_id: resource.field(self._.blocks, 'key_id'),
    },
    dependabot_organization_secrets(name, block): {
      local resource = blockType.resource('github_dependabot_organization_secrets', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'secrets')
      ),
      id: resource.field(self._.blocks, 'id'),
      secrets: resource.field(self._.blocks, 'secrets'),
    },
    dependabot_public_key(name, block): {
      local resource = blockType.resource('github_dependabot_public_key', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'key') +
        attribute(block, 'key_id') +
        attribute(block, 'repository', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      key: resource.field(self._.blocks, 'key'),
      key_id: resource.field(self._.blocks, 'key_id'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    dependabot_secrets(name, block): {
      local resource = blockType.resource('github_dependabot_secrets', name),
      _: resource._(
        block,
        attribute(block, 'full_name') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'secrets')
      ),
      full_name: resource.field(self._.blocks, 'full_name'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      secrets: resource.field(self._.blocks, 'secrets'),
    },
    enterprise(name, block): {
      local resource = blockType.resource('github_enterprise', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'database_id') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'slug', true) +
        attribute(block, 'url')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      database_id: resource.field(self._.blocks, 'database_id'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      slug: resource.field(self._.blocks, 'slug'),
      url: resource.field(self._.blocks, 'url'),
    },
    external_groups(name, block): {
      local resource = blockType.resource('github_external_groups', name),
      _: resource._(
        block,
        attribute(block, 'external_groups') +
        attribute(block, 'id')
      ),
      external_groups: resource.field(self._.blocks, 'external_groups'),
      id: resource.field(self._.blocks, 'id'),
    },
    ip_ranges(name, block): {
      local resource = blockType.resource('github_ip_ranges', name),
      _: resource._(
        block,
        attribute(block, 'actions') +
        attribute(block, 'actions_ipv4') +
        attribute(block, 'actions_ipv6') +
        attribute(block, 'api') +
        attribute(block, 'api_ipv4') +
        attribute(block, 'api_ipv6') +
        attribute(block, 'dependabot') +
        attribute(block, 'dependabot_ipv4') +
        attribute(block, 'dependabot_ipv6') +
        attribute(block, 'git') +
        attribute(block, 'git_ipv4') +
        attribute(block, 'git_ipv6') +
        attribute(block, 'hooks') +
        attribute(block, 'hooks_ipv4') +
        attribute(block, 'hooks_ipv6') +
        attribute(block, 'id') +
        attribute(block, 'importer') +
        attribute(block, 'importer_ipv4') +
        attribute(block, 'importer_ipv6') +
        attribute(block, 'packages') +
        attribute(block, 'packages_ipv4') +
        attribute(block, 'packages_ipv6') +
        attribute(block, 'pages') +
        attribute(block, 'pages_ipv4') +
        attribute(block, 'pages_ipv6') +
        attribute(block, 'web') +
        attribute(block, 'web_ipv4') +
        attribute(block, 'web_ipv6')
      ),
      actions: resource.field(self._.blocks, 'actions'),
      actions_ipv4: resource.field(self._.blocks, 'actions_ipv4'),
      actions_ipv6: resource.field(self._.blocks, 'actions_ipv6'),
      api: resource.field(self._.blocks, 'api'),
      api_ipv4: resource.field(self._.blocks, 'api_ipv4'),
      api_ipv6: resource.field(self._.blocks, 'api_ipv6'),
      dependabot: resource.field(self._.blocks, 'dependabot'),
      dependabot_ipv4: resource.field(self._.blocks, 'dependabot_ipv4'),
      dependabot_ipv6: resource.field(self._.blocks, 'dependabot_ipv6'),
      git: resource.field(self._.blocks, 'git'),
      git_ipv4: resource.field(self._.blocks, 'git_ipv4'),
      git_ipv6: resource.field(self._.blocks, 'git_ipv6'),
      hooks: resource.field(self._.blocks, 'hooks'),
      hooks_ipv4: resource.field(self._.blocks, 'hooks_ipv4'),
      hooks_ipv6: resource.field(self._.blocks, 'hooks_ipv6'),
      id: resource.field(self._.blocks, 'id'),
      importer: resource.field(self._.blocks, 'importer'),
      importer_ipv4: resource.field(self._.blocks, 'importer_ipv4'),
      importer_ipv6: resource.field(self._.blocks, 'importer_ipv6'),
      packages: resource.field(self._.blocks, 'packages'),
      packages_ipv4: resource.field(self._.blocks, 'packages_ipv4'),
      packages_ipv6: resource.field(self._.blocks, 'packages_ipv6'),
      pages: resource.field(self._.blocks, 'pages'),
      pages_ipv4: resource.field(self._.blocks, 'pages_ipv4'),
      pages_ipv6: resource.field(self._.blocks, 'pages_ipv6'),
      web: resource.field(self._.blocks, 'web'),
      web_ipv4: resource.field(self._.blocks, 'web_ipv4'),
      web_ipv6: resource.field(self._.blocks, 'web_ipv6'),
    },
    issue_labels(name, block): {
      local resource = blockType.resource('github_issue_labels', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'labels') +
        attribute(block, 'repository', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      labels: resource.field(self._.blocks, 'labels'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    membership(name, block): {
      local resource = blockType.resource('github_membership', name),
      _: resource._(
        block,
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'organization') +
        attribute(block, 'role') +
        attribute(block, 'state') +
        attribute(block, 'username', true)
      ),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      organization: resource.field(self._.blocks, 'organization'),
      role: resource.field(self._.blocks, 'role'),
      state: resource.field(self._.blocks, 'state'),
      username: resource.field(self._.blocks, 'username'),
    },
    organization(name, block): {
      local resource = blockType.resource('github_organization', name),
      _: resource._(
        block,
        attribute(block, 'advanced_security_enabled_for_new_repositories') +
        attribute(block, 'default_repository_permission') +
        attribute(block, 'dependabot_alerts_enabled_for_new_repositories') +
        attribute(block, 'dependabot_security_updates_enabled_for_new_repositories') +
        attribute(block, 'dependency_graph_enabled_for_new_repositories') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'ignore_archived_repos') +
        attribute(block, 'login') +
        attribute(block, 'members') +
        attribute(block, 'members_allowed_repository_creation_type') +
        attribute(block, 'members_can_create_internal_repositories') +
        attribute(block, 'members_can_create_pages') +
        attribute(block, 'members_can_create_private_pages') +
        attribute(block, 'members_can_create_private_repositories') +
        attribute(block, 'members_can_create_public_pages') +
        attribute(block, 'members_can_create_public_repositories') +
        attribute(block, 'members_can_create_repositories') +
        attribute(block, 'members_can_fork_private_repositories') +
        attribute(block, 'name', true) +
        attribute(block, 'node_id') +
        attribute(block, 'orgname') +
        attribute(block, 'plan') +
        attribute(block, 'repositories') +
        attribute(block, 'secret_scanning_enabled_for_new_repositories') +
        attribute(block, 'secret_scanning_push_protection_enabled_for_new_repositories') +
        attribute(block, 'summary_only') +
        attribute(block, 'two_factor_requirement_enabled') +
        attribute(block, 'users') +
        attribute(block, 'web_commit_signoff_required')
      ),
      advanced_security_enabled_for_new_repositories: resource.field(self._.blocks, 'advanced_security_enabled_for_new_repositories'),
      default_repository_permission: resource.field(self._.blocks, 'default_repository_permission'),
      dependabot_alerts_enabled_for_new_repositories: resource.field(self._.blocks, 'dependabot_alerts_enabled_for_new_repositories'),
      dependabot_security_updates_enabled_for_new_repositories: resource.field(self._.blocks, 'dependabot_security_updates_enabled_for_new_repositories'),
      dependency_graph_enabled_for_new_repositories: resource.field(self._.blocks, 'dependency_graph_enabled_for_new_repositories'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      ignore_archived_repos: resource.field(self._.blocks, 'ignore_archived_repos'),
      login: resource.field(self._.blocks, 'login'),
      members: resource.field(self._.blocks, 'members'),
      members_allowed_repository_creation_type: resource.field(self._.blocks, 'members_allowed_repository_creation_type'),
      members_can_create_internal_repositories: resource.field(self._.blocks, 'members_can_create_internal_repositories'),
      members_can_create_pages: resource.field(self._.blocks, 'members_can_create_pages'),
      members_can_create_private_pages: resource.field(self._.blocks, 'members_can_create_private_pages'),
      members_can_create_private_repositories: resource.field(self._.blocks, 'members_can_create_private_repositories'),
      members_can_create_public_pages: resource.field(self._.blocks, 'members_can_create_public_pages'),
      members_can_create_public_repositories: resource.field(self._.blocks, 'members_can_create_public_repositories'),
      members_can_create_repositories: resource.field(self._.blocks, 'members_can_create_repositories'),
      members_can_fork_private_repositories: resource.field(self._.blocks, 'members_can_fork_private_repositories'),
      name: resource.field(self._.blocks, 'name'),
      node_id: resource.field(self._.blocks, 'node_id'),
      orgname: resource.field(self._.blocks, 'orgname'),
      plan: resource.field(self._.blocks, 'plan'),
      repositories: resource.field(self._.blocks, 'repositories'),
      secret_scanning_enabled_for_new_repositories: resource.field(self._.blocks, 'secret_scanning_enabled_for_new_repositories'),
      secret_scanning_push_protection_enabled_for_new_repositories: resource.field(self._.blocks, 'secret_scanning_push_protection_enabled_for_new_repositories'),
      summary_only: resource.field(self._.blocks, 'summary_only'),
      two_factor_requirement_enabled: resource.field(self._.blocks, 'two_factor_requirement_enabled'),
      users: resource.field(self._.blocks, 'users'),
      web_commit_signoff_required: resource.field(self._.blocks, 'web_commit_signoff_required'),
    },
    organization_custom_role(name, block): {
      local resource = blockType.resource('github_organization_custom_role', name),
      _: resource._(
        block,
        attribute(block, 'base_role') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'permissions')
      ),
      base_role: resource.field(self._.blocks, 'base_role'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      permissions: resource.field(self._.blocks, 'permissions'),
    },
    organization_external_identities(name, block): {
      local resource = blockType.resource('github_organization_external_identities', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'identities')
      ),
      id: resource.field(self._.blocks, 'id'),
      identities: resource.field(self._.blocks, 'identities'),
    },
    organization_ip_allow_list(name, block): {
      local resource = blockType.resource('github_organization_ip_allow_list', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'ip_allow_list')
      ),
      id: resource.field(self._.blocks, 'id'),
      ip_allow_list: resource.field(self._.blocks, 'ip_allow_list'),
    },
    organization_team_sync_groups(name, block): {
      local resource = blockType.resource('github_organization_team_sync_groups', name),
      _: resource._(
        block,
        attribute(block, 'groups') +
        attribute(block, 'id')
      ),
      groups: resource.field(self._.blocks, 'groups'),
      id: resource.field(self._.blocks, 'id'),
    },
    organization_teams(name, block): {
      local resource = blockType.resource('github_organization_teams', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'results_per_page') +
        attribute(block, 'root_teams_only') +
        attribute(block, 'summary_only') +
        attribute(block, 'teams')
      ),
      id: resource.field(self._.blocks, 'id'),
      results_per_page: resource.field(self._.blocks, 'results_per_page'),
      root_teams_only: resource.field(self._.blocks, 'root_teams_only'),
      summary_only: resource.field(self._.blocks, 'summary_only'),
      teams: resource.field(self._.blocks, 'teams'),
    },
    organization_webhooks(name, block): {
      local resource = blockType.resource('github_organization_webhooks', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'webhooks')
      ),
      id: resource.field(self._.blocks, 'id'),
      webhooks: resource.field(self._.blocks, 'webhooks'),
    },
    ref(name, block): {
      local resource = blockType.resource('github_ref', name),
      _: resource._(
        block,
        attribute(block, 'etag') +
        attribute(block, 'id') +
        attribute(block, 'owner') +
        attribute(block, 'ref', true) +
        attribute(block, 'repository', true) +
        attribute(block, 'sha')
      ),
      etag: resource.field(self._.blocks, 'etag'),
      id: resource.field(self._.blocks, 'id'),
      owner: resource.field(self._.blocks, 'owner'),
      ref: resource.field(self._.blocks, 'ref'),
      repository: resource.field(self._.blocks, 'repository'),
      sha: resource.field(self._.blocks, 'sha'),
    },
    release(name, block): {
      local resource = blockType.resource('github_release', name),
      _: resource._(
        block,
        attribute(block, 'asserts_url') +
        attribute(block, 'assets') +
        attribute(block, 'assets_url') +
        attribute(block, 'body') +
        attribute(block, 'created_at') +
        attribute(block, 'draft') +
        attribute(block, 'html_url') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'owner', true) +
        attribute(block, 'prerelease') +
        attribute(block, 'published_at') +
        attribute(block, 'release_id') +
        attribute(block, 'release_tag') +
        attribute(block, 'repository', true) +
        attribute(block, 'retrieve_by', true) +
        attribute(block, 'tarball_url') +
        attribute(block, 'target_commitish') +
        attribute(block, 'upload_url') +
        attribute(block, 'url') +
        attribute(block, 'zipball_url')
      ),
      asserts_url: resource.field(self._.blocks, 'asserts_url'),
      assets: resource.field(self._.blocks, 'assets'),
      assets_url: resource.field(self._.blocks, 'assets_url'),
      body: resource.field(self._.blocks, 'body'),
      created_at: resource.field(self._.blocks, 'created_at'),
      draft: resource.field(self._.blocks, 'draft'),
      html_url: resource.field(self._.blocks, 'html_url'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      owner: resource.field(self._.blocks, 'owner'),
      prerelease: resource.field(self._.blocks, 'prerelease'),
      published_at: resource.field(self._.blocks, 'published_at'),
      release_id: resource.field(self._.blocks, 'release_id'),
      release_tag: resource.field(self._.blocks, 'release_tag'),
      repository: resource.field(self._.blocks, 'repository'),
      retrieve_by: resource.field(self._.blocks, 'retrieve_by'),
      tarball_url: resource.field(self._.blocks, 'tarball_url'),
      target_commitish: resource.field(self._.blocks, 'target_commitish'),
      upload_url: resource.field(self._.blocks, 'upload_url'),
      url: resource.field(self._.blocks, 'url'),
      zipball_url: resource.field(self._.blocks, 'zipball_url'),
    },
    repositories(name, block): {
      local resource = blockType.resource('github_repositories', name),
      _: resource._(
        block,
        attribute(block, 'full_names') +
        attribute(block, 'id') +
        attribute(block, 'include_repo_id') +
        attribute(block, 'names') +
        attribute(block, 'query', true) +
        attribute(block, 'repo_ids') +
        attribute(block, 'results_per_page') +
        attribute(block, 'sort')
      ),
      full_names: resource.field(self._.blocks, 'full_names'),
      id: resource.field(self._.blocks, 'id'),
      include_repo_id: resource.field(self._.blocks, 'include_repo_id'),
      names: resource.field(self._.blocks, 'names'),
      query: resource.field(self._.blocks, 'query'),
      repo_ids: resource.field(self._.blocks, 'repo_ids'),
      results_per_page: resource.field(self._.blocks, 'results_per_page'),
      sort: resource.field(self._.blocks, 'sort'),
    },
    repository(name, block): {
      local resource = blockType.resource('github_repository', name),
      _: resource._(
        block,
        attribute(block, 'allow_auto_merge') +
        attribute(block, 'allow_merge_commit') +
        attribute(block, 'allow_rebase_merge') +
        attribute(block, 'allow_squash_merge') +
        attribute(block, 'allow_update_branch') +
        attribute(block, 'archived') +
        attribute(block, 'default_branch') +
        attribute(block, 'delete_branch_on_merge') +
        attribute(block, 'description') +
        attribute(block, 'fork') +
        attribute(block, 'full_name') +
        attribute(block, 'git_clone_url') +
        attribute(block, 'has_discussions') +
        attribute(block, 'has_downloads') +
        attribute(block, 'has_issues') +
        attribute(block, 'has_projects') +
        attribute(block, 'has_wiki') +
        attribute(block, 'homepage_url') +
        attribute(block, 'html_url') +
        attribute(block, 'http_clone_url') +
        attribute(block, 'id') +
        attribute(block, 'is_template') +
        attribute(block, 'merge_commit_message') +
        attribute(block, 'merge_commit_title') +
        attribute(block, 'name') +
        attribute(block, 'node_id') +
        attribute(block, 'pages') +
        attribute(block, 'primary_language') +
        attribute(block, 'private') +
        attribute(block, 'repo_id') +
        attribute(block, 'repository_license') +
        attribute(block, 'squash_merge_commit_message') +
        attribute(block, 'squash_merge_commit_title') +
        attribute(block, 'ssh_clone_url') +
        attribute(block, 'svn_url') +
        attribute(block, 'template') +
        attribute(block, 'topics') +
        attribute(block, 'visibility')
      ),
      allow_auto_merge: resource.field(self._.blocks, 'allow_auto_merge'),
      allow_merge_commit: resource.field(self._.blocks, 'allow_merge_commit'),
      allow_rebase_merge: resource.field(self._.blocks, 'allow_rebase_merge'),
      allow_squash_merge: resource.field(self._.blocks, 'allow_squash_merge'),
      allow_update_branch: resource.field(self._.blocks, 'allow_update_branch'),
      archived: resource.field(self._.blocks, 'archived'),
      default_branch: resource.field(self._.blocks, 'default_branch'),
      delete_branch_on_merge: resource.field(self._.blocks, 'delete_branch_on_merge'),
      description: resource.field(self._.blocks, 'description'),
      fork: resource.field(self._.blocks, 'fork'),
      full_name: resource.field(self._.blocks, 'full_name'),
      git_clone_url: resource.field(self._.blocks, 'git_clone_url'),
      has_discussions: resource.field(self._.blocks, 'has_discussions'),
      has_downloads: resource.field(self._.blocks, 'has_downloads'),
      has_issues: resource.field(self._.blocks, 'has_issues'),
      has_projects: resource.field(self._.blocks, 'has_projects'),
      has_wiki: resource.field(self._.blocks, 'has_wiki'),
      homepage_url: resource.field(self._.blocks, 'homepage_url'),
      html_url: resource.field(self._.blocks, 'html_url'),
      http_clone_url: resource.field(self._.blocks, 'http_clone_url'),
      id: resource.field(self._.blocks, 'id'),
      is_template: resource.field(self._.blocks, 'is_template'),
      merge_commit_message: resource.field(self._.blocks, 'merge_commit_message'),
      merge_commit_title: resource.field(self._.blocks, 'merge_commit_title'),
      name: resource.field(self._.blocks, 'name'),
      node_id: resource.field(self._.blocks, 'node_id'),
      pages: resource.field(self._.blocks, 'pages'),
      primary_language: resource.field(self._.blocks, 'primary_language'),
      private: resource.field(self._.blocks, 'private'),
      repo_id: resource.field(self._.blocks, 'repo_id'),
      repository_license: resource.field(self._.blocks, 'repository_license'),
      squash_merge_commit_message: resource.field(self._.blocks, 'squash_merge_commit_message'),
      squash_merge_commit_title: resource.field(self._.blocks, 'squash_merge_commit_title'),
      ssh_clone_url: resource.field(self._.blocks, 'ssh_clone_url'),
      svn_url: resource.field(self._.blocks, 'svn_url'),
      template: resource.field(self._.blocks, 'template'),
      topics: resource.field(self._.blocks, 'topics'),
      visibility: resource.field(self._.blocks, 'visibility'),
    },
    repository_autolink_references(name, block): {
      local resource = blockType.resource('github_repository_autolink_references', name),
      _: resource._(
        block,
        attribute(block, 'autolink_references') +
        attribute(block, 'id') +
        attribute(block, 'repository', true)
      ),
      autolink_references: resource.field(self._.blocks, 'autolink_references'),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    repository_branches(name, block): {
      local resource = blockType.resource('github_repository_branches', name),
      _: resource._(
        block,
        attribute(block, 'branches') +
        attribute(block, 'id') +
        attribute(block, 'only_non_protected_branches') +
        attribute(block, 'only_protected_branches') +
        attribute(block, 'repository', true)
      ),
      branches: resource.field(self._.blocks, 'branches'),
      id: resource.field(self._.blocks, 'id'),
      only_non_protected_branches: resource.field(self._.blocks, 'only_non_protected_branches'),
      only_protected_branches: resource.field(self._.blocks, 'only_protected_branches'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    repository_custom_properties(name, block): {
      local resource = blockType.resource('github_repository_custom_properties', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'property') +
        attribute(block, 'repository', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      property: resource.field(self._.blocks, 'property'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    repository_deploy_keys(name, block): {
      local resource = blockType.resource('github_repository_deploy_keys', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'keys') +
        attribute(block, 'repository', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      keys: resource.field(self._.blocks, 'keys'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    repository_deployment_branch_policies(name, block): {
      local resource = blockType.resource('github_repository_deployment_branch_policies', name),
      _: resource._(
        block,
        attribute(block, 'deployment_branch_policies') +
        attribute(block, 'environment_name', true) +
        attribute(block, 'id') +
        attribute(block, 'repository', true)
      ),
      deployment_branch_policies: resource.field(self._.blocks, 'deployment_branch_policies'),
      environment_name: resource.field(self._.blocks, 'environment_name'),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    repository_environments(name, block): {
      local resource = blockType.resource('github_repository_environments', name),
      _: resource._(
        block,
        attribute(block, 'environments') +
        attribute(block, 'id') +
        attribute(block, 'repository', true)
      ),
      environments: resource.field(self._.blocks, 'environments'),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
    },
    repository_file(name, block): {
      local resource = blockType.resource('github_repository_file', name),
      _: resource._(
        block,
        attribute(block, 'branch') +
        attribute(block, 'commit_author') +
        attribute(block, 'commit_email') +
        attribute(block, 'commit_message') +
        attribute(block, 'commit_sha') +
        attribute(block, 'content') +
        attribute(block, 'file', true) +
        attribute(block, 'id') +
        attribute(block, 'ref') +
        attribute(block, 'repository', true) +
        attribute(block, 'sha')
      ),
      branch: resource.field(self._.blocks, 'branch'),
      commit_author: resource.field(self._.blocks, 'commit_author'),
      commit_email: resource.field(self._.blocks, 'commit_email'),
      commit_message: resource.field(self._.blocks, 'commit_message'),
      commit_sha: resource.field(self._.blocks, 'commit_sha'),
      content: resource.field(self._.blocks, 'content'),
      file: resource.field(self._.blocks, 'file'),
      id: resource.field(self._.blocks, 'id'),
      ref: resource.field(self._.blocks, 'ref'),
      repository: resource.field(self._.blocks, 'repository'),
      sha: resource.field(self._.blocks, 'sha'),
    },
    repository_milestone(name, block): {
      local resource = blockType.resource('github_repository_milestone', name),
      _: resource._(
        block,
        attribute(block, 'description') +
        attribute(block, 'due_date') +
        attribute(block, 'id') +
        attribute(block, 'number', true) +
        attribute(block, 'owner', true) +
        attribute(block, 'repository', true) +
        attribute(block, 'state') +
        attribute(block, 'title')
      ),
      description: resource.field(self._.blocks, 'description'),
      due_date: resource.field(self._.blocks, 'due_date'),
      id: resource.field(self._.blocks, 'id'),
      number: resource.field(self._.blocks, 'number'),
      owner: resource.field(self._.blocks, 'owner'),
      repository: resource.field(self._.blocks, 'repository'),
      state: resource.field(self._.blocks, 'state'),
      title: resource.field(self._.blocks, 'title'),
    },
    repository_pull_request(name, block): {
      local resource = blockType.resource('github_repository_pull_request', name),
      _: resource._(
        block,
        attribute(block, 'base_ref') +
        attribute(block, 'base_repository', true) +
        attribute(block, 'base_sha') +
        attribute(block, 'body') +
        attribute(block, 'draft') +
        attribute(block, 'head_owner') +
        attribute(block, 'head_ref') +
        attribute(block, 'head_repository') +
        attribute(block, 'head_sha') +
        attribute(block, 'id') +
        attribute(block, 'labels') +
        attribute(block, 'maintainer_can_modify') +
        attribute(block, 'number', true) +
        attribute(block, 'opened_at') +
        attribute(block, 'opened_by') +
        attribute(block, 'owner') +
        attribute(block, 'state') +
        attribute(block, 'title') +
        attribute(block, 'updated_at')
      ),
      base_ref: resource.field(self._.blocks, 'base_ref'),
      base_repository: resource.field(self._.blocks, 'base_repository'),
      base_sha: resource.field(self._.blocks, 'base_sha'),
      body: resource.field(self._.blocks, 'body'),
      draft: resource.field(self._.blocks, 'draft'),
      head_owner: resource.field(self._.blocks, 'head_owner'),
      head_ref: resource.field(self._.blocks, 'head_ref'),
      head_repository: resource.field(self._.blocks, 'head_repository'),
      head_sha: resource.field(self._.blocks, 'head_sha'),
      id: resource.field(self._.blocks, 'id'),
      labels: resource.field(self._.blocks, 'labels'),
      maintainer_can_modify: resource.field(self._.blocks, 'maintainer_can_modify'),
      number: resource.field(self._.blocks, 'number'),
      opened_at: resource.field(self._.blocks, 'opened_at'),
      opened_by: resource.field(self._.blocks, 'opened_by'),
      owner: resource.field(self._.blocks, 'owner'),
      state: resource.field(self._.blocks, 'state'),
      title: resource.field(self._.blocks, 'title'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    repository_pull_requests(name, block): {
      local resource = blockType.resource('github_repository_pull_requests', name),
      _: resource._(
        block,
        attribute(block, 'base_ref') +
        attribute(block, 'base_repository', true) +
        attribute(block, 'head_ref') +
        attribute(block, 'id') +
        attribute(block, 'owner') +
        attribute(block, 'results') +
        attribute(block, 'sort_by') +
        attribute(block, 'sort_direction') +
        attribute(block, 'state')
      ),
      base_ref: resource.field(self._.blocks, 'base_ref'),
      base_repository: resource.field(self._.blocks, 'base_repository'),
      head_ref: resource.field(self._.blocks, 'head_ref'),
      id: resource.field(self._.blocks, 'id'),
      owner: resource.field(self._.blocks, 'owner'),
      results: resource.field(self._.blocks, 'results'),
      sort_by: resource.field(self._.blocks, 'sort_by'),
      sort_direction: resource.field(self._.blocks, 'sort_direction'),
      state: resource.field(self._.blocks, 'state'),
    },
    repository_teams(name, block): {
      local resource = blockType.resource('github_repository_teams', name),
      _: resource._(
        block,
        attribute(block, 'full_name') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'teams')
      ),
      full_name: resource.field(self._.blocks, 'full_name'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      teams: resource.field(self._.blocks, 'teams'),
    },
    repository_webhooks(name, block): {
      local resource = blockType.resource('github_repository_webhooks', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'repository', true) +
        attribute(block, 'webhooks')
      ),
      id: resource.field(self._.blocks, 'id'),
      repository: resource.field(self._.blocks, 'repository'),
      webhooks: resource.field(self._.blocks, 'webhooks'),
    },
    rest_api(name, block): {
      local resource = blockType.resource('github_rest_api', name),
      _: resource._(
        block,
        attribute(block, 'body') +
        attribute(block, 'code') +
        attribute(block, 'endpoint', true) +
        attribute(block, 'headers') +
        attribute(block, 'id') +
        attribute(block, 'status')
      ),
      body: resource.field(self._.blocks, 'body'),
      code: resource.field(self._.blocks, 'code'),
      endpoint: resource.field(self._.blocks, 'endpoint'),
      headers: resource.field(self._.blocks, 'headers'),
      id: resource.field(self._.blocks, 'id'),
      status: resource.field(self._.blocks, 'status'),
    },
    ssh_keys(name, block): {
      local resource = blockType.resource('github_ssh_keys', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'keys')
      ),
      id: resource.field(self._.blocks, 'id'),
      keys: resource.field(self._.blocks, 'keys'),
    },
    team(name, block): {
      local resource = blockType.resource('github_team', name),
      _: resource._(
        block,
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'members') +
        attribute(block, 'membership_type') +
        attribute(block, 'name') +
        attribute(block, 'node_id') +
        attribute(block, 'permission') +
        attribute(block, 'privacy') +
        attribute(block, 'repositories') +
        attribute(block, 'repositories_detailed') +
        attribute(block, 'results_per_page') +
        attribute(block, 'slug', true) +
        attribute(block, 'summary_only')
      ),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      members: resource.field(self._.blocks, 'members'),
      membership_type: resource.field(self._.blocks, 'membership_type'),
      name: resource.field(self._.blocks, 'name'),
      node_id: resource.field(self._.blocks, 'node_id'),
      permission: resource.field(self._.blocks, 'permission'),
      privacy: resource.field(self._.blocks, 'privacy'),
      repositories: resource.field(self._.blocks, 'repositories'),
      repositories_detailed: resource.field(self._.blocks, 'repositories_detailed'),
      results_per_page: resource.field(self._.blocks, 'results_per_page'),
      slug: resource.field(self._.blocks, 'slug'),
      summary_only: resource.field(self._.blocks, 'summary_only'),
    },
    tree(name, block): {
      local resource = blockType.resource('github_tree', name),
      _: resource._(
        block,
        attribute(block, 'entries') +
        attribute(block, 'id') +
        attribute(block, 'recursive') +
        attribute(block, 'repository', true) +
        attribute(block, 'tree_sha', true)
      ),
      entries: resource.field(self._.blocks, 'entries'),
      id: resource.field(self._.blocks, 'id'),
      recursive: resource.field(self._.blocks, 'recursive'),
      repository: resource.field(self._.blocks, 'repository'),
      tree_sha: resource.field(self._.blocks, 'tree_sha'),
    },
    user(name, block): {
      local resource = blockType.resource('github_user', name),
      _: resource._(
        block,
        attribute(block, 'avatar_url') +
        attribute(block, 'bio') +
        attribute(block, 'blog') +
        attribute(block, 'company') +
        attribute(block, 'created_at') +
        attribute(block, 'email') +
        attribute(block, 'followers') +
        attribute(block, 'following') +
        attribute(block, 'gpg_keys') +
        attribute(block, 'gravatar_id') +
        attribute(block, 'id') +
        attribute(block, 'location') +
        attribute(block, 'login') +
        attribute(block, 'name') +
        attribute(block, 'node_id') +
        attribute(block, 'public_gists') +
        attribute(block, 'public_repos') +
        attribute(block, 'site_admin') +
        attribute(block, 'ssh_keys') +
        attribute(block, 'suspended_at') +
        attribute(block, 'updated_at') +
        attribute(block, 'username', true)
      ),
      avatar_url: resource.field(self._.blocks, 'avatar_url'),
      bio: resource.field(self._.blocks, 'bio'),
      blog: resource.field(self._.blocks, 'blog'),
      company: resource.field(self._.blocks, 'company'),
      created_at: resource.field(self._.blocks, 'created_at'),
      email: resource.field(self._.blocks, 'email'),
      followers: resource.field(self._.blocks, 'followers'),
      following: resource.field(self._.blocks, 'following'),
      gpg_keys: resource.field(self._.blocks, 'gpg_keys'),
      gravatar_id: resource.field(self._.blocks, 'gravatar_id'),
      id: resource.field(self._.blocks, 'id'),
      location: resource.field(self._.blocks, 'location'),
      login: resource.field(self._.blocks, 'login'),
      name: resource.field(self._.blocks, 'name'),
      node_id: resource.field(self._.blocks, 'node_id'),
      public_gists: resource.field(self._.blocks, 'public_gists'),
      public_repos: resource.field(self._.blocks, 'public_repos'),
      site_admin: resource.field(self._.blocks, 'site_admin'),
      ssh_keys: resource.field(self._.blocks, 'ssh_keys'),
      suspended_at: resource.field(self._.blocks, 'suspended_at'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      username: resource.field(self._.blocks, 'username'),
    },
    user_external_identity(name, block): {
      local resource = blockType.resource('github_user_external_identity', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'login') +
        attribute(block, 'saml_identity') +
        attribute(block, 'scim_identity') +
        attribute(block, 'username', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      login: resource.field(self._.blocks, 'login'),
      saml_identity: resource.field(self._.blocks, 'saml_identity'),
      scim_identity: resource.field(self._.blocks, 'scim_identity'),
      username: resource.field(self._.blocks, 'username'),
    },
    users(name, block): {
      local resource = blockType.resource('github_users', name),
      _: resource._(
        block,
        attribute(block, 'emails') +
        attribute(block, 'id') +
        attribute(block, 'logins') +
        attribute(block, 'node_ids') +
        attribute(block, 'unknown_logins') +
        attribute(block, 'usernames', true)
      ),
      emails: resource.field(self._.blocks, 'emails'),
      id: resource.field(self._.blocks, 'id'),
      logins: resource.field(self._.blocks, 'logins'),
      node_ids: resource.field(self._.blocks, 'node_ids'),
      unknown_logins: resource.field(self._.blocks, 'unknown_logins'),
      usernames: resource.field(self._.blocks, 'usernames'),
    },
  },
};
local providerWithConfiguration = provider(null, null) + {
  withConfiguration(alias, block): provider(block, {
    alias: alias,
    base_url: build.template(std.get(block, 'base_url', null)),
    insecure: build.template(std.get(block, 'insecure', null)),
    max_retries: build.template(std.get(block, 'max_retries', null)),
    organization: build.template(std.get(block, 'organization', null)),
    owner: build.template(std.get(block, 'owner', null)),
    parallel_requests: build.template(std.get(block, 'parallel_requests', null)),
    read_delay_ms: build.template(std.get(block, 'read_delay_ms', null)),
    retry_delay_ms: build.template(std.get(block, 'retry_delay_ms', null)),
    retryable_errors: build.template(std.get(block, 'retryable_errors', null)),
    token: build.template(std.get(block, 'token', null)),
    write_delay_ms: build.template(std.get(block, 'write_delay_ms', null)),
  }),
};
providerWithConfiguration
