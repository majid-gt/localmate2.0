from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.repositories.category_repo import CategoryRepository
from app.schemas.schemas import CategoryResponse

router = APIRouter()

@router.get("/", response_model=List[CategoryResponse])
def get_categories(db: Session = Depends(get_db)):
    categories = CategoryRepository.get_all_active(db)
    if not categories:
        # Auto-seed if database is empty for easy onboarding
        CategoryRepository.seed_categories(db)
        categories = CategoryRepository.get_all_active(db)
    return categories
