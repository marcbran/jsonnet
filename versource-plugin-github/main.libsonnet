{
  adapters: {
    user(resource): resource {
      name: super.data.username,
      data: super.data {
        ssh_keys:: null,
      },
    },
    organization(resource): resource {
      name: super.data.login,
      data: super.data {
        members:: null,
        repositories:: null,
        users:: null,
      },
    },
    repository(resource): resource {
      namespace: std.split(super.data.full_name, '/')[0],
      name: std.split(super.data.full_name, '/')[1],
      data: super.data {
        repository_license:: null,
      },
    },
  },
  views: {
    repository: {
      web: |||
        SELECT
            CONCAT('github-repository-web-', uuid) as uid,
            CONCAT_WS('/', NULLIF(namespace, ''), name) as title,
            `data`->>"$.html_url" as arg
        FROM `resources`
        WHERE provider = "github"
        AND resource_type = "repository"
        LIMIT 1000
      |||,
    },
  },
  projections: {
    user(resource): [
      {
        provider: 'github',
        providerAlias: null,
        namespace: '%s/%s' % [resource.namespace, resource.name],
        resourceType: 'page',
        name: 'profile',
        data: {
          url: 'https://github.com/%s' % resource.data.username,
        },
      },
    ],
    organization(resource): [
      {
        provider: 'github',
        providerAlias: null,
        namespace: '%s/%s' % [resource.namespace, resource.name],
        resourceType: 'page',
        name: 'main',
        data: {
          url: 'https://github.com/%s' % resource.data.orgname,
        },
      },
    ],
    repository(resource):
      local pages = [
        { path: '', name: 'repo' },
        { path: '/issues', name: 'issues' },
        { path: '/pulls', name: 'pull-requests' },
        { path: '/actions', name: 'actions' },
      ];
      [
        {
          provider: 'github',
          providerAlias: null,
          namespace: '%s/%s' % [resource.namespace, resource.name],
          resourceType: 'page',
          name: page.name,
          data: {
            url: '%s%s' % [resource.data.html_url, page.path],
          },
        }
        for page in pages
      ],
  },
}
