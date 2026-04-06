from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import uvicorn, httpx, os, uuid
from datetime import datetime
from enum import Enum

app = FastAPI(title="Order Service", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

orders_db = {}
USER_SERVICE_URL = os.getenv("USER_SERVICE_URL", "http://user-service:8001")
PRODUCT_SERVICE_URL = os.getenv("PRODUCT_SERVICE_URL", "http://product-service:8002")

class OrderStatus(str, Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"

class OrderItem(BaseModel):
    product_id: str
    quantity: int

class OrderCreate(BaseModel):
    user_id: str
    items: List[OrderItem]

class OrderResponse(BaseModel):
    id: str
    user_id: str
    items: List[dict]
    status: str
    total_amount: float
    created_at: str

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "order-service"}

@app.post("/orders", response_model=OrderResponse, status_code=201)
async def create_order(order: OrderCreate):
    async with httpx.AsyncClient() as client:
        user_resp = await client.get(f"{USER_SERVICE_URL}/users/{order.user_id}")
        if user_resp.status_code == 404:
            raise HTTPException(status_code=404, detail="User not found")

        order_items = []
        total_amount = 0.0

        for item in order.items:
            prod_resp = await client.get(f"{PRODUCT_SERVICE_URL}/products/{item.product_id}")
            if prod_resp.status_code == 404:
                raise HTTPException(status_code=404, detail=f"Product {item.product_id} not found")
            product = prod_resp.json()
            line_total = product["price"] * item.quantity
            total_amount += line_total
            order_items.append({
                "product_id": item.product_id,
                "product_name": product["name"],
                "quantity": item.quantity,
                "unit_price": product["price"],
                "line_total": line_total
            })

        for item in order.items:
            await client.post(f"{PRODUCT_SERVICE_URL}/products/{item.product_id}/reduce-stock",
                              params={"quantity": item.quantity})

    order_id = str(uuid.uuid4())
    order_data = {
        "id": order_id,
        "user_id": order.user_id,
        "items": order_items,
        "status": OrderStatus.PENDING,
        "total_amount": total_amount,
        "created_at": datetime.utcnow().isoformat()
    }
    orders_db[order_id] = order_data
    return order_data

@app.get("/orders", response_model=List[OrderResponse])
def list_orders(user_id: Optional[str] = None):
    orders = list(orders_db.values())
    if user_id:
        orders = [o for o in orders if o["user_id"] == user_id]
    return orders

@app.get("/orders/{order_id}", response_model=OrderResponse)
def get_order(order_id: str):
    if order_id not in orders_db:
        raise HTTPException(status_code=404, detail="Order not found")
    return orders_db[order_id]

@app.put("/orders/{order_id}/status")
def update_order_status(order_id: str, status: OrderStatus):
    if order_id not in orders_db:
        raise HTTPException(status_code=404, detail="Order not found")
    orders_db[order_id]["status"] = status
    return orders_db[order_id]

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", 8003)))
