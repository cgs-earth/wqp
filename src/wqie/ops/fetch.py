from dagster import op
from typing import List, Dict, Any
from wqie.models import Station, StationsData

def clean_word(text: str) -> str:
    return text.strip().replace('\n', ' ').replace('\r', '')

def extract_coord(value: str) -> float:
    try:
        return float(value)
    except (ValueError, TypeError):
        return 0.0

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
