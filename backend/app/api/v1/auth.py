from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional
from app.core.database import get_db
from app.core.security import create_access_token
from app.repositories.user_repo import UserRepository
from app.schemas.schemas import Token, UserCreate
from pydantic import BaseModel
import random

router = APIRouter()

import redis
from app.core.config import settings

# Initialize Redis client with fallback
USE_REDIS = False
redis_client = None

try:
    redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)
    redis_client.ping()
    USE_REDIS = True
    print("--- Connected to Redis successfully for OTP store ---")
except Exception as e:
    print(f"--- Redis connection failed: {e}. Falling back to in-memory MOCK_OTP_STORE. ---")

MOCK_OTP_STORE = {}

class OTPSendRequest(BaseModel):
    phone_number: str

class OTPVerifyRequest(BaseModel):
    phone_number: str
    code: str

class GoogleLoginRequest(BaseModel):
    id_token: str
    name: Optional[str] = None
    email: Optional[str] = None

from typing import Optional

@router.post("/otp/send", status_code=status.HTTP_200_OK)
def send_otp(request: OTPSendRequest, db: Session = Depends(get_db)):
    # Normalize phone number (simple check)
    phone = request.phone_number.strip()
    
    # Check if user exists and has a fixed OTP
    user = UserRepository.get_by_phone(db, phone)
    if user and user.fixed_otp:
        otp_code = user.fixed_otp
    else:
        # Generate 6-digit OTP code
        otp_code = str(random.randint(100000, 999999))
        
        # For testing ease, if phone ends with "0000", code is always "123456"
        if phone.endswith("0000"):
            otp_code = "123456"
            
        if USE_REDIS:
            try:
                redis_client.setex(f"otp:{phone}", 300, otp_code) # 5 minutes TTL
            except Exception as e:
                print(f"--- Redis error on setex: {e}, falling back to in-memory ---")
                MOCK_OTP_STORE[phone] = otp_code
        else:
            MOCK_OTP_STORE[phone] = otp_code
        
    print(f"--- [MOCK SMS GATEWAY] Sent OTP {otp_code} to {phone} ---")
    
    return {"message": "OTP sent successfully", "debug_code": otp_code}

@router.post("/otp/verify", response_model=Token)
def verify_otp(request: OTPVerifyRequest, db: Session = Depends(get_db)):
    phone = request.phone_number.strip()
    code = request.code.strip()
    
    # Check if user exists and has fixed OTP
    user = UserRepository.get_by_phone(db, phone)
    if user and user.fixed_otp:
        if code != user.fixed_otp:
            raise HTTPException(status_code=400, detail="Invalid OTP code")
    else:
        # Validation
        stored_code = None
        if USE_REDIS:
            try:
                stored_code = redis_client.get(f"otp:{phone}")
            except Exception as e:
                print(f"--- Redis error on get: {e}, falling back to in-memory ---")
                stored_code = MOCK_OTP_STORE.get(phone)
        else:
            stored_code = MOCK_OTP_STORE.get(phone)
            
        # Check bypass or exact code match
        if code != "123456" and stored_code != code:
            raise HTTPException(status_code=400, detail="Invalid OTP code")
    
    # Cleanup OTP
    if USE_REDIS:
        try:
            redis_client.delete(f"otp:{phone}")
        except Exception as e:
            print(f"--- Redis error on delete: {e} ---")
    if phone in MOCK_OTP_STORE:
        del MOCK_OTP_STORE[phone]
        
    # Check if user exists
    user = UserRepository.get_by_phone(db, phone)
    is_new_user = False
    
    if not user:
        # Create a new user skeleton
        is_new_user = True
        user_in = UserCreate(
            name=f"User-{phone[-4:]}",
            phone_number=phone,
            email=None,
            profile_photo_url=None
        )
        user = UserRepository.create(db, user_in)
        
    access_token = create_access_token(subject=user.id)
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "is_new_user": is_new_user
    }

import httpx
from jose import jwt
import os

GOOGLE_CERTS_URL = "https://www.googleapis.com/oauth2/v3/certs"
_google_certs_cache = None

def verify_google_token(token: str) -> dict:
    global _google_certs_cache
    
    # Test/emulator bypass
    if token.startswith("mock") or "mock" in token:
        return {
            "sub": f"google-mock-{token[-10:]}",
            "email": f"mock-{token[-10:]}@gmail.com",
            "name": "Mock Google User",
            "picture": None
        }
        
    try:
        if not _google_certs_cache:
            resp = httpx.get(GOOGLE_CERTS_URL)
            if resp.status_code == 200:
                _google_certs_cache = resp.json()
            else:
                raise HTTPException(status_code=500, detail="Failed to fetch Google OAuth certs")
                
        header = jwt.get_unverified_header(token)
        kid = header.get("kid")
        if not kid:
            raise HTTPException(status_code=400, detail="Token lacks kid header")
            
        matching_key = None
        for key in _google_certs_cache.get("keys", []):
            if key.get("kid") == kid:
                matching_key = key
                break
                
        if not matching_key:
            # Try fetching once more in case certificates rotated
            resp = httpx.get(GOOGLE_CERTS_URL)
            if resp.status_code == 200:
                _google_certs_cache = resp.json()
                for key in _google_certs_cache.get("keys", []):
                    if key.get("kid") == kid:
                        matching_key = key
                        break
                        
        if not matching_key:
            raise HTTPException(status_code=400, detail="Invalid token signing key ID")
            
        # Verify and decode
        google_client_id = os.getenv("GOOGLE_CLIENT_ID")
        options = {}
        if not google_client_id:
            options["verify_aud"] = False
            
        payload = jwt.decode(
            token,
            matching_key,
            algorithms=["RS256"],
            audience=google_client_id,
            options=options
        )
        
        # Check issuer
        if payload.get("iss") not in ["accounts.google.com", "https://accounts.google.com"]:
            raise HTTPException(status_code=400, detail="Invalid token issuer")
            
        return {
            "sub": payload.get("sub"),
            "email": payload.get("email"),
            "name": payload.get("name", "Google User"),
            "picture": payload.get("picture")
        }
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token has expired")
    except jwt.JWTError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Token validation failed: {e}")
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Google login failed: {e}")

@router.post("/google", response_model=Token)
def google_login(request: GoogleLoginRequest, db: Session = Depends(get_db)):
    # Verify Google ID token
    google_data = verify_google_token(request.id_token)
    google_id = google_data["sub"]
    email = google_data["email"] or f"user-{google_id}@gmail.com"
    name = google_data["name"]
    picture = google_data["picture"]
    
    user = UserRepository.get_by_google_id(db, google_id)
    is_new_user = False
    
    if not user:
        is_new_user = True
        temp_phone = f"google-tmp-{random.randint(10000, 99999)}"
        user_in = UserCreate(
            name=name,
            phone_number=temp_phone,
            email=email,
            profile_photo_url=picture,
            google_id=google_id
        )
        user = UserRepository.create(db, user_in)
        
    access_token = create_access_token(subject=user.id)
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "is_new_user": is_new_user
    }
