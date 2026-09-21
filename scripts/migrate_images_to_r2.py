"""
Base64 сүрөттөрдү R2'га миграциялоо скрипти.

Иштетүү:
    railway run python3 scripts/migrate_images_to_r2.py

Эмне жасайт:
    1. enterprise_products.image_url  — base64 → R2 → URL
    2. enterprises.logo_data          — base64 → R2 → URL
    3. VACUUM менен DB орун бошотот
"""

import os
import base64
import mimetypes
import sys
import time

import boto3
import psycopg2
import psycopg2.extras
from botocore.config import Config

# ── R2 конфигурация ────────────────────────────────────────────────────────────
R2_ACCESS_KEY = os.environ["R2_ACCESS_KEY"]
R2_SECRET_KEY = os.environ["R2_SECRET_KEY"]
R2_ENDPOINT = os.environ["R2_ENDPOINT"]
R2_BUCKET = os.environ["R2_BUCKET"]
PUBLIC_BASE = os.environ["R2_PUBLIC_BASE"].rstrip("/")

DATABASE_URL   = os.environ["DATABASE_URL"]

# ── S3 клиент ─────────────────────────────────────────────────────────────────
s3 = boto3.client(
    "s3",
    endpoint_url=R2_ENDPOINT,
    aws_access_key_id=R2_ACCESS_KEY,
    aws_secret_access_key=R2_SECRET_KEY,
    config=Config(signature_version="s3v4"),
    region_name="auto",
)


def parse_base64(data_url: str) -> tuple[bytes, str]:
    """data:image/jpeg;base64,XXXX → (bytes, content_type)"""
    if "," not in data_url:
        raise ValueError("base64 формат туура эмес")
    header, b64 = data_url.split(",", 1)
    content_type = "image/jpeg"
    if ":" in header and ";" in header:
        content_type = header.split(":")[1].split(";")[0]
    return base64.b64decode(b64), content_type


def ext_for(content_type: str) -> str:
    ext = mimetypes.guess_extension(content_type)
    mapping = {".jpe": ".jpg", ".jpeg": ".jpg", None: ".jpg"}
    return mapping.get(ext, ext or ".jpg")


def upload_to_r2(key: str, data: bytes, content_type: str) -> str:
    """R2'га жүктөп, public URL кайтарат."""
    s3.put_object(
        Bucket=R2_BUCKET,
        Key=key,
        Body=data,
        ContentType=content_type,
    )
    return f"{PUBLIC_BASE}/{key}"


def migrate_product_images(conn):
    print("\n── Продукт сүрөттөрү ────────────────────────────────")
    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute("""
            SELECT id, image_url FROM enterprise_products
            WHERE image_url IS NOT NULL
              AND image_url LIKE 'data:%'
            ORDER BY id
        """)
        rows = cur.fetchall()

    print(f"Жалпы: {len(rows)} продукт сүрөт")
    ok = err = 0

    for row in rows:
        pid, data_url = row["id"], row["image_url"]
        try:
            img_bytes, ctype = parse_base64(data_url)
            ext = ext_for(ctype)
            key = f"products/{pid}{ext}"
            url = upload_to_r2(key, img_bytes, ctype)

            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE enterprise_products SET image_url = %s WHERE id = %s",
                    (url, pid),
                )
            conn.commit()
            ok += 1
            print(f"  ✓ product #{pid} → {key}  ({len(img_bytes)//1024} KB)")
        except Exception as e:
            conn.rollback()
            err += 1
            print(f"  ✗ product #{pid}: {e}")
        time.sleep(0.05)

    print(f"\nПродукттар: {ok} ийгиликтүү, {err} ката")
    return ok, err


def migrate_enterprise_logos(conn):
    print("\n── Ишкана логотиптери ───────────────────────────────")
    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute("""
            SELECT id, logo_data FROM enterprises
            WHERE logo_data IS NOT NULL
              AND logo_data LIKE 'data:%'
            ORDER BY id
        """)
        rows = cur.fetchall()

    print(f"Жалпы: {len(rows)} логотип")
    ok = err = 0

    for row in rows:
        eid, data_url = row["id"], row["logo_data"]
        try:
            img_bytes, ctype = parse_base64(data_url)
            ext = ext_for(ctype)
            key = f"logos/{eid}{ext}"
            url = upload_to_r2(key, img_bytes, ctype)

            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE enterprises SET logo_data = %s WHERE id = %s",
                    (url, eid),
                )
            conn.commit()
            ok += 1
            print(f"  ✓ enterprise #{eid} → {key}  ({len(img_bytes)//1024} KB)")
        except Exception as e:
            conn.rollback()
            err += 1
            print(f"  ✗ enterprise #{eid}: {e}")
        time.sleep(0.05)

    print(f"\nЛоготиптер: {ok} ийгиликтүү, {err} ката")
    return ok, err


def vacuum_db(conn):
    print("\n── VACUUM ───────────────────────────────────────────")
    conn.autocommit = True
    with conn.cursor() as cur:
        cur.execute("VACUUM ANALYZE enterprise_products, enterprises")
    conn.autocommit = False
    print("VACUUM аяктады")


def db_size(conn) -> str:
    with conn.cursor() as cur:
        cur.execute("SELECT pg_size_pretty(pg_database_size(current_database()))")
        return cur.fetchone()[0]


def main():
    print("=" * 55)
    print("  Base64 → Cloudflare R2 миграция")
    print("=" * 55)

    conn = psycopg2.connect(DATABASE_URL)
    try:
        before = db_size(conn)
        print(f"DB өлчөмү миграцияга чейин: {before}")

        p_ok, p_err = migrate_product_images(conn)
        e_ok, e_err = migrate_enterprise_logos(conn)

        vacuum_db(conn)

        after = db_size(conn)
        print("\n" + "=" * 55)
        print(f"  Натыйжа:")
        print(f"  Продукт сүрөттөр: {p_ok} өткөрүлдү, {p_err} ката")
        print(f"  Логотиптер:       {e_ok} өткөрүлдү, {e_err} ката")
        print(f"  DB өлчөмү:  {before}  →  {after}")
        print("=" * 55)

        if p_err + e_err > 0:
            sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
