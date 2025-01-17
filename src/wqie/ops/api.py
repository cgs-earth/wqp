from dagster import op, Nothing
from csv import DictReader
import logging
from ..env import THINGS, STATIONS
from ..models import Station, Location, Properties, Coordinates
from ..util import extract_coord, url_join, clean_word
from ..metadata.datastream import load_datastreams
from ..config import APIConfig

LOGGER = logging.getLogger(__name__)

@op
def publish_stations_to_api() -> Nothing:
    """
    Publish stations to the SensorThings API.
    """
    with STATIONS.open() as fh:
        reader = DictReader(fh)
        api_config = APIConfig()

        for row in reader:
            station_identifier = row['MonitoringLocationIdentifier']
            try:
                datastreams = load_datastreams(station_identifier)
            except Exception:
                LOGGER.warning(f"Failed to load datastreams for {station_identifier}")
                continue

            location_name = clean_word(row['MonitoringLocationName'])
            
            station = Station(
                iot_id=station_identifier,
                name=location_name,
                description=location_name,
                locations=[Location(
                    name=row['MonitoringLocationName'],
                    description=row['MonitoringLocationName'],
                    encoding_type="application/geo+json",
                    location={
                        'type': 'Point',
                        'coordinates': [
                            extract_coord(row['LongitudeMeasure']),
                            extract_coord(row['LatitudeMeasure'])
                        ]
                    }
                )],
                properties=Properties(
                    hu08=url_join(api_config.geoconnex_url, 'ref/hu08', row['HUCEightDigitCode']),
                    state=url_join(api_config.geoconnex_url, 'ref/states', row['StateCode']),
                    county=url_join(api_config.geoconnex_url, 'ref/counties', 
                                  f"{row['StateCode']}{row['CountyCode']}"),
                    provider=row['ProviderName']
                ),
                datastreams=datastreams
            )

            if not upsert_collection_item(THINGS, station.dict(by_alias=True)):
                LOGGER.error(f"Failed to publish {station_identifier}")

@op
def delete_stations_from_api() -> Nothing:
    """
    Delete stations from the SensorThings API.
    """
    with STATIONS.open() as fh:
        reader = DictReader(fh)
        for row in reader:
            delete_collection_item(THINGS, row['MonitoringLocationIdentifier'])