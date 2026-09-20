import json
import logging
import math
import urllib.parse
import urllib.request
from typing import Optional

from app.core.config import settings


def calculate_price(
    distance_km: float,
    base_price: float = 80,
    price_per_km: float = 20,
    extra_after_km: float = 4,
    extra_price_per_km: float = 0,
) -> float:
    extra_km = max(0.0, distance_km - extra_after_km)
    return base_price + distance_km * price_per_km + extra_km * extra_price_per_km


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return great-circle distance in kilometres."""
    R = 6371.0
    φ1, φ2 = math.radians(lat1), math.radians(lat2)
    dφ = math.radians(lat2 - lat1)
    dλ = math.radians(lon2 - lon1)
    a = math.sin(dφ / 2) ** 2 + math.cos(φ1) * math.cos(φ2) * math.sin(dλ / 2) ** 2
    return R * 2 * math.asin(math.sqrt(a))


# Road distance ≈ 1.6× the straight line on Batken's street grid (measured on
# sample routes); used when a routing service is unavailable.
ROAD_FACTOR = 1.6
MIN_DISTANCE_KM = 0.5
MAX_DISTANCE_KM = 500.0

_ORS_URL = "https://api.openrouteservice.org/v2/directions/driving-car"
_ORS_TIMEOUT_SECONDS = 6

logger = logging.getLogger(__name__)


def _clamp_distance(value: float) -> float:
    return max(MIN_DISTANCE_KM, min(MAX_DISTANCE_KM, value))


def road_distance_km(
    from_lat: float,
    from_lon: float,
    to_lat: float,
    to_lon: float,
) -> Optional[float]:
    """Driving distance from OpenRouteService, or None when unavailable."""
    api_key = settings.ORS_API_KEY
    if not api_key:
        return None

    query = urllib.parse.urlencode(
        {
            "api_key": api_key,
            "start": f"{from_lon},{from_lat}",
            "end": f"{to_lon},{to_lat}",
        }
    )
    try:
        req = urllib.request.Request(
            f"{_ORS_URL}?{query}",
            headers={"User-Agent": "BatkenExpress/1.0"},
        )
        with urllib.request.urlopen(req, timeout=_ORS_TIMEOUT_SECONDS) as resp:
            if resp.status != 200:
                return None
            payload = json.loads(resp.read().decode("utf-8"))
        meters = payload["features"][0]["properties"]["summary"]["distance"]
        if not isinstance(meters, (int, float)) or meters <= 0:
            return None
        return float(meters) / 1000.0
    except Exception as exc:  # network error, quota, unexpected payload
        logger.warning("ORS routing failed: %s", exc)
        return None


def resolve_distance_km(
    client_distance_km: float,
    from_lat: Optional[float],
    from_lon: Optional[float],
    to_lat: Optional[float],
    to_lon: Optional[float],
) -> float:
    """Distance the price is billed on.

    The client sends a distance, but a modified app could send any number, so
    whenever both endpoints carry coordinates the server recomputes it and
    ignores what was sent. Without coordinates there is nothing to verify
    against, so the client value is only clamped to a sane range.
    """
    have_coords = None not in (from_lat, from_lon, to_lat, to_lon)
    if not have_coords:
        logger.info(
            "Order without coordinates — billing the client distance %.2f km",
            client_distance_km,
        )
        return _clamp_distance(client_distance_km)

    distance = road_distance_km(from_lat, from_lon, to_lat, to_lon)
    if distance is None:
        distance = haversine_km(from_lat, from_lon, to_lat, to_lon) * ROAD_FACTOR

    resolved = _clamp_distance(distance)
    # Big gaps mean a stale estimate, a routing outage, or a tampered client.
    if client_distance_km > 0 and abs(resolved - client_distance_km) / resolved > 0.25:
        logger.warning(
            "Distance mismatch: client sent %.2f km, server billed %.2f km",
            client_distance_km,
            resolved,
        )
    return resolved
