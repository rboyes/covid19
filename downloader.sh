#!/bin/bash
set -u

#Date of processing
DT=$(date "+%Y-%m-%d")

CSV_DIR='/volume1/web/covid19-data'
LOG_DIR='/tmp'

CSV_PATH="$CSV_DIR/covid19-$DT.csv"
LOG_PATH="$LOG_DIR/covid19-$DT.log"

THIS_DIR="$(dirname $(realpath $0))"
cd $THIS_DIR && 
  python3 -m pipenv install &&
  python3 -m pipenv run python "$THIS_DIR/downloader.py" $CSV_PATH $LOG_PATH

find $CSV_DIR -type f -mtime +7 -name 'covid19*.csv' | xargs rm -f
find $LOG_DIR -type f -mtime +7 -name 'covid19*.log' | xargs rm -f

