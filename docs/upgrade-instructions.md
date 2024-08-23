# Upgrading Default Gitea Chart

## Introduction

This document describes one of the ways to deal with breaking changnes in `gitea/helm-chart`.
This instructions may well crush your deployment. **Do not use** them, unless you know what
you are doing.

For the rest of the document, the chart is assumed to be in `gitea` namespace.

## Before 8.0.0 and after 9.0.0

Upgrades are rather strightforward normally. This simple command would work most of
the times for an increment of the major version:

```bash
$ helm upgrade --reuse-values -n gitea --version $NEXT_VERSION gitea gitea-charts/gitea
```

## To 8.0.0

`v8.0.0` introduces a big breaking change for the default configuration. A change to helm values
is required to keep things working. Let's go step by step. First, we upgrade to `v7.0.4`:

```bash
$ helm upgrade --reuse-values -n gitea --version ^7 gitea gitea-charts/gitea
```

It may be a good idea to get those used values back from `helm`:

```bash
$ helm get values gitea -n gitea > ./gitea-values-7.yaml
$ cp gitea-values-7.yaml gitea-values-8.yaml
```

Now, we need to retake ownership of postgres database from the chart to make it "external".
The first step is to get the necessary resources:


```bash
$ helm template -f gitea-values-7.yaml -n gitea --version ^7 gitea gitea-charts/gitea > postgres.yaml
$ echo '---' >> postgres.yaml
$ kubectl -n gitea get secret gitea-postgresql -o yaml >> postgres.yaml
```

The next step is a bit tricky, as we need to remove from `postgres.yaml` everything we don't need.
The remainder was 2 services, 1 statefulset and 1 secret for me.

When the "external" `postgres` definition is ready, we need to update values in `gitea-values-8.yaml`
to use it. These keys were needed in my case:

```yaml
gitea:
  config:
    database:
      DB_TYPE: postgres
      HOST: gitea-postgresql.gitea.svc.cluster.local:5432
      NAME: gitea
      USER: gitea
      PASSWD: gitea
      SCHEMA: public
postgresql:
  enabled: false
```

Now the upgrade:

```bash
$ helm upgrade -f gitea-values-8.yaml -n gitea --version ^8 gitea gitea-charts/gitea
$ kubectl apply -f postgres.yaml
```

## To 9.0.0

`v9.0.0` introduces another big breaking change for the default configuration. And another change to
helm values is required to keep things working. It is a good idea to upgrade to `v8.3.0` before going
any further.

We need to get ownership of `memcache` service.

```bash
$ helm template -f gitea-values-8.yaml -n gitea --version ^8 gitea gitea-charts/gitea > memcache.yaml
$ cp gitea-values-8.yaml gitea-values-9.yaml
```

The next step is again a bit tricky, as we need to remove from `memcache.yaml` everything we don't need.
The remainder was 1 service and 1 deployment for me. Then, we update the values to use the
"external" `memcache`. I needed to add these keys:

```yaml
gitea:
  config:
    cache:
      ADAPTER: memcache
      HOST: gitea-memcached.gitea.svc.cluster.local:11211
    queue:
      TYPE: channel
      CONN_STR: memcache://gitea-memcached.gitea.svc.cluster.local:11211/
    session:
      PROVIDER: memcache
      PROVIDER_CONFIG: gitea-memcached.gitea.svc.cluster.local:11211
persistence:
  mount: true
  create: false
  claimName: data-gitea-0
postgresql-ha:
  enabled: false
redis-cluster:
  enabled: false
redis:
  enabled: false
```

Now the upgrade:

```bash
$ helm upgrade -f gitea-values-9.yaml -n gitea --version 9.5.1 gitea gitea-charts/gitea
$ kubectl apply -f memcache.yaml
```
