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

# In-memory dictionary for OTP storage (for development/MVP testing)
# In production, this can be moved to Redis
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
def send_otp(request: OTPSendRequest):
    # Normalize phone number (simple check)
    phone = request.phone_number.strip()
    
    # Generate 6-digit OTP code
    otp_code = str(random.randint(100000, 999999))
    
    # For testing ease, if phone ends with "0000", code is always "123456"
    if phone.endswith("0000"):
        otp_code = "123456"
        
    MOCK_OTP_STORE[phone] = otp_code
    print(f"--- [MOCK SMS GATEWAY] Sent OTP {otp_code} to {phone} ---")
    
    return {"message": "OTP sent successfully", "debug_code": otp_code}

@router.post("/otp/verify", response_model=Token)
def verify_otp(request: OTPVerifyRequest, db: Session = Depends(get_db)):
    phone = request.phone_number.strip()
    code = request.code.strip()
    
    # Validation
    stored_code = MOCK_OTP_STORE.get(phone)
    # Check bypass or exact code match
    if code != "123456" and stored_code != code:
        raise HTTPException(status_code=400, detail="Invalid OTP code")
    
    # Cleanup OTP
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

@router.post("/google", response_model=Token)
def google_login(request: GoogleLoginRequest, db: Session = Depends(get_db)):
    # In a real app, verify request.id_token with Google API:
    # idinfo = id_token.verify_oauth2_token(token, requests.Request(), CLIENT_ID)
    # google_id = idinfo['sub']
    
    # Mock Google Login for MVP:
    google_id = f"google-{request.id_token[-10:]}"
    email = request.email or f"user-{google_id}@gmail.com"
    name = request.name or "Google User"
    
    user = UserRepository.get_by_google_id(db, google_id)
    is_new_user = False
    
    if not user:
        # Check if user with same email or phone exists (we default to google_id check)
        is_new_user = True
        # For Google logins, phone number is initially empty or temp placeholder.
        # The frontend should ask the user to fill and verify their phone number if missing.
        temp_phone = f"google-tmp-{random.randint(10000, 99999)}"
        user_in = UserCreate(
            name=name,
            phone_number=temp_phone,
            email=email,
            profile_photo_url=None,
            google_id=google_id
        )
        user = UserRepository.create(db, user_in)
        
    access_token = create_access_token(subject=user.id)
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "is_new_user": is_new_user
    }
