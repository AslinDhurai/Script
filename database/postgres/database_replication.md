#Docker Installation
$ sudo apt update
$ sudo apt install apt-transport-https ca-certificates curl software-properties-common
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
$ sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
$ apt-cache policy docker-ce
$ sudo apt install docker-ce
$ sudo systemctl status docker


#Create Network
$ docker network create pg-cluster

#Launch Primary Container
$ docker run --name pg-primary \
  -e POSTGRES_PASSWORD=secret \
  -v pg-data-primary:/var/lib/postgresql/data \
  --network pg-cluster \
  -d postgres:15 -c wal_level=replica

#Create Replication User
$ docker exec -it pg-primary psql -U postgres -c \
  "CREATE USER repl_user WITH REPLICATION PASSWORD 'repl_pass';"

#Base Backup
$ docker run --rm -it \
  -v pg-data-replica:/var/lib/postgresql/data \
  --network pg-cluster \
  postgres:15 bash -c '
  rm -rf /var/lib/postgresql/data/* && \
  PGPASSWORD=repl_pass pg_basebackup -h pg-primary -U repl_user -D /var/lib/postgresql/data -P -v -R'

#Start Replica
$ docker run --name pg-replica \
  -v pg-data-replica:/var/lib/postgresql/data \
  --network pg-cluster \
  -d postgres:15

#Check Replication Status
$ docker exec pg-primary psql -U postgres -c \
  "SELECT * FROM pg_stat_replication;"

#Lists active replication connections
$ docker exec pg-replica psql -U postgres -c \
  "SELECT pg_is_in_recovery();"

##Test Data Sync
# Primary
$ docker exec pg-primary psql -U postgres -c \
  "CREATE TABLE test(id SERIAL); INSERT INTO test DEFAULT VALUES;"

# Replica
$ docker exec pg-replica psql -U postgres -c \
  "SELECT * FROM test;"



#Validating Lag is <60s
$ docker exec pg-primary psql -U postgres -c \
  "SELECT client_addr, 
   EXTRACT(SECOND FROM write_lag) AS write_lag_sec,
   EXTRACT(SECOND FROM replay_lag) AS replay_lag_sec
   FROM pg_stat_replication;"

#Inserting Data
$ docker exec pg-primary psql -U postgres -c   "CREATE TABLE IF NOT EXISTS test_lag(id SERIAL PRIMARY KEY, name TEXT); \
  INSERT INTO test_lag(name) SELECT 'Lag test data' FROM generate_series(1, 100000);"

