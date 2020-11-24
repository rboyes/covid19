import json
import os
import sys
import time
from uk_covid19 import Cov19API

if(len(sys.argv) != 3):
    print("Download the latest UK regional covid19 data\n")
    print("Usage: downloader.py output.csv output.log")
    exit(1)

output_csvpath = sys.argv[1]
output_dirname = os.path.abspath(os.path.dirname(output_csvpath))

if not (os.path.exists(output_dirname) and os.path.isdir(output_dirname)):
    raise FileExistsError("Output csv directory does not exist or is not a directory")

output_logpath = sys.argv[2]
output_dirname = os.path.abspath(os.path.dirname(output_logpath))

if not (os.path.exists(output_dirname) and os.path.isdir(output_dirname)):
    raise FileExistsError("Output log directory does not exist or is not a directory")

start_time = time.time()

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

end_time = time.time()

log_data = {
    'release_timestamp': Cov19API.get_release_timestamp(),
    'last_udpate': downloader.last_update,
    'total_pages': downloader.total_pages,
    'download_time': end_time - start_time
}


with open(output_logpath, 'w') as json_file:
    json_file.write(json.dumps(log_data))
    
exit(0)