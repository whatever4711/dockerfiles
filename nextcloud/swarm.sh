#!/bin/bash

NET='cloud_net'
SHARE_HOST_1='192.168.9.1'
SHARE_HOST_2='192.168.9.250'
SHARE_HOST_3='192.168.9.47'
SHARE_DIR_1=':/home/marcel/clouddata/Wedding'
SHARE_DIR_2=':/nfs/docker'
RESTART_DELAY='10s'
RESTART_ATTEMPTS='5'
VOLUMES_1=( 'nc_db' 'nc_www' 'nc_config' )
VOLUMES_2=( 'nc_apps' )
VOLUMES_3=( 'nc_data' )
VOLUMES=( "${VOLUMES_1[@]}" "${VOLUMES_2[@]}" "${VOLUMES_3[@]}")
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
docker network create --driver overlay --subnet=192.168.111.0/24 ${NET}
}

function createDB {
local db=${1:-cloud_postgres}
echo "Creating DB service ${db} with volume ${VOLUMES[0]}"
docker service create --name ${db} --replicas 1 --network ${NET} \
  --restart-delay ${RESTART_DELAY} --restart-max-attempts ${RESTART_ATTEMPTS} \
	--publish 5432:5432 \
  --mount type=volume,volume-opt=o=addr="${SHARE_HOST_1}",volume-opt=device="${SHARE_DIR_1}/${VOLUMES[0]}",volume-opt=type=nfs,src=${VOLUMES[0]},dst=/var/lib/postgresql/data \
	whatever4711/postgres:armhf
SERVICES+=("${db}")
}

function createRedis {
local redis=${1:-cloud_redis}
echo "Creating Redis service ${redis}"
docker service create --name ${redis} --replicas 1 --network ${NET} \
  --restart-delay ${RESTART_DELAY} --restart-max-attempts ${RESTART_ATTEMPTS} \
	--publish 6379:6379 \
	--mount type=bind,src=${PWD}/config/redis.conf,dst=/redis.conf \
	--constraint 'node.hostname!=jack' \
	armhf/redis redis-server /redis.conf
SERVICES+=("${redis}")
}

function createMemcache {
local memcache=${1:-cloud_memcache}
local publishedPort=${2:-11211}
echo "Creating Memcache service ${memcache}"
docker service create --name ${memcache} --replicas 1 --network ${NET} \
  --restart-delay ${RESTART_DELAY} --restart-max-attempts ${RESTART_ATTEMPTS} \
	--publish ${publishedPort}:11211 \
	armhf/memcached:alpine -m 128
SERVICES+=("${memcache}")
}

function createNextCloud {
local nextcloud=${1:-cloud_nextcloud}
echo "Creating Nextcloud service ${nextcloud} with volumes ${VOLUMES[1]}, ${VOLUMES[2]}, ${VOLUMES[3]}, and ${VOLUMES[4]}"
docker service create --name ${nextcloud} --replicas 1 --network ${NET} \
  --restart-delay ${RESTART_DELAY} --restart-max-attempts ${RESTART_ATTEMPTS} \
	--publish 9000:9000 \
	--mount type=volume,volume-opt=o=addr="${SHARE_HOST_1}",volume-opt=device="${SHARE_DIR_1}/${VOLUMES[1]}",volume-opt=type=nfs,src=${VOLUMES[1]},dst=/nextcloud \
	--mount type=volume,volume-opt=o=addr="${SHARE_HOST_1}",volume-opt=device="${SHARE_DIR_1}/${VOLUMES[2]}",volume-opt=type=nfs,src=${VOLUMES[2]},dst=/config \
	--mount type=volume,volume-opt=o=addr="${SHARE_HOST_2}",volume-opt=device="${SHARE_DIR_1}/${VOLUMES[3]}",volume-opt=type=nfs,src=${VOLUMES[3]},dst=/apps \
	--mount type=volume,volume-opt=o=addr="${SHARE_HOST_3}",volume-opt=device="${SHARE_DIR_2}/${VOLUMES[4]}",volume-opt=type=nfs,src=${VOLUMES[4]},dst=/data \
	--env DB_TYPE=pgsql \
	--env DB_NAME=nextcloud \
	--env DB_USER=postgres \
	--env DB_PASSWORD=postgres \
	--env DB_HOST=192.168.9.3 \
	--env REDIS_HOST=192.168.9.3 \
	--env MEMCACHE_ARRAY="array('192.168.9.3', 11211)" \
	--env ADMIN_USER=admin \
	--env ADMIN_PASSWORD=admin \
	whatever4711/nextcloud:armhf
SERVICES+=("${nextcloud}")
}

function createCaddy {
	local caddy=${1:-cloud_caddy}
	echo "Creating Caddy service ${caddy} with volumes "
	docker service create --name ${caddy} --replicas 1 --network ${NET} \
	  --restart-delay ${RESTART_DELAY} --restart-max-attempts ${RESTART_ATTEMPTS} \
		--publish 80:80 \
		--mount type=volume,volume-opt=o=addr="${SHARE_HOST_1}",volume-opt=device="${SHARE_DIR_1}/${VOLUMES[1]}",volume-opt=type=nfs,src=${VOLUMES[1]},dst=/nextcloud \
		--mount type=bind,src=${PWD}/config/Caddyfile,dst=/root/.caddy/Caddyfile \
		whatever4711/caddy:armhf --agree --conf /root/.caddy/Caddyfile
	SERVICES+=("${caddy}")
}

function create_ssh {
local ssh=${1:-cloud_ssh}
echo "Creating SSH service ${ssh}"
docker service create --name ${ssh} --replicas 1 --network ${NET} \
  --restart-delay ${RESTART_DELAY} --restart-max-attempts ${RESTART_ATTEMPTS} \
	--publish 2222:22 \
	--env ROOT_PASS=12wert45 \
	--constraint 'node.hostname!=roupi' \
	whatever4711/ssh:armhf
SERVICE+=("${ssh}")
}

function create {
createBasics
createDB
createRedis
createMemcache
setServices
}

function start {
getServices
#createNextCloud
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
# TODO: On Each node!
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
reset        reset - Use with sudo and care

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
