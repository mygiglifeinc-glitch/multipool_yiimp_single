# multipool_yiimp_single
Installation files for yiimp single server

#### These files do nothing on their own please go to https://github.com/cryptopool-builders/Multi-Pool-Installer

## Supported systems

- Ubuntu 22.04 LTS (Jammy Jellyfish)
- Ubuntu 24.04 LTS (Noble Numbat)
- Ubuntu 26.04 LTS (Resolute Raccoon)

64-bit (x86_64) only. Ubuntu 16.04, 18.04 and 20.04 are no longer supported.

## Notes

- PHP is installed from the [Ondrej PHP PPA](https://launchpad.net/~ondrej/+archive/ubuntu/php)
  using the `PHP_VERSION` set in `/etc/multipool.conf` (falls back to the Ubuntu PHP packages on
  releases the PPA does not support yet). MariaDB, nginx and certbot come from Ubuntu.
- The YiiMP source is cloned from https://github.com/cryptopool-builders/yiimp.git. To install from a
  fork set `YIIMP_REPO` (and optionally `YIIMP_BRANCH`) in the environment before starting the installer.
- Database user names and passwords are saved in `$STORAGE_ROOT/yiimp/.my.cnf` (readable by the
  installing user only).
