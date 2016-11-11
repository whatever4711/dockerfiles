#!/bin/bash

NET='cloud_net'
SHARE_HOST='sparrow.mg'
SHARE_DIR='/home/marcel/clouddata/Wedding'
SHARE=${SHARE_HOST}:${SHARE_DIR}
VOLUMES=( 'nc_db' 'nc_www' 'nc_config' 'nc_data' 'nc_apps' )
SERVICES=( 'cloud_postgres' 'cloud_redis' 'cloud_memcache' 'cloud_nextcloud' 'cloud_ssh' )


function create {
#Does not work!
docker network create --driver overlay ${NET}
for volume in "${VOLUMES[@]}"; do
  echo "Creating volume ${volume}"
  docker volume create -d nfs --name ${volume} -o share=${SHARE}/${volume}
done
}

function createDB {
docker service create --name ${SERVICES[1]} --replicas 1 --network ${NET} \
--mount type=volume,src=${VOLUMES[1]},dst=/var/lib/postgresql/data \
--constraint 'node.hostname==sparrow' \
whatever4711/postgres:armhf
}

function createRedis {
docker service create --name ${SERVICES[2]} --replicas 1 --network ${NET} \
--constraint 'node.hostname!=jack' \
armhf/redis
}

function createMemcache {
docker service create --name ${SERVICE[3]} --replicas 1 --network ${NET} \
--constraint 'node.hostname!=jack' \
armhf/memcached:alpine
}

function createNextCloud {
docker service create --name ${SERVICES[4]} --replicas 1 --network ${NET} \
--publish 9000:9000 \
--mount type=volume,src=${VOLUMES[2]},dst=/nextcloud \
--mount type=volume,src=${VOLUMES[3]},dst=/config \
--mount type=volume,src=${VOLUMES[4]},dst=/data \
--mount type=volume,src=${VOLUMES[5]},dst=/apps \
--env DB_TYPE=pgsql \
--env DB_NAME=nextcloud \
--env DB_USER=postgres \
--env DB_PASSWORD=postgres \
--env DB_HOST=${SERVICES[1]} \
--env REDIS_HOST=${SERVICES[2]} \
--env MEMCACHE_HOST=${SERVICE[3]} \
--env ADMIN_USER=admin \
--env ADMIN_PASSWORD=admin \
--constraint 'node.hostname==sparrow' \
whatever4711/nextcloud:armhf
}

function create_ssh {
docker service create --name ${SERVICES[5]}--replicas 1 --network ${NET} \
--publish 2222:22 \
--mount type=volume,src=nc_www,dst=/nextcloud \
--env ROOT_PASS=12wert45 \
--constraint 'node.hostname!=jack' \
whatever4711/ssh:armhf
}

function start {
  create
  createDB
  createRedis
  createMemcache
}

function destroy {
  for service in "${SERVICES[@]}"; do
    docker service rm ${service}
  done

  for volume in "${VOLUMES[@]}"; do
    docker volume rm ${volume}
  done

  docker network rm ${NET}

}

function usage(){
cat << EOM
  usage:

  create       create
  start        start
  destroy      destroy

EOM
}

if [ $# -eq 1 ]; then
  case "$1" in
    "create")  create;;
    "start")   start;;
    "destroy")    destroy;;
    *) usage;;
  esac
else
  usage
fi
exit 0
