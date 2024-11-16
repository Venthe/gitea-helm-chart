# Runner only setup

```yaml values.yaml
persistence:
  enabled: true
  create: true
  mount: true
  claimName: gitea-shared-storage
  size: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClass: storageclassgoeshere

actions:
  enabled: true
  remoteInstanceUrl: "https://gitea.example.com/"
  statefulset:

    actRunner:
      repository: gitea/act_runner
      tag: 0.2.11
      pullPolicy: IfNotPresent
      config: |
        log:
          level: debug
        cache:
          enabled: true
        runner:
          labels:
            - "act-runner-host"
            - "gitea-ubuntu-latest:docker://gitea/runner-images:ubuntu-latest"
            - "catthehacker-ubuntu-22-04:docker://catthehacker/ubuntu:act-22.04"
            - "x86_64" # amd64
        container:
          options: |
            --add-host=docker:host-gateway -v /certs:/certs -e "DOCKER_HOST=tcp://docker:2376/" -e "DOCKER_TLS_CERTDIR=/certs" -e "DOCKER_TLS_VERIFY=1" -e "DOCKER_CERT_PATH=/certs/server"
          valid_volumes:
            - /certs
            - '**'


  provisioning:
    enabled: false
  existingSecret: "gitea-actions-secret"
  existingSecretKey: "token"

gitea:
  enabled: false
  config:
    #  APP_NAME: "Gitea: Git with a cup of tea"
    #  RUN_MODE: dev
    cache:
      ENABLED: false
    queue:
      ENABLED: false
    session:
      ENABLED: false
redis-cluster:
  enabled: false
redis:
  enabled: false
postgresql-ha:
  enabled: false
postgresql:
  enabled: false
checkDeprecation: true
```


```bash
$GITEA_ACTIONS_TOKEN="tokengoeshere"
kubectl create secret generic gitea-actions-secret --from-literal=token=$GITEA_ACTIONS_TOKEN
helm upgrade --install --dependency-update gitea-action-runners . -f values.yaml
```
