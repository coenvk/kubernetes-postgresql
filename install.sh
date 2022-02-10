kubectl apply -k postgres-operator-examples/kustomize/install
kubectl apply -k .
kubectl apply -f spring/spring-v1.yaml