from fastapi import APIRouter, Depends, HTTPException, File, UploadFile
from sqlalchemy.orm import Session
import os
import uuid
from app.core.database import get_db
from app.core.config import settings
from app.api.deps import get_current_user
from app.models.models import User
from app.repositories.user_repo import UserRepository
from app.schemas.schemas import UserResponse, UserUpdate

router = APIRouter()

@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user

@router.put("/me", response_model=UserResponse)
def update_me(
    user_in: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return UserRepository.update(db, current_user, user_in)

@router.post("/me/photo", response_model=UserResponse)
def upload_profile_photo(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    ext = os.path.splitext(file.filename)[1] or ".jpg"
    photo_id = str(uuid.uuid4())
    filename = f"profile_{photo_id}{ext}"
    file_path = os.path.join(settings.UPLOAD_DIR, filename)
    
    with open(file_path, "wb") as f:
        f.write(file.file.read())
        
    photo_url = f"/uploads/{filename}"
    user_in = UserUpdate(profile_photo_url=photo_url)
    return UserRepository.update(db, current_user, user_in)

@router.get("/{id}", response_model=UserResponse)
def get_user_profile(id: str, db: Session = Depends(get_db)):
    user = UserRepository.get_by_id(db, id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
