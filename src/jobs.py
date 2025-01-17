from dagster import job, graph_partition_key, Config
from wqie.ops.fetch import fetch_station_metadata, fetch_site_metadata
from wqie.ops.transform import transform_stations
from wqie.partitions import county_partitions

class JobConfig(Config):
    results_url: str
    station_url: str
    geoconnex_url: str

@job(config_schema=JobConfig, partitions_def=county_partitions)
def process_county_stations(context):
    """
    Process stations for a single county partition.
    """
    config = {
        "results_url": context.op_config["results_url"],
        "station_url": context.op_config["station_url"],
        "geoconnex_url": context.op_config["geoconnex_url"]
    }
    
    county = graph_partition_key()
    
    stations = fetch_station_metadata(config, county)
    site_details = fetch_site_metadata(config, [s["MonitoringLocationIdentifier"] for s in stations])
    station_data = transform_stations(site_details)
    
    return station_data
