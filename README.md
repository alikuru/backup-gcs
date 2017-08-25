# Backup-GCS
A simple bash script for backing up your MySQL databases and virtual hosts' files to Google Cloud Storage.

It basically finds every database hosted on your [MySQL](https://github.com/mysql/mysql-server) (or drop-in replacements like [MariaDB](https://github.com/MariaDB/server) and [Percona](https://github.com/percona/percona-server)) server, create dumps and archives them, then sends those archives with files on your virtual hosts root to Google Cloud Storage. Since it uses `rsync` functionality of `gsutil`, it actually mirrors your web root and database archives to Google Cloud Storage, more like Unix `rsync` than a blind FTP upload. Especially if you choose to use `-d` parameter while synchronizing, which can be set through the settings file. Check [settings.conf.sample](settings.conf.sample) for the set of parameters I use for my transfers.

Though it can be triggered manually, the script is designed to run as a daily cron job. If you don't want a particular database to be dumped synchronized every day, put an underscrore in the beginning of its name and it will be excluded. You can also exclude directories from your webroot. Again, please check [settings.conf.sample](settings.conf.sample) for details.

### Usage
- Clone the repo to your server, wherever you like. Preferably at `/root/`.
- Copy [settings.conf.sample](settings.conf.sample) to `settings.conf` at the script directory and edit it with your credentials and preferences.
- Set a daily cron and if everything works, you'll start receiving daily backup reports.

### Requirements
Needs [gsutil Tool](https://cloud.google.com/storage/docs/gsutil) for synchronizing to Google Cloud Storage and a [Postmark](https://postmarkapp.com/) account for sending notification emails. Also needs [7zip](http://www.7-zip.org) for archiving. Tested only on Debian 7 and 8 but should work on other distributions as well.

### License
This script is licensed under MIT License, which allows you to freely use or modify it as you see fit, without guaranteeing any results. Please read [LICENSE](LICENSE) file for details.

### To-do's
- Make rotation an option that can be controlled through the settings file.
- Interactively create the settings file.
- Create buckets while creating the settings file.
