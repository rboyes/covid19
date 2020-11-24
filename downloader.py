import json
import os
import sys
from uk_covid19 import Cov19API

output_csvpath = sys.argv[1]
output_dirname = os.path.dirname(output_csvpath)

if not (os.path.exists(output_dirname) and os.path.isdir(output_dirname)):
    raise FileExistsError("Output csv directory does not exist or is not a directory")

output_logpath = sys.argv[2]
output_dirname = os.path.dirname(output_logpath)

if not (os.path.exists(output_dirname) and os.path.isdir(output_dirname)):
    raise FileExistsError("Output log directory does not exist or is not a directory")

filters = ['areaType=ltla']

structure = {
    'date': 'date',
    'name': 'areaName',
    'code': 'areaCode',
    'daily': 'newCasesBySpecimenDate',
    'cumulative': 'cumCasesBySpecimenDate'
}

downloader = Cov19API(filters=filters, structure=structure)

csv = downloader.get_csv(save_as=output_csvpath)

log_data = {
    'release_timestamp': Cov19API.get_release_timestamp()
    'last_udpate': downloader.last_update
    'total_pages': downloader.total_pages
}

with open(output_logpath, 'w') as json_file:
    json_file.write(json.dumps(log_data))
    
exit(0)