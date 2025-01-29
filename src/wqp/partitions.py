# =================================================================
#
# Authors: Ben Webb <bwebb@lincolninst.edu>
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================

from dagster import StaticPartitionsDefinition, get_dagster_logger
import requests
from typing import List

LOGGER = get_dagster_logger()


def load_us_counties() -> List[str]:
    """
    Load all US county codes from GeoConnex API.
    """
    url = "https://reference.geoconnex.us/collections/counties/items"
    params = {"limit": 5000, "properties": "statefp,countyfp", "skipGeometry": "true"}
    counties = []
    LOGGER.debug(url)
    while True:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()

        for feature in data["features"]:
            props = feature["properties"]
            county_code = f"US:{props['statefp']}:{props['countyfp']}"
            counties.append(county_code)

        if len(data["features"]) < params["limit"]:
            break

        params["offset"] = params.get("offset", 0) + params["limit"]

    return sorted(counties)


county_partitions = StaticPartitionsDefinition(
   load_us_counties()
)

if __name__ == "__main__":
    from json import dumps
    print(
        dumps({
            partition: "" for partition in load_us_counties()
        })
    )