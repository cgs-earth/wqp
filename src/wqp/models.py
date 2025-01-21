# =================================================================
#
# Authors: Ben Webb <bwebb@lincolninst.edu>
#
# Copyright (c) 2025 Lincoln Institute of Land Policy
#
# Licensed under the MIT License.
#
# =================================================================

from pydantic import BaseModel
from typing import List, Dict, Any, Optional


class Station(BaseModel):
    station_id: str
    name: str
    description: str
    longitude: Optional[float]
    latitude: Optional[float]
    state_code: str
    county_code: str
    huc_code: str
    provider: str
    datastreams: List[Dict[str, Any]]


class StationsData(BaseModel):
    stations: List[Station]
