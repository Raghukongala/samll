from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import Optional, List
import uvicorn
import os
import uuid
from datetime import datetime

app = FastAPI(title="User Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory store (replace with PostgreSQL in production)
users_db = {}

class UserCreate(BaseModel):
    name: str
    email: str
    password: str

class UserResponse(BaseModel):
    id: str
    name: str
    email: str
    created_at: str

class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "user-service"}

@app.post("/users", response_model=UserResponse, status_code=201)
def create_user(user: UserCreate):
    user_id = str(uuid.uuid4())
    user_data = {
        "id": user_id,
        "name": user.name,
        "email": user.email,
        "created_at": datetime.utcnow().isoformat()
    }
    users_db[user_id] = user_data
    return user_data

@app.get("/users", response_model=List[UserResponse])
def list_users():
    return list(users_db.values())

@app.get("/users/{user_id}", response_model=UserResponse)
def get_user(user_id: str):
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    return users_db[user_id]

@app.put("/users/{user_id}", response_model=UserResponse)
def update_user(user_id: str, update: UserUpdate):
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    if update.name:
        users_db[user_id]["name"] = update.name
    if update.email:
        users_db[user_id]["email"] = update.email
    return users_db[user_id]

@app.delete("/users/{user_id}")
def delete_user(user_id: str):
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    del users_db[user_id]
    return {"message": "User deleted"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", 8001)))
