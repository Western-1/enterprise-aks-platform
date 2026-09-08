from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest

items_created = Counter("media_items_created_total", "Items created via POST /media/items")


def render() -> tuple[bytes, str]:
    return generate_latest(), CONTENT_TYPE_LATEST