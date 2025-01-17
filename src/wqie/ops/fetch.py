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

from wqie.env import RESULTS_URL, STATION_URL


@op(out={"sites": Out(list)})
def fetch_station_metadata(county: str) -> List[Dict[str, Any]]:
    """
    Fetch station metadata for a single county.
    """
    params = {
        'countycode': [county],
        'mimeType': 'csv',
        'startDateLo': '01-01-2023',
        'dataProfile': 'resultPhysChem'
    }
    response = requests.get(RESULTS_URL, params=params)
    response.raise_for_status()

    stations = []
    for row in csv.DictReader(response.text.splitlines()):
        stations.append(row)
    return stations


@op(out={"station_details": Out(list)})
def fetch_site_metadata(site_ids: List[str]) -> List[Dict[str, Any]]:
    """
    Fetch detailed site metadata for a set of sites.
    """
    params = {
        'siteid': site_ids,
        'mimeType': 'csv'
    }
    response = requests.post(STATION_URL, data=params)
    response.raise_for_status()

    details = []
    for row in csv.DictReader(response.text.splitlines()):
        details.append(row)
    return details
