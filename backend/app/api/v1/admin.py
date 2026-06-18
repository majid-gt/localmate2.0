from fastapi import APIRouter, Depends, HTTPException, Header, status
from sqlalchemy.orm import Session
from typing import List, Optional
from app.core.database import get_db
from app.models.models import User, Listing, ServiceReview
from app.schemas.schemas import UserResponse, ListingResponse, ServiceReviewResponse

router = APIRouter()

ADMIN_SECRET = "localmate_admin_secret_key"

def verify_admin(x_admin_secret: str = Header(...)):
    if x_admin_secret != ADMIN_SECRET:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin credentials"
        )

@router.get("/users", response_model=List[UserResponse], dependencies=[Depends(verify_admin)])
def get_all_users(db: Session = Depends(get_db)):
    return db.query(User).all()

@router.get("/listings", response_model=List[ListingResponse], dependencies=[Depends(verify_admin)])
def get_all_listings(db: Session = Depends(get_db)):
    return db.query(Listing).all()

@router.get("/reviews", response_model=List[ServiceReviewResponse], dependencies=[Depends(verify_admin)])
def get_all_reviews(db: Session = Depends(get_db)):
    return db.query(ServiceReview).all()

@router.put("/listings/{id}/disable", response_model=ListingResponse, dependencies=[Depends(verify_admin)])
def disable_listing(id: str, db: Session = Depends(get_db)):
    listing = db.query(Listing).filter(Listing.id == id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    listing.status = "disabled"
    db.commit()
    db.refresh(listing)
    return listing

@router.put("/users/{id}/disable", response_model=UserResponse, dependencies=[Depends(verify_admin)])
def disable_user(id: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = False
    db.commit()
    db.refresh(user)
    return user

@router.put("/users/{id}/enable", response_model=UserResponse, dependencies=[Depends(verify_admin)])
def enable_user(id: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = True
    db.commit()
    db.refresh(user)
    return user

@router.put("/listings/{id}/enable", response_model=ListingResponse, dependencies=[Depends(verify_admin)])
def enable_listing(id: str, db: Session = Depends(get_db)):
    listing = db.query(Listing).filter(Listing.id == id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    listing.status = "active"
    db.commit()
    db.refresh(listing)
    return listing

