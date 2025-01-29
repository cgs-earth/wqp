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

from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional


class UnitOfMeasurement(BaseModel):
    """SensorThings API UnitOfMeasurement"""

    name: str
    symbol: str
    definition: str


class ObservedProperty(BaseModel):
    """SensorThings API ObservedProperty"""

    # iotid: str = Field(alias="@iot.id")
    name: str
    definition: str
    description: str


class Datastream(BaseModel):
    """SensorThings API Datastream"""

    iotid: str = Field(alias="@iot.id")
    name: str
    description: str
    observationType: str
    unitOfMeasurement: UnitOfMeasurement
    ObservedProperty: ObservedProperty
    Sensor: dict


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
    organization_name: str
    location_type: str
    datastreams: List[Dict[str, Any]]


class StationsData(BaseModel):
    stations: List[Station]
