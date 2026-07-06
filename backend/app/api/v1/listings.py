from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form, status
from sqlalchemy.orm import Session
from typing import List, Optional
from app.core.database import get_db
from app.core.config import settings
from app.api.deps import get_current_user
from app.models.models import User, Listing
from app.repositories.listing_repo import ListingRepository
from app.repositories.category_repo import CategoryRepository
from app.schemas.schemas import ListingResponse, ListingDetailedResponse, ListingCreate, ListingUpdate, ListingSuggestionCreate, ListingSuggestionResponse
import uuid
import os
import json

router = APIRouter()

@router.post("/", response_model=ListingResponse, status_code=status.HTTP_201_CREATED)
def create_listing(
    name: str = Form(...),
    category_id: int = Form(...),
    owner_name: str = Form(...),
    owner_phone: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    address: str = Form(...),
    working_days_json: str = Form(..., description="JSON string array of integers e.g. [1,2,3,4,5]"),
    working_hours: str = Form(...),
    description: Optional[str] = Form(None),
    images: List[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Normalize phone
    phone = owner_phone.strip()
    
    # Check category existence
    cat = CategoryRepository.get_by_id(db, category_id)
    if not cat:
        raise HTTPException(status_code=400, detail="Invalid category_id")

    # Check for duplicates
    existing = ListingRepository.check_duplicate(db, phone, category_id)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "error": "duplicate_exists",
                "existing_listing_id": existing.id,
                "message": "Listing with this owner number and category already exists"
            }
        )

    # Parse working_days
    try:
        working_days = json.loads(working_days_json)
        if not isinstance(working_days, list):
            raise ValueError()
    except Exception:
        raise HTTPException(status_code=400, detail="working_days_json must be a valid JSON array of numbers")

    # Create listing input
    listing_in = ListingCreate(
        name=name,
        category_id=category_id,
        owner_name=owner_name,
        owner_phone=phone,
        latitude=latitude,
        longitude=longitude,
        address=address,
        working_days=working_days,
        working_hours=working_hours,
        description=description
    )

    db_listing = ListingRepository.create(db, listing_in, current_user.id)

    # Handle image uploads
    if images:
        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
        for idx, img in enumerate(images):
            # Safe filename
            ext = os.path.splitext(img.filename)[1] or ".jpg"
            img_id = str(uuid.uuid4())
            filename = f"{img_id}{ext}"
            file_path = os.path.join(settings.UPLOAD_DIR, filename)
            
            with open(file_path, "wb") as f:
                f.write(img.file.read())
            
            # Save mapping in database
            # URL will point to static folder or API download route
            image_url = f"/uploads/{filename}"
            ListingRepository.add_image(db, db_listing.id, image_url, order_index=idx)

    # Refresh and return
    db.refresh(db_listing)
    return db_listing

@router.get("/", response_model=List[ListingResponse])
def search_listings(
    q: Optional[str] = None,
    category_id: Optional[int] = None,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    radius_km: Optional[float] = None,
    sort_by: str = "created_at",
    open_now: bool = False,
    limit: int = 20,
    offset: int = 0,
    contributor_id: Optional[str] = None,
    db: Session = Depends(get_db)
):
    results, _ = ListingRepository.search_listings(
        db, q=q, category_id=category_id, lat=latitude, lng=longitude,
        radius_km=radius_km, sort_by=sort_by, open_now=open_now, limit=limit, offset=offset,
        contributor_id=contributor_id
    )
    
    # Map results and inject calculated distances, ratings & open status
    output = []
    import datetime
    from datetime import timezone, timedelta
    now_dt = datetime.datetime.now(timezone(timedelta(hours=5, minutes=30)))
    for listing, dist in results:
        # We set the transient properties to populate the schemas
        listing.distance = round(dist, 2) if (latitude is not None and longitude is not None) else None
        
        # Calculate rating & review count
        ratings = [r.rating for r in listing.reviews]
        listing.average_rating = round(sum(ratings) / len(ratings), 1) if ratings else 0.0
        listing.reviews_count = len(ratings)
        
        # Check open status
        days = listing.working_days
        if not isinstance(days, list):
            try:
                days = json.loads(listing.working_days)
            except:
                days = [1, 2, 3, 4, 5]
        listing.is_open = ListingRepository.is_open_now(days, listing.working_hours or "", now_dt)
        
        output.append(listing)
    return output

@router.get("/my-listings", response_model=List[ListingResponse])
def get_my_listings(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return ListingRepository.get_my_listings(db, current_user.id)

@router.get("/{id}", response_model=ListingDetailedResponse)
def get_listing_detail(id: str, db: Session = Depends(get_db)):
    listing = ListingRepository.get_by_id(db, id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    
    # Calculate average rating, reviews count and open status of listing
    ratings = [r.rating for r in listing.reviews]
    listing.average_rating = round(sum(ratings) / len(ratings), 1) if ratings else 0.0
    listing.reviews_count = len(ratings)
    
    import datetime
    from datetime import timezone, timedelta
    now_dt = datetime.datetime.now(timezone(timedelta(hours=5, minutes=30)))
    days = listing.working_days
    if not isinstance(days, list):
        try:
            days = json.loads(listing.working_days)
        except:
            days = [1, 2, 3, 4, 5]
    listing.is_open = ListingRepository.is_open_now(days, listing.working_hours or "", now_dt)
    
    return listing

@router.put("/{id}", response_model=ListingResponse)
def update_listing(
    id: str,
    listing_in: ListingUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    listing = ListingRepository.get_by_id(db, id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
        
    # Permission check: only owner/contributor can edit
    if listing.contributor_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to edit this listing")
        
    return ListingRepository.update(db, listing, listing_in)

@router.post("/{id}/suggestions", response_model=ListingSuggestionResponse)
def create_suggestion(
    id: str,
    suggestion_in: ListingSuggestionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    listing = ListingRepository.get_by_id(db, id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
        
    return ListingRepository.create_suggestion(db, suggestion_in, id, current_user.id)
