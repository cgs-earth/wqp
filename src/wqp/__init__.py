# =================================================================
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================

from dagster import Definitions
from wqp.jobs import process_county_stations


defs = Definitions(
    jobs=[process_county_stations],
)
