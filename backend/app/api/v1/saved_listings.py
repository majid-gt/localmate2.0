from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.models import User
from app.repositories.listing_repo import ListingRepository
from app.schemas.schemas import ListingResponse

router = APIRouter()

@router.post("/{listing_id}", status_code=status.HTTP_201_CREATED)
def save_listing(
    listing_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    listing = ListingRepository.get_by_id(db, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    
    ListingRepository.save_listing(db, current_user.id, listing_id)
    return {"message": "Listing saved successfully"}

@router.delete("/{listing_id}")
def unsave_listing(
    listing_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    success = ListingRepository.unsave_listing(db, current_user.id, listing_id)
    if not success:
        raise HTTPException(status_code=404, detail="Saved listing reference not found")
    return {"message": "Listing removed from saved"}

@router.get("/", response_model=List[ListingResponse])
def get_saved_listings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return ListingRepository.get_saved_listings(db, current_user.id)
