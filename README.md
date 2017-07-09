# mailcow-backup
**Warning!** These scripts are not yet suitable for use in a productive system!
The scripts have not yet been fully tested and can contain fatal errors. No liability is assumed for damage of any kind!

The scripts extend the [mailcow-dockerized](https://github.com/mailcow/mailcow-dockerized) project with a backup function.

## How to use
- Clone the repository `git clone https://github.com/Dennis14e/mailcow-backup.git`
- Go to the directory of the repository `cd mailcow-backup/`
- Copy the sample configuration file `cp backup.sample.conf backup.conf`
- Edit the configuration file and save it
- Run a script (e.g. `./backup_mysql.sh`)
