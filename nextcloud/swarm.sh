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
declare -a SERVICES
filename=services.txt

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

function getServices {
	if [ -f ${filename} ]; then
	  mapfile -t SERVICES < ${filename}
	else
	  SERVICES=()
	fi
}

function setServices {
	echo ${SERVICES[@]} > ${filename}
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
docker node update --label-add ${VOLUMES[0]} cubietruck
ssh neo.mg "docker volume create -d nfs --name ${VOLUMES[1]} -o share=${SHARE_1}/${VOLUMES[1]}"
docker node update --label-add nextcloud=${VOLUMES[1]} neo
docker node update --label-add nextcloud=${VOLUMES[1]} sparrow
}

function createDB {
local db=${1:-cloud_postgres}
echo "Creating DB service ${db} with volume ${VOLUMES[0]}"
docker service create --name ${db} --replicas 1 --network ${NET} \
	--publish 5432:5432 \
	--mount type=volume,src=${VOLUMES[0]},dst=/var/lib/postgresql/data \
	--constraint 'node.hostname==cubietruck' \
	whatever4711/postgres:armhf
SERVICES+=("${db}")
}

function createRedis {
local redis=${1:-cloud_redis}
echo "Creating Redis service ${redis}"
docker service create --name ${redis} --replicas 1 --network ${NET} \
	--publish 6379:6379 \
	--mount type=bind,src=${PWD}/config/redis.conf,dst=/redis.conf \
	--constraint 'node.hostname!=roupi' --constraint 'node.hostname!=jack' \
	armhf/redis redis-server /redis.conf
SERVICES+=("${redis}")
}

function createMemcache {
local memcache=${1:-cloud_memcache}
local publishedPort=${2:-11211}
echo "Creating Memcache service ${memcache}"
docker service create --name ${memcache} --replicas 1 --network ${NET} \
	--publish ${publishedPort}:11211 \
	--constraint 'node.hostname!=roupi' \
	armhf/memcached:alpine -m 64
SERVICES+=("${memcache}")
}

function createNextCloud {
local nextcloud=${1:-cloud_nextcloud}
echo "Creating Nextcloud service ${nextcloud} with volumes ${VOLUMES[1]}, ${VOLUMES[2]}, ${VOLUMES[3]}, and ${VOLUMES[4]}"
docker service create --name ${nextcloud} --replicas 1 --network ${NET} \
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
SERVICES+=("${nextcloud}")
}

function createCaddy {
	local caddy=${1:-cloud_caddy}
	echo "Creating Caddy service ${caddy} with volumes "
	docker service create --name ${caddy} --replicas 1 --network ${NET} \
		--publish 80:80 \
		--mount type=volume,src=${VOLUMES[1]},dst=/nextcloud \
		--mount type=bind,src=${PWD}/config/Caddyfile,dst=/root/.caddy/Caddyfile \
		--constraint "node.labels.nextcloud==${VOLUMES[1]}" \
		whatever4711/caddy:armhf --agree --conf /root/.caddy/Caddyfile
	SERVICES+=("${caddy}")
}

function create_ssh {
local ssh=${1:-cloud_ssh}
echo "Creating SSH service ${ssh}"
docker service create --name ${ssh} --replicas 1 --network ${NET} \
	--publish 2222:22 \
	--env ROOT_PASS=12wert45 \
	--constraint 'node.hostname!=roupi' \
	whatever4711/ssh:armhf
SERVICE+=("${ssh}")
}

function create {
createBasics
sleep 10
createDB
createRedis
createMemcache
createMemcache cloud_memcache_2 11212
setServices
}

function start {
getServices
createNextCloud
createCaddy
setServices
}

function debug {
getServices
create_ssh
setServices
}

function destroy {
getServices
for service in "${SERVICES[@]}"; do
	docker service rm ${service}
done
sleep 10

for volume in "${VOLUMES[@]}"; do
	docker volume rm ${volume}
done
sleep 10
docker network rm ${NET}
rm ${filename}
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
