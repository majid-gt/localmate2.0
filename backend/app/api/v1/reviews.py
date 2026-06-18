from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile
from sqlalchemy.orm import Session
from typing import List
import os
import uuid
from app.core.config import settings
from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.models import User
from app.repositories.review_repo import ReviewRepository
from app.repositories.listing_repo import ListingRepository
from app.repositories.user_repo import UserRepository
from app.schemas.schemas import ServiceReviewCreate, ServiceReviewResponse, ContributorReviewCreate, ContributorReviewResponse

router = APIRouter()

@router.post("/listings/{id}", response_model=ServiceReviewResponse, status_code=status.HTTP_201_CREATED)
def create_service_review(
    id: str,
    review_in: ServiceReviewCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    listing = ListingRepository.get_by_id(db, id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
        
    return ReviewRepository.create_service_review(db, review_in, id, current_user.id)

@router.get("/listings/{id}", response_model=List[ServiceReviewResponse])
def get_service_reviews(id: str, db: Session = Depends(get_db)):
    listing = ListingRepository.get_by_id(db, id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
        
    return ReviewRepository.get_service_reviews(db, id)

@router.post("/users/{id}", response_model=ContributorReviewResponse, status_code=status.HTTP_201_CREATED)
def create_contributor_review(
    id: str,
    review_in: ContributorReviewCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    target_user = UserRepository.get_by_id(db, id)
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Prevent reviewing oneself
    if id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot review yourself")
        
    return ReviewRepository.create_contributor_review(db, review_in, id, current_user.id)

@router.get("/users/{id}", response_model=List[ContributorReviewResponse])
def get_contributor_reviews(id: str, db: Session = Depends(get_db)):
    target_user = UserRepository.get_by_id(db, id)
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")
        
    return ReviewRepository.get_contributor_reviews(db, id)

@router.post("/upload")
def upload_review_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    ext = os.path.splitext(file.filename)[1] or ".jpg"
    img_id = str(uuid.uuid4())
    filename = f"proof_{img_id}{ext}"
    file_path = os.path.join(settings.UPLOAD_DIR, filename)
    
    with open(file_path, "wb") as f:
        f.write(file.file.read())
        
    image_url = f"/uploads/{filename}"
    return {"image_url": image_url}
