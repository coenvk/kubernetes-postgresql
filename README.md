# Postgres Kubernetes cluster with Pgpool-II Load Balancer

This repository provides `YAML` files to deploy a Postgres cluster on Kubernetes. The cluster is managed by the
CrunchyData Postgres Operator (PGO) v5. PGO ensures replication and automatic failover. Pgpool-II provides connection
pooling and query load balancing. Any write queries are directed to the master database instance while read queries are
load balanced across all instances.

---

## Prerequisites

Before running the Postgres cluster, the following dependencies are required:
- A Kubernetes cluster with `kubectl` installed.

For this project, a cluster was initialized with minikube. Minikube can be started as follows:

```shell
minikube start
```

## Architecture
![architecture](docs/kubernetes.jpg)

## Configuration

### Number of database replicas
Some configuration of this setup can be adjusted to your needs. Depending on how many replicas are required, the value for `spec.instances.replicas` in `postgres/postgres.yaml` can be edited. Note that a value of 1 means that there is only a master database.
Based on how many replicas are defined, the load balance ratio (for read queries) should be redefined. Ideally, we want each database instance to receive the same amount of read queries. For instance, for a master and two slaves (so `spec.instances.replicas` is set to 3), 33% of the read queries should go to the master service and 67% goes to the slave service. This is defined in `pgpool/pgpool-configmap.yaml` under `data.pgpool.conf` as:

```yaml
database_redirect_preference_list = postgres:standby(0.67),hippo:standby(0.67)
```

