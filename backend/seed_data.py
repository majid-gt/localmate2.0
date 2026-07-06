import sys
import os
import uuid
import json

# Add parent directory to sys.path to allow app imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal, engine, Base
from app.models.models import User, Listing, Category, ServiceReview, ContributorReview, ReputationScore, ListingImage
from app.repositories.category_repo import CategoryRepository
from app.services.reputation_service import ReputationService

def seed():
    print("Dropping and recreating database tables...")
    Base.metadata.drop_all(bind=engine)
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
        print("Seeding mock users with fixed OTPs...")
        users_data = [
            {
                "id": "8e70325a-24ca-4f84-bb27-9b9331abbf92",
                "name": "Md Majid",
                "phone_number": "9948817509",
                "email": "majid@example.com",
                "profile_photo_url": "https://api.dicebear.com/7.x/avataaars/png?seed=Felix",
                "fixed_otp": "551982"
            },
            {
                "id": "2d94821a-12ca-3f84-cc27-8b9331abbf81",
                "name": "Latheef Esnomat",
                "phone_number": "6303047522",
                "email": "latheef@example.com",
                "profile_photo_url": "https://api.dicebear.com/7.x/avataaars/png?seed=Aneka",
                "fixed_otp": "820194"
            },
            {
                "id": "7b80925c-34ca-4f84-aa27-7b9331abbf99",
                "name": "Ishrath Begum",
                "phone_number": "8096473987",
                "email": "ishrath@example.com",
                "profile_photo_url": "https://api.dicebear.com/7.x/avataaars/png?seed=Jack",
                "fixed_otp": "367415"
            },
            {
                "id": "user-4",
                "name": "Md Rasheed",
                "phone_number": "9666757551",
                "email": "rasheed@example.com",
                "profile_photo_url": "https://api.dicebear.com/7.x/avataaars/png?seed=Oliver",
                "fixed_otp": "719843"
            },
            {
                "id": "user-5",
                "name": "Putnala Rajeshri",
                "phone_number": "7674820934",
                "email": "rajeshri@example.com",
                "profile_photo_url": "https://api.dicebear.com/7.x/avataaars/png?seed=Bella",
                "fixed_otp": "948271"
            },
            {
                "id": "user-6",
                "name": "Sai Ram",
                "phone_number": "9392817168",
                "email": "sairam@example.com",
                "profile_photo_url": "https://api.dicebear.com/7.x/avataaars/png?seed=Adrian",
                "fixed_otp": "423819"
            },
            {
                "id": "user-7",
                "name": "Pyarla Prashanth",
                "phone_number": "7338133487",
                "email": "prashanth@example.com",
                "profile_photo_url": "https://api.dicebear.com/7.x/avataaars/png?seed=Luna",
                "fixed_otp": "610752"
            },
            {
                "id": "user-8",
                "name": "Jeevan Mourya",
                "phone_number": "9014244979",
                "email": "jeevan@example.com",
                "profile_photo_url": "https://api.dicebear.com/7.x/avataaars/png?seed=Felix",
                "fixed_otp": "193856"
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
                    profile_photo_url=ud["profile_photo_url"],
                    fixed_otp=ud["fixed_otp"]
                )
                db.add(u)
                db.flush()
                # Initialize Reputation Score
                rep = ReputationScore(
                    user_id=u.id,
                    total_listings=0,
                    avg_rating=0.00,
                    total_reviews=0,
                    points=0,
                    reputation_level="Bronze Contributor"
                )
                db.add(rep)
                users.append(u)
                print(f"Created user: {ud['name']}")
            else:
                users.append(existing)
                
        user_majid = db.query(User).filter(User.name == "Md Majid").first()
        user_latheef = db.query(User).filter(User.name == "Latheef Esnomat").first()
        user_ishrath = db.query(User).filter(User.name == "Ishrath Begum").first()
        
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
                "contributor_id": user_majid.id,
                "image_urls": [
                    "https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500"
                ]
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
                "contributor_id": user_latheef.id,
                "image_urls": [
                    "https://images.unsplash.com/photo-1504328345606-18bbc8c9d7d1?w=500"
                ]
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
                "contributor_id": user_majid.id,
                "image_urls": [
                    "https://images.unsplash.com/photo-1486006920555-c77dce18193b?w=500"
                ]
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
                db.flush()
                
                # Add images
                for idx, url in enumerate(ld.get("image_urls", [])):
                    img = ListingImage(
                        id=str(uuid.uuid4()),
                        listing_id=l.id,
                        image_url=url,
                        order_index=idx
                    )
                    db.add(img)
                print(f"Created listing: {ld['name']} with {len(ld.get('image_urls', []))} images")
                
        db.commit()
        
        # 3. Recalculate reputation
        print("Recalculating reputation scores...")
        ReputationService.recalculate_reputation(db, user_majid.id)
        ReputationService.recalculate_reputation(db, user_latheef.id)
        
        print("Database seeded successfully!")
        
    except Exception as e:
        print(f"ERROR: Seeding failed: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed()
