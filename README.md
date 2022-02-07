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

## Installation

While the Kubernetes cluster is up, the Postgres cluster can simply be installed by running the following command:
```shell
./install.sh
```

This installs the CrunchyData Postgres Operator, creates a Postgres cluster, and sets up a Pgpool-II service to which you can connect. The command `kubectl -n postgres-operator get all` should return something like:
```
NAME                          READY   STATUS      RESTARTS   AGE
pod/hippo-instance1-86ql-0    3/3     Running     0          2m37s
pod/hippo-instance1-b66n-0    3/3     Running     0          2m37s
pod/hippo-instance1-q6cz-0    3/3     Running     0          2m37s
pod/hippo-repo-host-0         1/1     Running     0          2m37s
pod/liquibase-5w44n           0/1     Completed   0          87s
pod/pgo-85684987c9-zmv2t      1/1     Running     0          2m46s
pod/pgpool-9649b64bc-8qhzz    1/1     Running     0          2m45s
pod/pgpool-9649b64bc-hr92l    1/1     Running     0          2m45s
pod/pgpool-9649b64bc-zfp6p    1/1     Running     0          2m45s
pod/spring-54cc7489b4-6jjst   1/1     Running     0          45s
pod/spring-54cc7489b4-jqcdk   1/1     Running     0          45s
pod/spring-54cc7489b4-s9k7r   1/1     Running     0          45s

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/hippo-ha          ClusterIP   10.106.69.254   <none>        5432/TCP   2m43s
service/hippo-ha-config   ClusterIP   None            <none>        <none>     2m38s
service/hippo-pods        ClusterIP   None            <none>        <none>     2m43s
service/hippo-primary     ClusterIP   None            <none>        5432/TCP   2m43s
service/hippo-replicas    ClusterIP   10.105.204.6    <none>        5432/TCP   2m43s
service/pgpool-svc        ClusterIP   10.111.92.31    <none>        9999/TCP   2m46s
service/spring-svc        ClusterIP   10.110.61.10    <none>        8080/TCP   2m46s

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/pgo      1/1     1            1           2m47s
deployment.apps/pgpool   3/3     3            3           2m46s
deployment.apps/spring   3/3     3            3           46s

NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/pgo-85684987c9      1         1         1       2m47s
replicaset.apps/pgpool-9649b64bc    3         3         3       2m46s
replicaset.apps/spring-54cc7489b4   3         3         3       46s

NAME                                    READY   AGE
statefulset.apps/hippo-instance1-86ql   1/1     2m38s
statefulset.apps/hippo-instance1-b66n   1/1     2m38s
statefulset.apps/hippo-instance1-q6cz   1/1     2m38s
statefulset.apps/hippo-repo-host        1/1     2m38s

NAME                  COMPLETIONS   DURATION   AGE
job.batch/liquibase   1/1           10s        88s
```

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
