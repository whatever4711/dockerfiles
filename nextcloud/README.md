## whatever4711/nextcloud

### Features
- One Container per process.
- Memcache enabled.
- Caddy server with automatic letsencrypt functionality
- Bundled with PHP 7.
- Automatic installation using environment variables.
- Package integrity and authenticity checked during building process.
- Data and apps persistence.
- OPCache (opcocde), APCu (local), Redis (file locking) installed and configured.
- system cron task running.
- MySQL, PostgreSQL (server not built-in) and sqlite3 support.
- Redis, FTP, SMB, LDAP support.
- GNU Libiconv for php iconv extension (avoiding errors with some apps).
- No root processes. Never.
- Environment variables provided (see below).

### Notes
- [It has been reported](https://github.com/Wonderfall/dockerfiles/issues/37) that this image might not work well with old versions of aufs. Please update aufs to 4.x or later, or use overlay/btrfs as a replacement.
- HTTP port has recently changed, it's now **8888**. You will have to modify your reverse proxy settings.
- A Redis sever is now running, so you may want to configure it for file locking cache if your config.php was not generated recently. [For best performance it is recommended by Nextcloud documentation](https://docs.nextcloud.com/server/10/admin_manual/configuration_server/caching_configuration.html#additional-notes-for-redis-vs-apcu-on-memory-caching). Add the following lines to your `config.php` :

```
  'memcache.locking' => '\OC\Memcache\Redis',
   'redis' => array(
        'host' => '/tmp/redis.sock',
        'port' => 0,
        'timeout' => 0.0,
         ),
```

### Why choose this image over the official?
I wanted to make this official, and I was granted an access to the repository. But many people were opposed since my image doesn't respect Docker philosophy "one process per container". Honestly I don't give a shit, but I let them do their thing. Be aware I'm not a developper or anything else related, I maintain this image because I need it. Contributions are welcome!

Why this over the official? I've already answered : this is an all-in-one container, so you can avoid complexity. Only the database is not included since the choice should be yours. Environment variables can be provided for a fast & simple setup. I also care about security : NO root processes (golden rule of my images), and the use of PGP verification whenever it's possible. So which one is better? Of course it's up to you, perhaps you'll prefer the official for its modularity, perhaps you'll prefer mine for its simplicity.

### Tags
- **latest** : latest stable version. (11.0)
- **11.0** : latest 11.0.x version (stable)
- **10.0** : latest 10.0.x version (old stable) (unmaintained)
- **9.0** : latest 9.0.x version. (old stable) (unmaintained)
- **daily** : latest code (daily build).

Other tags than `daily` are built weekly. For security reasons, you should occasionally update the container, even if you have the latest version of Nextcloud.

### Build-time variables
- **NEXTCLOUD_VERSION** : version of nextcloud
- **GNU_LIBICONV_VERSION** : version of GNU Libiconv
- **GPG_nextcloud** : signing key fingerprint

### Environment variables
- **UID** : nextcloud user id *(default : 991)*
- **GID** : nextcloud group id *(default : 991)*
- **UPLOAD_MAX_SIZE** : maximum upload size *(default : 10G)*
- **APC_SHM_SIZE** : apc memory size *(default : 128M)*
- **OPCACHE_MEM_SIZE** : opcache memory size in megabytes *(default : 128)*
- **CRON_PERIOD** : time interval between two cron tasks *(default : 15m)*
- **TZ** : the system/log timezone *(default : Etc/UTC)*
- **ADMIN_USER** : username of the admin account *(default : admin)*
- **ADMIN_PASSWORD** : password of the admin account *(default : admin)*
- **DB_TYPE** : database type (sqlite3, mysql or pgsql) *(default : sqlite3)*
- **DB_NAME** : name of database *(default : none)*
- **DB_USER** : username for database *(default : none)*
- **DB_PASSWORD** : password for database user *(default : none)*
- **DB_HOST** : database host *(default : none)*

Don't forget to use a **strong password** for the admin account!

### Port
- **9000** : FPM Nextcloud port.

### Volumes
- **/data** : Nextcloud data.
- **/config** : config.php location.
- **/apps2** : Nextcloud downloaded apps.
- **/var/lib/redis** : Redis dumpfile location.

### Database
Basically, you can use a database instance running on the host or any other machine. An easier solution is to use an external database container. I suggest you to use MariaDB, which is a reliable database server. You can use the official `mariadb` image available on Docker Hub to create a database container, which must be linked to the Nextcloud container. PostgreSQL can also be used as well.

### Setup
Pull the image and create a container. `/mnt` can be anywhere on your host, this is just an example. Change `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` values (mariadb). You may also want to change UID and GID for Nextcloud, as well as other variables (see *Environment Variables*).
