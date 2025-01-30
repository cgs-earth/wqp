# =================================================================
#
# Authors: Ben Webb <bwebb@lincolninst.edu>
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================

from dagster import op, get_dagster_logger
from typing import List, Dict, Any
import requests

# Assumed to be defined elsewhere in the project
from wqp.env import API_BACKEND_URL, GEOCONNEX_URL, NLDI_URL
from wqp.util import extract_coord, clean_word, url_join
from wqp.models import Station, StationsData
from wqp.ops.datastreams import load_datastreams

# Logger setup
LOGGER = get_dagster_logger()


def upsert_collection_item(collection: str, item: Dict[str, Any]) -> bool:
    api_url = url_join(API_BACKEND_URL, collection)
    response = requests.post(api_url, json=item)
    return response.status_code == 201


def station_exists(station_id: str) -> bool:
    """
    Check if a station exists in the SensorThings API.

    :param station_id: The identifier of the station.
    :return: True if the station exists, False otherwise.
    """
    api_url = url_join(API_BACKEND_URL, f"Things('{station_id}')")
    response = requests.get(api_url)
    return response.status_code == 200


@op
def transform_stations(stations: List[Dict[str, Any]]) -> StationsData:
    """
    Transform raw station data into structured format.
    """
    transformed_stations = []

    for row in stations:
        try:
            lon = float(extract_coord(row['LongitudeMeasure']))
            lat = float(extract_coord(row['LatitudeMeasure']))
        except ValueError:
            LOGGER.debug(row['MonitoringLocationIdentifier'])
            continue

        station = Station(
            station_id=row['MonitoringLocationIdentifier'],
            name=clean_word(row['MonitoringLocationName']),
            description=clean_word(row['MonitoringLocationName']),
            longitude=lon,
            latitude=lat,
            state_code=row['StateCode'],
            county_code=row['CountyCode'],
            huc_code=row['HUCEightDigitCode'],
            provider=row['ProviderName'],
            organization_name=row['OrganizationFormalName'],
            location_type=row['MonitoringLocationTypeName'],
            datastreams=[]
        )
        if station_exists(station.station_id):
            continue

        transformed_stations.append(station)

    return StationsData(stations=transformed_stations)


@op
def publish_station_collection(stations_data: StationsData) -> bool:
    """
    Publishes station collection to API config and backend.

    Takes in the transformed station data and sends it to the SensorThings API.

    :param stations_data: The transformed station data.
    :returns: `None`
    """
    # Iterate over the transformed stations data
    sta_things = []
    sensor_url = url_join(API_BACKEND_URL, "Sensors")
    sensor = {
        '@iot.id': 1,
        'name': 'Unknown',
        'description': 'Unknown',
        'encodingType': 'Unknown',
        'metadata': 'Unknown'
    }
    requests.post(sensor_url, json=sensor)
    for station in stations_data.stations:
        station_identifier = station.station_id

        try:
            datastreams = list(load_datastreams(station_identifier))
            assert len(datastreams) != 0
        except AssertionError:
            LOGGER.info(f'No datastreams for {station_identifier}')
            continue
        except Exception:
            msg = f'Failed to load datastreams for {station_identifier}'
            LOGGER.warning(msg)
            continue

        try:
            mainstem, station_url = get_mainstem_uri(station_identifier)
        except Exception:
            mainstem = ''
            station_url = ''
            LOGGER.info(f'Failed to load mainstem for {station_identifier}')

        # Construct feature for SensorThings API
        sta_things.append({
            '@iot.id': station_identifier,
            'name': station.name,
            'description': station.name,
            'Locations': [{
                'name': station.name,
                'description': station.name,
                'encodingType': 'application/geo+json',
                'location':  {
                    'type': 'Point',
                    'coordinates': [
                        station.longitude,
                        station.latitude
                    ]
                },
            }],
            'properties': {
                'mainstem': mainstem,
                'station_url': station_url,
                'uri': url_join(GEOCONNEX_URL, 'iow/wqp', station_identifier),
                'hu08': url_join(GEOCONNEX_URL, 'ref/hu08', station.huc_code), # noqa
                'state': url_join(GEOCONNEX_URL, 'ref/states', station.state_code), # noqa
                'county': url_join(GEOCONNEX_URL, 'ref/counties', f"{station.state_code}{station.county_code}"), # noqa
                'provider': station.provider,
                'OrganizationFormalName': station.organization_name,
                'monitoringLocationType': station.location_type
            },
            'Datastreams': datastreams
        })

        # Upsert the station feature to the SensorThings API
        if not upsert_collection_item('Things', sta_things[-1]):
            LOGGER.error(f'Failed to publish {station_identifier}')
            break  # Stop processing if one fails

    # BatchHelper().send_things(sta_things)

    return True


def get_mainstem_uri(id):
    # Convert the input geom to GeoJSON using Shapely

    url = url_join(NLDI_URL, 'linked-data/wqp', id)
    r = requests.get(url)
    fc = r.json()
    if 'features' in fc and len(fc['features']) > 0:
        feature = fc['features'][0]
        return feature['properties']['mainstem'], feature['properties']['uri']
    else:
        return None
