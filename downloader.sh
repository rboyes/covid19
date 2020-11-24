#!/bin/bash
set -u

#Date of processing
DT=$(date "+%Y-%m-%d")

ENV_PATH=/volume1/share/venv/covid19/bin/activate
PYTHON_PATH=/volume1/share/web
CSV_PATH="/volume1/web/covid19/covid19-"$DT".csv"
LOG_PATH="/temp/covid19-"$DT".log"

. $ENV_PATH
python $PYTHON_PATH $CSV_PATH $LOG_PATH

deactivate