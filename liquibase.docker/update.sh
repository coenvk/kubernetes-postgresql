#!/bin/sh

DB_USERNAME=$(kubectl -n postgres-operator get secrets/hippo-pguser-hippo --template={{.data.user}} | base64 -d)
DB_PASSWORD=$(kubectl -n postgres-operator get secrets/hippo-pguser-hippo --template={{.data.password}} | base64 -d)
DB_DATABASE=$(kubectl -n postgres-operator get secrets/hippo-pguser-hippo --template={{.data.dbname}} | base64 -d)
DB_PORT=$(kubectl -n postgres-operator get secrets/hippo-pguser-hippo --template={{.data.port}} | base64 -d)
DB_HOST=$(kubectl -n postgres-operator get secrets/hippo-pguser-hippo --template={{.data.host}} | base64 -d)
POD_NAME=$(kubectl -n postgres-operator get pods -o name -l postgres-operator.crunchydata.com/role=master)

kubectl -n postgres-operator port-forward ${POD_NAME} 30200:${DB_PORT} &
pid=$!

trap '{
  kill $pid
}' EXIT

DB_URL="jdbc:postgresql://localhost:30200/${DB_DATABASE}"

if [ -z "$1" ]
then
  LIQUIBASE_COMMAND="update"
else
  LIQUIBASE_COMMAND="updateCount $1"
fi

liquibase ${LIQUIBASE_COMMAND} --url=${DB_URL} --username=${DB_USERNAME} --password=${DB_PASSWORD} --changeLogFile=db/changelog/db.changelog-master.xml --logLevel=info