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
