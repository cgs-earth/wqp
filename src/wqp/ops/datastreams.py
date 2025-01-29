
from csv import DictReader
from io import StringIO
import re
from requests import Session
from typing import Iterable
from dagster import get_dagster_logger

from wqp.env import MONITORING_LOCATIONS_URL
from wqp.util import deterministic_hash, url_join
from wqp.mapping import MAPPING
from wqp.models import Datastream, UnitOfMeasurement, ObservedProperty

LOGGER = get_dagster_logger()


def fetch_datastreams(station_id: str):
    """
    Load datasets from USBR RISE API

    :returns: list, of link relations for all datasets
    """
    http = Session()

    params = {
        'siteid': station_id,
        'mimeType': 'csv',
        'dataProfile': 'periodOfRecord'
    }

    r = http.get(MONITORING_LOCATIONS_URL, params=params)
    if len(r.content) <= 2278:
        # LOGGER.warning(f'No data found at {r.url}')
        return {}

    datastreams = {}
    with StringIO(r.text) as fh:
        reader = DictReader(fh)
        for row in reader:
            c_string = f"{row['CharacteristicName']}-{row['MonitoringLocationIdentifier']}"  # noqa
            _uuid = deterministic_hash(c_string, 32)
            row = dict(row)
            # Add code here
            try:
                year = int(row['YearSummarized'])
            except ValueError:
                continue  # Skip rows without a valid year

            # If this datastream has already been seen, update min/max years
            if _uuid in datastreams:
                existing = datastreams[_uuid]
                existing['min_year'] = min(existing['min_year'], year)
                existing['max_year'] = max(existing['max_year'], year)
            else:
                # Initialize the datastream with the current row and year
                row.update({
                    'min_year': year,
                    'max_year': year
                })
                datastreams[_uuid] = row

    return datastreams


def yield_datastreams(datasets: dict) -> Iterable:
    """
    Yield datasets from USBR RISE API

    :returns: Iterable, of link relations for all datasets
    """

    for id, dataset in datasets.items():

        observed_property_name = dataset['CharacteristicName'].strip()
        if observed_property_name not in MAPPING:
            continue

        obs_property = MAPPING[observed_property_name]
        _url = 'https://cdxapps.epa.gov/oms-substance-registry-services/substance-details'  # noqa
        observed_property_definition = url_join(_url, obs_property['itn'])

        yield {
            '@iot.id': id,
            'name': observed_property_name + ' at ' + dataset['MonitoringLocationIdentifier'],  # noqa
            'description': observed_property_name + ' at ' + dataset['MonitoringLocationIdentifier'],  # noqa
            'observationType': 'http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement',  # noqa
            'phenomenonTime': f'{dataset["min_year"]}-01-01T00:00:00Z/{dataset["max_year"]}-12-31T00:00:00Z', # noqa
            'unitOfMeasurement': {
                'name': obs_property['uom'],
                'symbol': obs_property['uom'],
                'definition': 'Unknown'
            },
            'ObservedProperty': {
                '@iot.id': deterministic_hash(observed_property_name, 32),
                'name': observed_property_name,
                'description': observed_property_name,
                'definition': observed_property_definition,
            },
            'Sensor': {"@iot.id": 1}
        }


def load_datastreams(station_id: str):
    """
    Load datasets from USBR RISE API

    :returns: list, of link relations for all datasets
    """
    return yield_datastreams(fetch_datastreams(station_id))
