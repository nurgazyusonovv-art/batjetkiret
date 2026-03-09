from time import perf_counter
from uuid import uuid4
import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi.errors import RateLimitExceeded
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.core.limiter import limiter
from app.core.logging import configure_logging
from app.api import auth, couriers, orders, courier_orders, users, wallet, admin
from app.api import chat
from app.api import support_chat
from app.api import notifications
from app.api import ratings
from app.api import topup

configure_logging(level=settings.LOG_LEVEL, json_logs=settings.LOG_JSON)
logger = logging.getLogger("app.request")

app = FastAPI(title="BATJETKIRET API")
app.state.limiter = limiter

# Custom exception handler for rate limit exceeded
@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request, exc):
    return JSONResponse(
        status_code=429,
        content={"detail": "Too many requests. Please try again later."},
    )


@app.middleware("http")
async def request_logging_middleware(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID") or uuid4().hex
    start = perf_counter()
    client_ip = request.client.host if request.client else "unknown"

    try:
        response = await call_next(request)
    except Exception:
        duration_ms = round((perf_counter() - start) * 1000, 2)
        logger.exception(
            "request_failed",
            extra={
                "service": settings.SERVICE_NAME,
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "duration_ms": duration_ms,
                "client_ip": client_ip,
            },
        )
        raise

    duration_ms = round((perf_counter() - start) * 1000, 2)
    response.headers["X-Request-ID"] = request_id
    logger.info(
        "request_completed",
        extra={
            "service": settings.SERVICE_NAME,
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "duration_ms": duration_ms,
            "client_ip": client_ip,
        },
    )

    return response

# CORS configuration - allow all localhost origins for development
if settings.DEBUG or True:  # Allow all origins for development
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # Allow all origins
        allow_credentials=False,  # Can't use "*" with credentials=True
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


app.include_router(notifications.router)
app.include_router(support_chat.router)
app.include_router(auth.router)
app.include_router(couriers.router)
app.include_router(orders.router)
app.include_router(courier_orders.router)
app.include_router(wallet.router)
app.include_router(admin.router)
app.include_router(ratings.router)
app.include_router(users.router)
app.include_router(topup.router)



app.include_router(chat.router)
