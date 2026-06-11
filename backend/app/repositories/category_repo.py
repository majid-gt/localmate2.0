from sqlalchemy.orm import Session
from typing import List, Optional
from app.models.models import Category

class CategoryRepository:
    @staticmethod
    def get_all_active(db: Session) -> List[Category]:
        return db.query(Category).filter(Category.is_active == True).all()

    @staticmethod
    def get_by_id(db: Session, category_id: int) -> Optional[Category]:
        return db.query(Category).filter(Category.id == category_id).first()

    @staticmethod
    def get_by_slug(db: Session, slug: str) -> Optional[Category]:
        return db.query(Category).filter(Category.slug == slug).first()

    @staticmethod
    def seed_categories(db: Session) -> None:
        initial_categories = [
            ("Electrician", "electrician"),
            ("Plumber", "plumber"),
            ("Mechanic", "mechanic"),
            ("Tutor", "tutor"),
            ("Tailor", "tailor"),
            ("Restaurant", "restaurant"),
            ("Tiffin Center", "tiffin-center"),
            ("Grocery Store", "grocery-store"),
            ("Vegetable Vendor", "vegetable-vendor"),
            ("PG", "pg"),
            ("Gym", "gym"),
            ("Doctor", "doctor"),
            ("Medical Shop", "medical-shop"),
            ("Beauty Salon", "beauty-salon")
        ]
        
        for name, slug in initial_categories:
            existing = db.query(Category).filter(Category.slug == slug).first()
            if not existing:
                category = Category(name=name, slug=slug, icon_url=f"/assets/icons/{slug}.png")
                db.add(category)
        db.commit()