### Database initialization with Liquibase
Initially, the database is empty. It does not contain any tables. A Docker container was created that creates a demo database and seeds it. There is a Kubernetes `Job` that runs the container to initialize the database. Similarly, a different Docker container can be built that specifies other data. The example can be found in `liquibase.docker` and a [tutorial](https://www.liquibase.com/blog/using-liquibase-in-kubernetes) is also available.

### Spring application
A Spring application can be deployed using the `spring/spring-v1.yaml` and `spring/spring-v2.yaml` files.
This installation provides a demo Spring application. To replace the demo application, follow this [tutorial](https://spring.io/guides/gs/spring-boot-kubernetes/) to build a Docker image.
Finally, update the `image` in the `spring/spring-v1.yaml` file. The same can be done for the new application version.

### Monitoring
Initially, the Postgres cluster is being monitored by Prometheus. If you do not want the additional workload, monitoring can be disabled by removing the following lines from `postgres/postgres.yaml`:

```yaml
monitoring:
pgmonitor:
  exporter:
    image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter:ubi8-5.0.4-0
```

## Installation

While the Kubernetes cluster is up, the Postgres cluster can simply be installed by running the following command:
```shell
install.sh
```

This installs the CrunchyData Postgres Operator, creates a Postgres cluster and sets up a Spring service that connects to the Pgpool-II service.
The command `kubectl -n postgres-operator get all` should return something like:
```
NAME                                        READY   STATUS    RESTARTS      AGE
pod/crunchy-alertmanager-5fdb768b96-2fmc9   1/1     Running   0             68s
pod/crunchy-grafana-85799958b8-dxtqt        1/1     Running   0             68s
pod/crunchy-prometheus-67b84d64b9-6blnb     1/1     Running   0             68s
pod/hippo-instance1-kjbk-0                  4/4     Running   0             65s
pod/hippo-instance1-kzxg-0                  4/4     Running   0             64s
pod/hippo-instance1-z9jj-0                  4/4     Running   0             64s
pod/hippo-repo-host-0                       1/1     Running   0             64s
pod/liquibase-zh7vh                         1/1     Running   2 (39s ago)   67s
pod/pgo-85684987c9-mhvqj                    1/1     Running   0             70s
pod/pgpool-9649b64bc-bjczk                  1/1     Running   0             68s
pod/pgpool-9649b64bc-mnjdv                  1/1     Running   0             68s
pod/pgpool-9649b64bc-rn66m                  1/1     Running   0             68s
pod/spring-65869894f5-5scmg                 1/1     Running   0             28s
pod/spring-65869894f5-shfcf                 1/1     Running   0             28s
pod/spring-65869894f5-xpwsp                 1/1     Running   0             28s

NAME                           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/crunchy-alertmanager   ClusterIP   10.104.79.98     <none>        9093/TCP   68s
service/crunchy-grafana        ClusterIP   10.105.20.224    <none>        3000/TCP   68s
service/crunchy-prometheus     ClusterIP   10.102.243.81    <none>        9090/TCP   68s
service/hippo-ha               ClusterIP   10.109.120.219   <none>        5432/TCP   65s
service/hippo-ha-config        ClusterIP   None             <none>        <none>     65s
service/hippo-pods             ClusterIP   None             <none>        <none>     65s
service/hippo-primary          ClusterIP   None             <none>        5432/TCP   65s
service/hippo-replicas         ClusterIP   10.96.113.94     <none>        5432/TCP   65s
service/pgpool-svc             ClusterIP   10.105.38.194    <none>        9999/TCP   68s
service/spring-svc             ClusterIP   10.105.205.120   <none>        8080/TCP   68s

NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/crunchy-alertmanager   1/1     1            1           68s
deployment.apps/crunchy-grafana        1/1     1            1           68s
deployment.apps/crunchy-prometheus     1/1     1            1           68s
deployment.apps/pgo                    1/1     1            1           70s
deployment.apps/pgpool                 3/3     3            3           68s
deployment.apps/spring                 3/3     3            3           28s

NAME                                              DESIRED   CURRENT   READY   AGE
replicaset.apps/crunchy-alertmanager-5fdb768b96   1         1         1       68s
replicaset.apps/crunchy-grafana-85799958b8        1         1         1       68s
replicaset.apps/crunchy-prometheus-67b84d64b9     1         1         1       68s
replicaset.apps/pgo-85684987c9                    1         1         1       70s
replicaset.apps/pgpool-9649b64bc                  3         3         3       68s
replicaset.apps/spring-65869894f5                 3         3         3       28s

NAME                                    READY   AGE
statefulset.apps/hippo-instance1-kjbk   1/1     66s
statefulset.apps/hippo-instance1-kzxg   1/1     65s
statefulset.apps/hippo-instance1-z9jj   1/1     66s
statefulset.apps/hippo-repo-host        1/1     65s

NAME                  COMPLETIONS   DURATION   AGE
job.batch/liquibase   0/1           69s        69s
```

If not all pods are in the `RUNNING` state, wait for a while and run the command again before continuing.

## Interacting with the Spring application

The Spring application is run on three different replicas. A load balancer sits in front of it to distribute the incoming requests. It is possible to interact with the web application by exposing the load balancer and directing a web request to it. This can be done with the following command:

```shell
# when a local cluster is running on minikube
minikube service -n postgres-operator spring-svc
```

This opens a web page at `127.0.0.1:{port}`. Where `port` is randomly assigned.

## Connecting from outside the Kubernetes cluster

To connect to the Kubernetes cluster from outside, we need to expose the Pgpool-II service. This can be done with either one of the following two commands:

```shell
# when a local cluster is running on minikube
minikube service -n postgres-operator pgpool-svc --url
```

This shows a URL in the form of: 127.0.0.1:{port}. It is, for instance, possible to connect to the service through psql using the given port.

OR

```shell
PGPOOL_POD=$(kubectl -n postgres-operator get pod -o name -l app.kubernetes.io/name=pgpool | head -n 1)
kubectl -n postgres-operator port-forward "${PGPOOL_POD}" 30200:5432
```

This exposes one of the pods in the `ReplicaSet`. In this case, the port that exposes the service is 30200. Psql can be used as follows to connect to the service:

```shell
psql -h localhost -p {port} -U hippo -d postgres
```

## Monitoring the Postgres cluster
As mentioned, Prometheus monitoring is enabled and provides metrics for the Postgres cluster. It can be accessed by exposing the Grafana service like so:

```shell
kubectl -n postgres-operator port-forward svc/crunchy-grafana 3000:3000
```

Next, go to `localhost:3000` and login with username **admin** and password **admin**. Go to the dashboard screen, click the cluster and navigate to one of the metric pages.

## Performing a database schema migration
The database schema can be migrated by creating a Kubernetes job similar to the database initialization using Liquibase. 
It is also possible to use a local Liquibase installation. Then specify the database connection in the `liquibase.properties` file and expose the Pgpool-II service.
The [liquibase-zd](https://github.com/coenvk/liquibase-zd) plugin is useful to apply the expand-contract pattern and migrate the database schema without any downtime.
The expand-contract pattern starts with an expand step that migrates the database schema to a mixed-state supporting both version v1 and v2.
After performing the expand step using Liquibase, several instances of the updated application can be deployed next to the old application.
First, the domain model in the Spring application needs to be updated. The image for the updated application can be used for the deployment specified in `spring/spring-v2.yaml`.
After running `kubectl apply -f spring/spring-v2.yaml`, ensure that the new application functions correctly.
Next, all clients need to be redirected to the new application instances. This can be done by updating the Spring service configuration. In `spring/spring-svc.yaml` add a new selector called `app.kubernetes.io/version` with a value of `v2`.
Then, apply the new configuration by running `kubectl apply -f spring/spring-svc.yaml`.
The old application instances can now be taken down using `kubectl delete -f spring/spring-v1.yaml`.
As the final step, the contract step can be applied using Liquibase.