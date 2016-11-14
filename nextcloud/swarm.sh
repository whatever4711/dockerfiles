#!/bin/bash

NET='cloud_net'
SHARE_HOST_1='cubietruck.mg'
SHARE_HOST_2='pine64.mg'
SHARE_DIR_1='/home/marcel/clouddata/Wedding'
SHARE_DIR_2='/home/marcel/clouddata/Wedding'
SHARE_1=${SHARE_HOST_1}:${SHARE_DIR_1}
SHARE_2=${SHARE_HOST_2}:${SHARE_DIR_2}
VOLUMES_1=( 'nc_db' 'nc_www' 'nc_config' ) 
VOLUMES_2=( 'nc_data' 'nc_apps' )
VOLUMES=( "${VOLUMES_1[@]}" "${VOLUMES_2[@]}" )
SERVICES=( 'cloud_postgres' 'cloud_redis' 'cloud_memcache' 'cloud_nextcloud' 'cloud_ssh' )

# Requires su rights
function reset {
tmp=tmp
mkdir ${tmp}
mount ${SHARE_1} ${tmp}
cd ${tmp}
for volume in "${VOLUMES_1[@]}"; do
	echo "Removing contents of ${volume}"
	rm -rf ${volume}
	echo "Recreating ${volume}"
	mkdir ${volume}
done
cd ..
umount ${tmp}
mount ${SHARE_2} ${tmp}
cd ${tmp}
for volume in "${VOLUMES_2[@]}"; do
	echo "Removing contents of ${volume}"
	rm -rf ${volume}
	echo "Recreating ${volume}"
	mkdir ${volume}
done
cd ..
umount ${tmp}
rm -rf ${tmp}
}

function createBasics {
echo "Creating network ${NET}"
docker network create --driver overlay ${NET}
for volume in "${VOLUMES_1[@]}"; do
	echo "Creating volume ${volume}"
	docker volume create -d nfs --name ${volume} -o share=${SHARE_1}/${volume}
done
for volume in "${VOLUMES_2[@]}"; do
	echo "Creating volume ${volume}"
	docker volume create -d nfs --name ${volume} -o share=${SHARE_2}/${volume}
done
ssh cubietruck.mg "docker volume create -d nfs --name ${VOLUMES[0]} -o share=${SHARE_1}/${VOLUMES[0]}"
}

function createDB {
echo "Creating DB service ${SERVICES[0]} with volume ${VOLUMES[0]}"
docker service create --name ${SERVICES[0]} --replicas 1 --network ${NET} \
	--publish 5432:5432 \
	--mount type=volume,src=${VOLUMES[0]},dst=/var/lib/postgresql/data \
	--constraint 'node.hostname==cubietruck' \
	whatever4711/postgres:armhf
}

function createRedis {
echo "Creating Redis service ${SERVICES[1]}"
docker service create --name ${SERVICES[1]} --replicas 1 --network ${NET} \
	--publish 6379:6379 \
	--constraint 'node.hostname!=roupi' --constraint 'node.hostname!=jack' \
	armhf/redis
}

function createMemcache {
local publishedPort=${1:-11211}
local nextName=${2:-''}
echo "Creating Memcache service ${SERVICES[2]}${nextName}"
docker service create --name ${SERVICES[2]}${nextName} --replicas 1 --network ${NET} \
	--publish ${publishedPort}:11211 \
	--constraint 'node.hostname!=roupi' \
	armhf/memcached:alpine
}

function createNextCloud {
echo "Creating Nextcloud service ${SERVICES[3]} with volumes ${VOLUMES[1]}, ${VOLUMES[2]}, ${VOLUMES[3]}, and ${VOLUMES[4]}"
docker service create --name ${SERVICES[3]} --replicas 1 --network ${NET} \
	--publish 9000:9000 \
	--mount type=volume,src=${VOLUMES[1]},dst=/nextcloud \
	--mount type=volume,src=${VOLUMES[2]},dst=/config \
	--mount type=volume,src=${VOLUMES[3]},dst=/data \
	--mount type=volume,src=${VOLUMES[4]},dst=/apps \
	--env DB_TYPE=pgsql \
	--env DB_NAME=nextcloud \
	--env DB_USER=postgres \
	--env DB_PASSWORD=postgres \
	--env DB_HOST=192.168.9.3 \
	--env REDIS_HOST=192.168.9.3 \
	--env MEMCACHE_ARRAY="array('192.168.9.3', 11211), array('192.168.9.250', 11212)" \
	--env ADMIN_USER=admin \
	--env ADMIN_PASSWORD=admin \
	--constraint 'node.hostname==sparrow' \
	whatever4711/nextcloud:armhf
}

function create_ssh {
echo "Creating SSH service ${SERVICES[4]}"
docker service create --name ${SERVICES[4]} --replicas 1 --network ${NET} \
	--publish 2222:22 \
	--env ROOT_PASS=12wert45 \
	--constraint 'node.hostname!=roupi' \
	whatever4711/ssh:armhf
}

function create {
createBasics
sleep 10
createDB
createRedis
createMemcache
createMemcache 11212 2
}

function start {
createNextCloud
}

function debug {
create_ssh
}

function destroy {
for service in "${SERVICES[@]}"; do
	docker service rm ${service}
done
sleep 10

for volume in "${VOLUMES[@]}"; do
	docker volume rm ${volume}
done
sleep 10
docker network rm ${NET}

}

function usage(){
cat << EOM
usage:

create       create
start        start
debug        debugging with ssh container
destroy      destroy
reset        reset

EOM
}

if [ $# -eq 1 ]; then
	case "$1" in
		"create")  create;;
		"start")   start;;
		"debug")   debug;;
		"destroy")    destroy;;
		"reset")    reset;;
		*) usage;;
	esac
else
	usage
fi
exit 0
