#!/bin/bash

# Get date for tagging backups.
suffix=$(date +"%Y%m%d")

# Mark the date for deleting the database backup taken given number of days before today.
rotate=$(date +"%Y%m%d" -d "-7days")

# Set path and logging details
scriptpath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
logfile="backup-$(hostname)-$suffix.log"
exitcodes="exit-codes.log"

# Import settings from config file
if [[ -f $scriptpath/settings.conf ]]; then

  source $scriptpath/settings.conf

  # If it doesn't exist, create the directory for storing database dumps as defined in settings.
  if [[ ! -d "$mysql_output" ]]; then
    mkdir -p $mysql_output
  fi

  # Dump all databeses and create arcives.
  # Skip databases with names starting with an underscrore. Also, prefer not to dump "information_schema".
  databases=`mysql --user=$mysql_user --password=$mysql_password -e "SHOW DATABASES;" | tr -d "| " | grep -v Database`
  echo $? >> $scriptpath/$exitcodes
  for db in $databases; do
    if [[ "$db" != "information_schema" ]] && [[ "$db" != _* ]] ; then
      echo -e "========================================\nDumping database: $db\n========================================" >> $scriptpath/$logfile
      mysqldump --force --opt --add-drop-table --log-error=$scriptpath/$logfile --user=$mysql_user --password=$mysql_password --databases $db > $mysql_output/$db.$suffix.sql
      echo $? >> $scriptpath/$exitcodes
      tar cfv $mysql_output/$db.$suffix.sql.tar -C $mysql_output $db.$suffix.sql
      echo $? >> $scriptpath/$exitcodes
      7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on $mysql_output/$db.$suffix.tar.7z $mysql_output/$db.$suffix.sql.tar >>$scriptpath/$logfile 2>&1
      echo $? >> $scriptpath/$exitcodes
      rm $mysql_output/$db.$rotate.tar.7z
    fi
  done
  rm $mysql_output/*.sql $mysql_output/*.tar

  # Sync all local assets with remote.
  echo -e "========================================\nSynchronizing databases\n========================================" >> $scriptpath/$logfile
  if [[ -z "$gs_sync_exclude" ]]; then
    gsutil -m rsync $gs_sync_params $mysql_output gs://$gs_bucket_dbs &>> $scriptpath/$logfile
  else
    gsutil -m rsync $gs_sync_params -x "$gs_sync_exclude" $mysql_output gs://$gs_bucket_dbs &>> $scriptpath/$logfile
  fi
  echo $? >> $scriptpath/$exitcodes
  echo -e "========================================\nSynchronizing virtual hosts\n========================================" >> $scriptpath/$logfile
  if [[ -z "$gs_sync_exclude" ]]; then
    gsutil -m rsync $gs_sync_params $root_vhosts gs://$gs_bucket_vhosts &>> $scriptpath/$logfile
  else
    gsutil -m rsync $gs_sync_params -x "$gs_sync_exclude" $root_vhosts gs://$gs_bucket_vhosts &>> $scriptpath/$logfile
  fi
  echo $? >> $scriptpath/$exitcodes

  # Check if any errors happened during creating and synchronizing backups.
  errorcount="$(grep -Ev '(^0|^$)' $scriptpath/$exitcodes|wc -l)"

  # Send the report.
  report=$(openssl enc -base64 -A -in $scriptpath/$logfile)
  if [[ $errorcount -eq 0 ]]; then
    errorstatus="without any errors"
  elif [[ $errorcount -eq 1 ]]; then
    errorstatus="with $errorcount error"
  else
    errorstatus="with $errorcount errors"
  fi

  echo "{From: '$mail_from', To: '$mail_to', Subject: 'Backup completed $errorstatus @ $(date) for $(hostname)', HtmlBody: 'Please find job report attached to this email.', TextBody: 'Please find job report attached to this email.', Attachments: [{Name: '$logfile', Content: '$report', ContentType: 'text/plain'}]}" >> $scriptpath/mail.json
  curl "https://api.postmarkapp.com/email" \
    -X POST \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "X-Postmark-Server-Token: $postmark_token" \
    -d @$scriptpath/mail.json

  # Set trap for cleanup
  function cleanup {
    rm $scriptpath/$logfile $scriptpath/$exitcodes $scriptpath/mail.json
  }
  trap cleanup EXIT

else

  echo "Missing settings.conf file, please refer to README." > error-$(hostname)-$suffix.log
  exit 0

fi
