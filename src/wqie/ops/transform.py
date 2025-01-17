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
from wqie.env import API_BACKEND_URL, GEOCONNEX_URL, NLDI_URL
from wqie.util import extract_coord, clean_word, url_join
from wqie.models import Station, StationsData
from wqie.ops.datastreams import load_datastreams

# Logger setup
LOGGER = get_dagster_logger()


# Example upsert function to interact with SensorThings API
def upsert_collection_item(collection: str, item: Dict[str, Any]) -> bool:
    api_url = url_join(API_BACKEND_URL, collection)
    response = requests.post(api_url, json=item)
    return response.status_code == 201  # Return True if creation is successful


@op
def transform_stations(stations: List[Dict[str, Any]]) -> StationsData:
    """
    Transform raw station data into structured format.
    """
    transformed_stations = []

    for row in stations:
        station = Station(
            station_id=row['MonitoringLocationIdentifier'],
            name=clean_word(row['MonitoringLocationName']),
            description=clean_word(row['MonitoringLocationName']),
            longitude=extract_coord(row['LongitudeMeasure']),
            latitude=extract_coord(row['LatitudeMeasure']),
            state_code=row['StateCode'],
            county_code=row['CountyCode'],
            huc_code=row['HUCEightDigitCode'],
            provider=row['ProviderName'],
            datastreams=[]
        )
        transformed_stations.append(station)

    return StationsData(stations=transformed_stations)


@op
def publish_station_collection(stations_data: StationsData) -> None:
    """
    Publishes station collection to API config and backend.

    Takes in the transformed station data and sends it to the SensorThings API.

    :param stations_data: The transformed station data.
    :returns: `None`
    """
    # Iterate over the transformed stations data
    for station in stations_data.stations:
        station_identifier = station.station_id

        try:
            datastreams = load_datastreams(station_identifier)
        except Exception:
            LOGGER.warning(f"Failed to load datastreams for {station_identifier}") # noqa
            continue

        try:
            mainstem = get_mainstem_uri(station_identifier)
        except Exception:
            LOGGER.warning(f"Failed to load mainstem for {station_identifier}")
            continue

        location_name = station.name

        # Construct feature for SensorThings API
        feature = {
            '@iot.id': station_identifier,
            'name': location_name,
            'description': location_name,
            'Locations': [{
                'name': location_name,
                'description': location_name,
                'encodingType': 'application/geo+json',
                'location':  {
                    'type': 'Point',
                    'coordinates': [
                        station.longitude,
                        station.latitude
                    ]
                }
            }],
            'properties': {
                'mainstem': mainstem,
                'hu08': url_join(GEOCONNEX_URL, 'ref/hu08', station.huc_code), # noqa
                'state': url_join(GEOCONNEX_URL, 'ref/states', station.state_code), # noqa
                'county': url_join(GEOCONNEX_URL, 'ref/counties', f"{station.state_code}{station.county_code}"), # noqa
                'provider': station.provider
            },
            'Datastreams': list(datastreams)
        }

        # Upsert the station feature to the SensorThings API
        if not upsert_collection_item('Things', feature):
            LOGGER.error(f'Failed to publish {station_identifier}')
            break  # Stop processing if one fails

    # Additional setup for the collection (e.g., updating metadata)
    # setup_collection(meta=gcm())  # Uncomment if required

    return


def get_mainstem_uri(id):
    # Convert the input geom to GeoJSON using Shapely

    url = url_join(NLDI_URL, 'linked-data/wqp', id)
    r = requests.get(url)
    fc = r.json()
    if 'features' in fc and len(fc['features']) > 0:
        feature = fc['features'][0]
        return feature['properties']['mainstem']
    else:
        return None
