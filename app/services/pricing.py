import math


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
