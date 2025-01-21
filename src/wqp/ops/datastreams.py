
from csv import DictReader
from io import StringIO
import re
from requests import Session
from typing import Iterable
from dagster import get_dagster_logger

from wqp.env import MONITORING_LOCATIONS_URL
from wqp.util import make_uuid, url_join
from wqp.mapping import MAPPING

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
            _uuid = make_uuid(c_string)
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

        observed_property_definition = ''
        _url = 'https://cdxapps.epa.gov/oms-substance-registry-services/substance-details'  # noqa
        _ = dataset['CharacteristicName'].replace(' ', '').lower()
        __ = observed_property_name.replace(' ', '').lower()
        if _ in MAPPING:
            observed_property_definition = url_join(_url, MAPPING[_])
        elif __ in MAPPING:
            observed_property_definition = url_join(_url, MAPPING[__])
        else:
            pattern = r'[a-zA-Z0-9()\[\].-]+'
            for word in re.findall(pattern, observed_property_name):
                try:
                    inner_id = MAPPING[word.lower()]
                    observed_property_definition = url_join(_url, inner_id)
                    break
                except KeyError:
                    continue
        yield {
            '@iot.id': id,
            'name': observed_property_name + ' at ' + dataset['MonitoringLocationIdentifier'],  # noqa
            'description': observed_property_name + ' at ' + dataset['MonitoringLocationIdentifier'],  # noqa
            'observationType': 'http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement',  # noqa
            'phenomenonTime': f'{dataset["min_year"]}-01-01T00:00:00Z/{dataset["max_year"]}-12-31T00:00:00Z', # noqa
            'unitOfMeasurement': {
                'name': 'unknown',
                'symbol': 'unknown',
                'definition': 'unknown'
            },
            'ObservedProperty': {
                'name': observed_property_name,
                'description': observed_property_name,
                'definition': observed_property_definition,
            },
            'Sensor': {
                "name": "Unknown",
                "description": "Unknown",
                "encodingType": "Unknown",
                'metadata': 'Unknown'
            },
        }


def load_datastreams(station_id: str):
    """
    Load datasets from USBR RISE API

    :returns: list, of link relations for all datasets
    """
    return yield_datastreams(fetch_datastreams(station_id))
