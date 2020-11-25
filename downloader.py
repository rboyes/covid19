from json import dumps
import os
import sys
import datetime
from uk_covid19 import Cov19API

if(len(sys.argv) != 3):
    print("Download the latest UK regional covid19 data\n")
    print("Usage: downloader.py output.csv output.log")
    exit(1)

output_csvpath = sys.argv[1]
output_dirname = os.path.abspath(os.path.dirname(output_csvpath))

if not (os.path.exists(output_dirname) and os.path.isdir(output_dirname)):
    raise FileExistsError(f"Output csv directory {output_dirname} does not exist or is not a directory")

output_logpath = sys.argv[2]
output_dirname = os.path.abspath(os.path.dirname(output_logpath))

if not (os.path.exists(output_dirname) and os.path.isdir(output_dirname)):
    raise FileExistsError(f"Output log directory {output_dirname} does not exist or is not a directory")

start_time = datetime.datetime.now()
num_pages = 0

structure = {
    'date': 'date',
    'name': 'areaName',
    'code': 'areaCode',
    'daily': 'newCasesBySpecimenDate',
    'cumulative': 'cumCasesBySpecimenDate'
}

data = []
areatype_filters = ['ltla', 'overview', 'nation']
for areatype in areatype_filters:
    downloader = Cov19API(filters=[f"areaType={areatype}"], structure=structure)
    filter_data = downloader.get_json()
    data.extend(filter_data['data'])
    num_pages += filter_data['totalPages']
    
with open(output_csvpath, 'w') as csv_file:
    csv_header = ','.join(list(data[0].keys()))
    csv_file.write(f"{csv_header}\n")
    for item in data:
        entries = [str(x) for x in item.values()]
        csv_entries = ','.join(entries)
        csv_file.write(f"{csv_entries}\n")
    
end_time = datetime.datetime.now()

log_data = {
    'release_timestamp': Cov19API.get_release_timestamp(),
    'start_time': str(start_time),
    'end_time': str(end_time),
    'download_time': str(end_time - start_time),
    'total_pages': str(num_pages)
}

with open(output_logpath, 'w') as json_file:
    json_file.write(dumps(log_data))
    
exit(0)