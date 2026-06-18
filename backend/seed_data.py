import sys
import os
import uuid
import json

# Add parent directory to sys.path to allow app imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal, engine, Base
from app.models.models import User, Listing, Category, ServiceReview, ContributorReview, ReputationScore
from app.repositories.category_repo import CategoryRepository
from app.services.reputation_service import ReputationService

def seed():
    print("Recreating database tables...")
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    try:
        print("Seeding categories...")
        CategoryRepository.seed_categories(db)
        
        # Get category objects for references
        cat_electrician = db.query(Category).filter(Category.slug == "electrician").first()
        cat_plumber = db.query(Category).filter(Category.slug == "plumber").first()
        cat_mechanic = db.query(Category).filter(Category.slug == "mechanic").first()
        cat_tutor = db.query(Category).filter(Category.slug == "tutor").first()
        
        # 1. Create mock users
        print("Seeding mock users...")
        users_data = [
            {
                "id": "8e70325a-24ca-4f84-bb27-9b9331abbf92", # Keep consistent UUID
                "name": "John Doe",
                "phone_number": "+91 9999900000",
                "email": "johndoe@example.com",
                "profile_photo_url": "https://api.dicebear.com/7.x/avataaars/png?seed=John"
            },
            {
                "id": "2d94821a-12ca-3f84-cc27-8b9331abbf81",
                "name": "Majid Contributor",
                "phone_number": "+91 8888800000",
                "email": "majid@example.com",
                "profile_photo_url": "https://api.dicebear.com/7.x/avataaars/png?seed=Felix"
            },
            {
                "id": "7b80925c-34ca-4f84-aa27-7b9331abbf99",
                "name": "Resident Tester",
                "phone_number": "+91 7777700000",
                "email": "tester@example.com",
                "profile_photo_url": "https://api.dicebear.com/7.x/avataaars/png?seed=Luna"
            }
        ]
        
        users = []
        for ud in users_data:
            existing = db.query(User).filter(User.phone_number == ud["phone_number"]).first()
            if not existing:
                u = User(
                    id=ud["id"],
                    name=ud["name"],
                    phone_number=ud["phone_number"],
                    email=ud["email"],
                    profile_photo_url=ud["profile_photo_url"]
                )
                db.add(u)
                db.flush()
                users.append(u)
                print(f"Created user: {ud['name']}")
            else:
                users.append(existing)
                
        user_john = db.query(User).filter(User.phone_number == "+91 9999900000").first()
        user_majid = db.query(User).filter(User.phone_number == "+91 8888800000").first()
        user_tester = db.query(User).filter(User.phone_number == "+91 7777700000").first()
        
        # 2. Create mock listings
        print("Seeding mock listings...")
        listings_data = [
            {
                "id": "listing-1",
                "name": "Super Spark Electrician",
                "category_id": cat_electrician.id,
                "owner_name": "Ramesh Kumar",
                "owner_phone": "+91 9848012345",
                "latitude": 17.4485,
                "longitude": 78.3741,
                "address": "Gachibowli Cross Roads, Hyderabad",
                "working_days": [1, 2, 3, 4, 5, 6],
                "working_hours": "9:00 AM - 7:00 PM",
                "description": "Certified industrial and residential electrician with 10 years of experience. Quick service for appliance repairs, home wiring, and generator setup.",
                "contributor_id": user_john.id
            },
            {
                "id": "listing-2",
                "name": "Reliable Leak Fixers",
                "category_id": cat_plumber.id,
                "owner_name": "Suresh Gupta",
                "owner_phone": "+91 9848054321",
                "latitude": 17.4442,
                "longitude": 78.3489,
                "address": "Mindspace, Madhapur, Hyderabad",
                "working_days": [1, 2, 3, 4, 5],
                "working_hours": "8:00 AM - 8:00 PM",
                "description": "Specialist in fixing leakages, tap repairs, bathroom fittings, and drain cleaning. Arrives within 30 minutes in Madhapur area.",
                "contributor_id": user_majid.id
            },
            {
                "id": "listing-3",
                "name": "Auto Mech Clinic",
                "category_id": cat_mechanic.id,
                "owner_name": "Anil Reddy",
                "owner_phone": "+91 9123456789",
                "latitude": 17.4622,
                "longitude": 78.3568,
                "address": "Kondapur Main Road, Hyderabad",
                "working_days": [1, 2, 3, 4, 5, 6],
                "working_hours": "10:00 AM - 6:00 PM",
                "description": "Car and bike mechanical repairs. Highly reliable engine diagnostics, brake changes, and general servicing at highly reasonable prices.",
                "contributor_id": user_john.id
            }
        ]
        
        for ld in listings_data:
            existing = db.query(Listing).filter(Listing.name == ld["name"]).first()
            if not existing:
                l = Listing(
                    id=ld["id"],
                    name=ld["name"],
                    category_id=ld["category_id"],
                    owner_name=ld["owner_name"],
                    owner_phone=ld["owner_phone"],
                    latitude=ld["latitude"],
                    longitude=ld["longitude"],
                    address=ld["address"],
                    working_days=ld["working_days"],
                    working_hours=ld["working_hours"],
                    description=ld["description"],
                    contributor_id=ld["contributor_id"]
                )
                db.add(l)
                print(f"Created listing: {ld['name']}")
                
        db.commit()
        
        # 3. Recalculate reputation for john and majid
        print("Recalculating reputation scores...")
        ReputationService.recalculate_reputation(db, user_john.id)
        ReputationService.recalculate_reputation(db, user_majid.id)
        
        print("Database seeded successfully!")
        
    except Exception as e:
        print(f"ERROR: Seeding failed: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed()
