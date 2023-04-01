# High Availability

HA is currently not supported out-of-the box by the helm chart.

> **Warning** Setting `replicas` to a value > 1 will not result in a stable HA setup.

Also, the chart must first move from using a statefulset to a deployment to allow for multiple replicas with a shared PV.

Achieving a functional and robust HA setup is possible though it requires additional services and configuration work.

In a nutshell, the following capabilities are required:

- A HA-ready code indexer (`elasticsearch` or similar)
- A HA-ready external object storage (`minio`)
- A HA-ready memcache (e.g. `redis` or similar)
- DB: Postgres instead of SQLite
- A RWX file-system (e.g. NFS or EFS (AWS), or similar)

The default `memcached.enabled` and `postgres.enabled` settings in the chart should be set to `false` for a HA setup.
Instead, custom HA-ready deployments should be used.

The following sections discuss each of the services above, list potential services and their configuration.
Note that for each service discussed, possibly other implementations could be used and all shown configurations only provide a starting point, not necessarily the most optimal setup.

## Code indexer

If Gitea should run with multiple replicas, disabling the default `bleve` indexer is required by setting `REPO_INDEXER_ENABLED=false`.
It can be enabled *if* the indexer is HA-ready, for example when using `elasticsearch` or similar.

Possible options:

- [elasticsearch](https://bitnami.com/stack/elasticsearch/helm) (4-8 GB)
- [opensearch](https://artifacthub.io/packages/helm/opensearch-project-helm-charts/opensearch) (4-8 GB)
- **not supported yet**: [manticore](https://manticoresearch.com/blog/manticore-alternative-to-elasticsearch/) (faster than `elasticsearch` & friends, lower resource usage)
- **not supported yet**: [zinc](https://github.com/zinclabs/zinc) (no HA yet, low resource usage)
- **not supported yet**: [meilisearch](https://github.com/meilisearch/meilisearch)

The main issue with code indexes in a HA setup is their memory requirement.

```yml
gitea:
  config:
    indexer:
      ISSUE_INDEXER_TYPE: elasticsearch
      ISSUE_INDEXER_CONN_STR: http://${search-server}:9200
      REPO_INDEXER_ENABLED: true
      REPO_INDEXER_TYPE: elasticsearch
      REPO_INDEXER_CONN_STR: http://${search-server}:9200
```

## Memcache DB

Possible options:

- [redis](https://bitnami.com/stack/redis/helm)
- [keydb](https://artifacthub.io/packages/helm/enapter/keydb)

```yml
gitea:
  cache:
    builtIn:
      enabled: false
  config:
      cache:
      ADAPTER: redis
      ITEM_TTL: 72h

    queue:
      TYPE: redis

    session:
      PROVIDER: redis
      COOKIE_SECURE: true
```

## Object storage

Possible options:

- [minio](https://github.com/minio/minio/tree/master/helm/minio)

```yml
gitea:
  config:
    attachment:
      MAX_SIZE: 50
      STORAGE_TYPE: minio
    lfs:
      STORAGE_TYPE: minio
    picture:
      AVATAR_STORAGE_TYPE: minio
      REPOSITORY_AVATAR_STORAGE_TYPE: minio

    storage:
      MINIO_ENDPOINT: <s3 endpoint>
      MINIO_LOCATION: <location>
      MINIO_ACCESS_KEY_ID: <access key>
      MINIO_BUCKET: <bucket name>
      MINIO_USE_SSL: true

    storage.repo-archive:
      STORAGE_TYPE: minio
```

## Postgres DB

If you do not have an HA-ready Postgres DB, using a managed databases service of your cloud provider might be the easiest and most robust solution.

```yml
gitea:
  database:
    builtIn:
      postgresql:
        enabled: false
  config:
    database:
      DB_TYPE: postgres
      HOST: <host>
      NAME: <name>
      USER: <user>
```

## RWX file-system

Possible options:

- [EFS](https://aws.amazon.com/efs/) (AWS only)
- [NFS](https://github.com/kubernetes-sigs/nfs-ganesha-server-and-external-provisioner)
- [NFS file shares on Azure](https://docs.microsoft.com/en-us/azure/storage/files/files-nfs-protocol)

A RWX file-system also requires a custom storage class which references the RWX file-system.
You may need to decide between dynamic and static provisioning depending on the RWX backend.

## Known issues

Currently Cron jobs are run on all replicas as no leader election is implemented.
See https://github.com/go-gitea/gitea/issues/13791 for a discussion and possible solution.
