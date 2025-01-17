from pydantic import BaseModel

class APIConfig(BaseModel):
    results_url: str
    station_url: str
    geoconnex_url: str