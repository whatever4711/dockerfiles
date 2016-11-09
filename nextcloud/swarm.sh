#!/bin/bash

docker network create --driver overlay cloud_net_internal
docker network create --driver overlay cloud_net_external

docker volume create -d nfs --name pg_data -o share=jack.mg:/home/marcel/clouddata/Wedding/pg_data

docker service create --name cloud_postgres --replicas 1 --network cloud_net_internal \
--mount type=volume,src=pg_data,dst=/var/lib/postgresql/data \
--constraint 'node.hostname==sparrow' \
whatever4711/postgres:armhf

docker service create --name cloud_redis --replicas 1 --network cloud_net_internal \
armhf/redis

docker service create --name cloud_memcache --replicas 1 --network cloud_net_internal \
armhf/memcached:alpine

docker volume create -d nfs --name nc_www -o share=jack.mg:/home/marcel/clouddata/Wedding/nc_www
docker volume create -d nfs --name nc_config -o share=jack.mg:/home/marcel/clouddata/Wedding/nc_config
docker volume create -d nfs --name nc_data -o share=jack.mg:/home/marcel/clouddata/Wedding/nc_data
docker volume create -d nfs --name nc_apps -o share=jack.mg:/home/marcel/clouddata/Wedding/nc_apps

docker service create --name cloud_nextcloud --replicas 1 --network cloud_net_internal \
--publish 9000:9000 \
--mount type=volume,src=nc_www,dst=/nextcloud \
--mount type=volume,src=nc_config,dst=/config \
--mount type=volume,src=nc_data,dst=/data \
--mount type=volume,src=nc_apps,dst=/apps \
--env DB_TYPE=pgsql \
--env DB_NAME=nextcloud \
--env DB_USER=postgres \
--env DB_PASSWORD=postgres \
--env DB_HOST=cloud_postgres \
--env REDIS_HOST=cloud_redis \
--env MEMCACHE_HOST=cloud_memcache \
--env ADMIN_USER=admin \
--env ADMIN_PASSWORD=admin \
whatever4711/nextcloud:armhf
