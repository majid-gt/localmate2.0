from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
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

@router.get("/{id}", response_model=UserResponse)
def get_user_profile(id: str, db: Session = Depends(get_db)):
    user = UserRepository.get_by_id(db, id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
