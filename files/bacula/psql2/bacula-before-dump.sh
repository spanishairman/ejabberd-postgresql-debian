#!/bin/bash
# Пример pg_dump со сжатием:
# sudo -u postgres pg_dump -d ejabberd | gzip > /media/backup/dump/ejabberd.sql.gz
# Мы делаем без сжатия, так как сжимать файлы будет bacula
postgreshome="/var/lib/postgresql"
cd $postgreshome
sudo -u postgres pg_dump -d ejabberd-domain-local > /bacula-backup/ejabberd.sql
