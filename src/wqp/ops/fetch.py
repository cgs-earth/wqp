# =================================================================
#
# Authors: Ben Webb <bwebb@lincolninst.edu>
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================

from dagster import op, Out
import requests
from typing import Dict, Any, List
import csv

from wqp.env import STATION_URL


@op(out={"station_details": Out(list)})
def fetch_station_metadata(county: str) -> List[Dict[str, Any]]:
    """
    Fetch detailed site metadata for a set of sites.
    """
    params = {
        'countycode': [county],
        'mimeType': 'csv'
    }
    response = requests.post(STATION_URL, data=params)
    response.raise_for_status()

    details = []
    for row in csv.DictReader(response.text.splitlines()):
        details.append(row)

    return details
