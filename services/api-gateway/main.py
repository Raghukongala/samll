from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import httpx, os, uvicorn, time
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="API Gateway", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

SERVICES = {
    "users":    os.getenv("USER_SERVICE_URL",    "http://user-service:8001"),
    "products": os.getenv("PRODUCT_SERVICE_URL", "http://product-service:8002"),
    "orders":   os.getenv("ORDER_SERVICE_URL",   "http://order-service:8003"),
}

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start
    logger.info(f"{request.method} {request.url.path} → {response.status_code} ({duration:.3f}s)")
    return response

@app.get("/health")
async def health_check():
    statuses = {}
    async with httpx.AsyncClient(timeout=3.0) as client:
        for name, url in SERVICES.items():
            try:
                r = await client.get(f"{url}/health")
                statuses[name] = "healthy" if r.status_code == 200 else "unhealthy"
            except Exception:
                statuses[name] = "unreachable"
    overall = "healthy" if all(v == "healthy" for v in statuses.values()) else "degraded"
    return {"status": overall, "service": "api-gateway", "dependencies": statuses}

@app.api_route("/{service}/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy(service: str, path: str, request: Request):
    if service not in SERVICES:
        raise HTTPException(status_code=404, detail=f"Service '{service}' not found")
    target_url = f"{SERVICES[service]}/{path}"
    if request.url.query:
        target_url += f"?{request.url.query}"
    headers = dict(request.headers)
    headers.pop("host", None)
    body = await request.body()
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.request(
                method=request.method,
                url=target_url,
                headers=headers,
                content=body,
            )
            return JSONResponse(
                content=response.json() if response.content else {},
                status_code=response.status_code
            )
        except httpx.ConnectError:
            raise HTTPException(status_code=503, detail=f"Service '{service}' is unavailable")
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", 8000)))
