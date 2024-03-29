kubectl apply -k postgres-operator-examples/kustomize/install
kubectl apply -k postgres
sleep 5s
kubectl -n postgres-operator wait --for=condition=ready pod -l postgres-operator.crunchydata.com/instance-set=instance1
PASSWORD=postgres
sleep 10s
kubectl patch secret -n postgres-operator hippo-pguser-postgres -p \
   "{\"stringData\":{\"password\":\"${PASSWORD}\",\"verifier\":\"\"}}"
kubectl apply -k liquibase
kubectl -n postgres-operator wait --for=condition=complete job.batch/liquibase
kubectl apply -k pgpool
kubectl -n postgres-operator wait --for=condition=ready pod -l app.kubernetes.io/name=pgpool
kubectl apply -k prometheus
kubectl apply -k spring
kubectl apply -f spring/spring-v1.yaml