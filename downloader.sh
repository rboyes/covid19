#!/bin/bash
set -u

#Date of processing
DT=$(date "+%Y-%m-%d")

ENV_PATH=/volume1/share/venv/covid19/bin/activate
PYTHON_PATH="$(dirname $(realpath $0))/downloader.py"
CSV_PATH="/volume1/web/covid19-data/covid19-$DT.csv"
LOG_PATH="/temp/covid19-$DT.log"

. $ENV_PATH
python $PYTHON_PATH $CSV_PATH $LOG_PATH

deactivate