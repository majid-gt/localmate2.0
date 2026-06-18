from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_, literal, Float, case
from typing import List, Optional, Tuple
from app.models.models import Listing, ListingImage, SavedListing, ListingSuggestion, Category
from app.schemas.schemas import ListingCreate, ListingUpdate, ListingSuggestionCreate
import uuid
import json

class ListingRepository:
    @staticmethod
    def get_by_id(db: Session, listing_id: str) -> Optional[Listing]:
        return db.query(Listing).filter(Listing.id == listing_id).first()

    @staticmethod
    def check_duplicate(db: Session, owner_phone: str, category_id: int) -> Optional[Listing]:
        # Perform check for duplicate listings
        return db.query(Listing).filter(
            and_(
                Listing.owner_phone == owner_phone,
                Listing.category_id == category_id,
                Listing.status == "active"
            )
        ).first()

    @staticmethod
    def create(db: Session, listing_in: ListingCreate, contributor_id: str) -> Listing:
        listing_id = str(uuid.uuid4())
        db_listing = Listing(
            id=listing_id,
            name=listing_in.name,
            category_id=listing_in.category_id,
            owner_name=listing_in.owner_name,
            owner_phone=listing_in.owner_phone,
            latitude=listing_in.latitude,
            longitude=listing_in.longitude,
            address=listing_in.address,
            working_days=listing_in.working_days,
            working_hours=listing_in.working_hours,
            description=listing_in.description,
            contributor_id=contributor_id,
            status="active"
        )
        db.add(db_listing)
        db.commit()
        db.refresh(db_listing)

        # Trigger reputation recalculation for contributor
        from app.services.reputation_service import ReputationService
        ReputationService.recalculate_reputation(db, contributor_id)

        return db_listing

    @staticmethod
    def update(db: Session, db_listing: Listing, listing_in: ListingUpdate) -> Listing:
        update_data = listing_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_listing, field, value)
        db.commit()
        db.refresh(db_listing)
        return db_listing

    @staticmethod
    def add_image(db: Session, listing_id: str, image_url: str, order_index: int = 0) -> ListingImage:
        db_image = ListingImage(
            id=str(uuid.uuid4()),
            listing_id=listing_id,
            image_url=image_url,
            order_index=order_index
        )
        db.add(db_image)
        db.commit()
        db.refresh(db_image)
        return db_image

    @staticmethod
    def get_my_listings(db: Session, contributor_id: str) -> List[Listing]:
        return db.query(Listing).filter(Listing.contributor_id == contributor_id).order_by(Listing.created_at.desc()).all()

    @staticmethod
    def is_open_now(working_days: list, working_hours_str: str, current_dt) -> bool:
        # Check day of week (current_dt.isoweekday(): 1=Mon, 7=Sun)
        day_of_week = current_dt.isoweekday()
        if day_of_week not in working_days:
            return False
            
        # Parse working hours range e.g. "9:00 AM - 6:00 PM"
        try:
            parts = working_hours_str.lower().split("-")
            if len(parts) != 2:
                return True # Default to open on format error
                
            start_str = parts[0].strip()
            end_str = parts[1].strip()
            
            def parse_time(time_str: str):
                time_str = time_str.replace(" ", "")
                is_pm = "pm" in time_str
                is_am = "am" in time_str
                time_str = time_str.replace("pm", "").replace("am", "")
                
                if ":" in time_str:
                    h_str, m_str = time_str.split(":")
                    hour = int(h_str)
                    minute = int(m_str)
                else:
                    hour = int(time_str)
                    minute = 0
                    
                if is_pm and hour != 12:
                    hour += 12
                elif is_am and hour == 12:
                    hour = 0
                import datetime
                return datetime.time(hour, minute)
                
            start_time = parse_time(start_str)
            end_time = parse_time(end_str)
            current_time = current_dt.time()
            
            if start_time <= end_time:
                return start_time <= current_time <= end_time
            else: # overnight
                return current_time >= start_time or current_time <= end_time
        except Exception:
            return True

    @staticmethod
    def search_listings(
        db: Session,
        q: Optional[str] = None,
        category_id: Optional[int] = None,
        lat: Optional[float] = None,
        lng: Optional[float] = None,
        radius_km: Optional[float] = None,
        sort_by: str = "created_at",
        open_now: bool = False,
        limit: int = 20,
        offset: int = 0,
        contributor_id: Optional[str] = None
    ) -> Tuple[List[Tuple[Listing, float]], int]:
        
        query = db.query(Listing).filter(Listing.status == "active")
        
        if contributor_id:
            query = query.filter(Listing.contributor_id == contributor_id)
            
        if category_id:
            query = query.filter(Listing.category_id == category_id)
            
        if q:
            # Simple keyword search on name and description
            query = query.filter(
                or_(
                    Listing.name.ilike(f"%{q}%"),
                    Listing.description.ilike(f"%{q}%"),
                    Listing.owner_name.ilike(f"%{q}%")
                )
            )

        # Distance calculation expression using Haversine formula (Earth radius = 6371 km)
        distance_col = literal(0.0) # default fallback
        if lat is not None and lng is not None:
            # Radian conversions
            rad_lat = func.radians(lat)
            rad_lng = func.radians(lng)
            db_rad_lat = func.radians(Listing.latitude)
            db_rad_lng = func.radians(Listing.longitude)
            
            # Distance formula (clamping acos value inside -1.0 and 1.0 to prevent numeric domain errors)
            cos_val = func.cos(rad_lat) * func.cos(db_rad_lat) * func.cos(db_rad_lng - rad_lng) + func.sin(rad_lat) * func.sin(db_rad_lat)
            # Safe acos
            safe_cos = case(
                (cos_val > 1.0, 1.0),
                (cos_val < -1.0, -1.0),
                else_=cos_val
            )
            distance_col = 6371 * func.acos(safe_cos)
            
            if radius_km:
                query = query.filter(distance_col <= radius_km)

        # Sorting
        if lat is not None and lng is not None and sort_by == "distance":
            query = query.order_by(distance_col.asc())
        elif sort_by == "rating":
            from app.models.models import ServiceReview
            query = query.outerjoin(ServiceReview).group_by(Listing.id).order_by(
                func.coalesce(func.avg(ServiceReview.rating), 0.0).desc(),
                Listing.created_at.desc()
            )
        elif sort_by == "reviews_count":
            from app.models.models import ServiceReview
            query = query.outerjoin(ServiceReview).group_by(Listing.id).order_by(
                func.count(ServiceReview.id).desc(),
                Listing.created_at.desc()
            )
        else:
            query = query.order_by(Listing.created_at.desc())

        # If open_now is True, we need to filter in Python
        if open_now:
            # Fetch all matching candidates (no SQL limit/offset here)
            results = query.all()
            
            # Filter in Python
            import datetime
            now_dt = datetime.datetime.now()
            
            filtered_results = []
            for listing in results:
                days = listing.working_days
                if not isinstance(days, list):
                    try:
                        days = json.loads(listing.working_days)
                    except:
                        days = [1, 2, 3, 4, 5]
                
                if ListingRepository.is_open_now(days, listing.working_hours or "", now_dt):
                    filtered_results.append(listing)
            
            total_count = len(filtered_results)
            # Apply manual limit/offset
            paginated_results = filtered_results[offset : offset + limit]
        else:
            # Total count before paging
            total_count = query.count()
            # Fetch with offset and limit
            paginated_results = query.offset(offset).limit(limit).all()

        # Calculate distance for response objects
        enriched_results = []
        for listing in paginated_results:
            dist = 0.0
            if lat is not None and lng is not None:
                # Math calculation for distance in python
                d_lat = math_rad(listing.latitude - lat)
                d_lng = math_rad(listing.longitude - lng)
                import math
                a = math.sin(d_lat/2) * math.sin(d_lat/2) + math.cos(math.radians(lat)) * math.cos(math.radians(listing.latitude)) * math.sin(d_lng/2) * math.sin(d_lng/2)
                c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
                dist = 6371 * c
            enriched_results.append((listing, dist))

        return enriched_results, total_count

    # Bookmarks
    @staticmethod
    def save_listing(db: Session, user_id: str, listing_id: str) -> SavedListing:
        existing = db.query(SavedListing).filter(
            and_(SavedListing.user_id == user_id, SavedListing.listing_id == listing_id)
        ).first()
        if existing:
            return existing
        db_saved = SavedListing(
            id=str(uuid.uuid4()),
            user_id=user_id,
            listing_id=listing_id
        )
        db.add(db_saved)
        db.commit()
        db.refresh(db_saved)
        return db_saved

    @staticmethod
    def unsave_listing(db: Session, user_id: str, listing_id: str) -> bool:
        db_saved = db.query(SavedListing).filter(
            and_(SavedListing.user_id == user_id, SavedListing.listing_id == listing_id)
        ).first()
        if db_saved:
            db.delete(db_saved)
            db.commit()
            return True
        return False

    @staticmethod
    def get_saved_listings(db: Session, user_id: str) -> List[Listing]:
        saved_relations = db.query(SavedListing).filter(SavedListing.user_id == user_id).all()
        listing_ids = [s.listing_id for s in saved_relations]
        if not listing_ids:
            return []
        return db.query(Listing).filter(Listing.id.in_(listing_ids)).all()

    # Suggestions
    @staticmethod
    def create_suggestion(db: Session, suggestion_in: ListingSuggestionCreate, listing_id: str, contributor_id: str) -> ListingSuggestion:
        db_suggestion = ListingSuggestion(
            id=str(uuid.uuid4()),
            listing_id=listing_id,
            contributor_id=contributor_id,
            comment=suggestion_in.comment,
            status="pending"
        )
        db.add(db_suggestion)
        db.commit()
        db.refresh(db_suggestion)
        return db_suggestion

def math_rad(x: float) -> float:
    import math
    return math.radians(x)
