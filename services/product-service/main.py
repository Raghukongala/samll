from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import uvicorn
import os
import uuid
from datetime import datetime

app = FastAPI(title="Product Service", version="1.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

products_db = {}

class ProductCreate(BaseModel):
    name: str
    description: str
    price: float
    stock: int
    category: str

class ProductResponse(BaseModel):
    id: str
    name: str
    description: str
    price: float
    stock: int
    category: str
    created_at: str

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    stock: Optional[int] = None

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "product-service"}

@app.post("/products", response_model=ProductResponse, status_code=201)
def create_product(product: ProductCreate):
    product_id = str(uuid.uuid4())
    product_data = {
        "id": product_id,
        **product.dict(),
        "created_at": datetime.utcnow().isoformat()
    }
    products_db[product_id] = product_data
    return product_data

@app.get("/products", response_model=List[ProductResponse])
def list_products(category: Optional[str] = None):
    products = list(products_db.values())
    if category:
        products = [p for p in products if p["category"] == category]
    return products

@app.get("/products/{product_id}", response_model=ProductResponse)
def get_product(product_id: str):
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail="Product not found")
    return products_db[product_id]

@app.put("/products/{product_id}", response_model=ProductResponse)
def update_product(product_id: str, update: ProductUpdate):
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail="Product not found")
    for field, value in update.dict(exclude_none=True).items():
        products_db[product_id][field] = value
    return products_db[product_id]

@app.delete("/products/{product_id}")
def delete_product(product_id: str):
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail="Product not found")
    del products_db[product_id]
    return {"message": "Product deleted"}

@app.post("/products/{product_id}/reduce-stock")
def reduce_stock(product_id: str, quantity: int):
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail="Product not found")
    if products_db[product_id]["stock"] < quantity:
        raise HTTPException(status_code=400, detail="Insufficient stock")
    products_db[product_id]["stock"] -= quantity
    return {"message": "Stock updated", "remaining_stock": products_db[product_id]["stock"]}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", 8002)))
