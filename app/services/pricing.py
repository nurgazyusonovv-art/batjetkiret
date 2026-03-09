def calculate_price(distance_km: float) -> float:
    base_price = 80
    price_per_km = 20

    return base_price + distance_km * price_per_km
