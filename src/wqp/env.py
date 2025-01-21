# =================================================================
#
# Authors: Colton Loftus <cloftus@lincolninst.edu>
# Authors: Ben Webb <bwebb@lincolninst.edu>
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================

from wqp.util import get_env

API_BACKEND_URL = get_env("API_BACKEND_URL")
GEOCONNEX_URL = "https://geoconnex.us"
NLDI_URL = "https://labs.waterdata.usgs.gov/api/nldi"
STATION_URL = 'https://www.waterqualitydata.us/data/Station/search'
RESULTS_URL = 'https://www.waterqualitydata.us/data/Result/search'
MONITORING_LOCATIONS_URL = "https://www.waterqualitydata.us/data/summary/monitoringLocation/search"
