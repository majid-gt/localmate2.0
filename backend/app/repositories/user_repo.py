from sqlalchemy.orm import Session
from typing import Optional
from app.models.models import User, ReputationScore
from app.schemas.schemas import UserCreate, UserUpdate
import uuid

class UserRepository:
    @staticmethod
    def get_by_id(db: Session, user_id: str) -> Optional[User]:
        return db.query(User).filter(User.id == user_id).first()

    @staticmethod
    def get_by_phone(db: Session, phone_number: str) -> Optional[User]:
        from sqlalchemy import or_
        cleaned = phone_number.replace(" ", "").replace("-", "").strip()
        if cleaned.startswith("+91"):
            raw_ten_digits = cleaned[3:]
            return db.query(User).filter(
                or_(
                    User.phone_number == cleaned,
                    User.phone_number == raw_ten_digits,
                    User.phone_number == f"+91 {raw_ten_digits}",
                    User.phone_number == f"+91{raw_ten_digits}"
                )
            ).first()
        else:
            return db.query(User).filter(
                or_(
                    User.phone_number == cleaned,
                    User.phone_number == f"+91{cleaned}",
                    User.phone_number == f"+91 {cleaned}"
                )
            ).first()

    @staticmethod
    def get_by_google_id(db: Session, google_id: str) -> Optional[User]:
        return db.query(User).filter(User.google_id == google_id).first()

    @staticmethod
    def create(db: Session, user_in: UserCreate) -> User:
        user_id = str(uuid.uuid4())
        db_user = User(
            id=user_id,
            phone_number=user_in.phone_number,
            name=user_in.name,
            email=user_in.email,
            profile_photo_url=user_in.profile_photo_url,
            google_id=user_in.google_id,
            fixed_otp=user_in.fixed_otp
        )
        db.add(db_user)
        db.flush()

        # Initialize Reputation Score
        rep = ReputationScore(
            user_id=user_id,
            total_listings=0,
            avg_rating=0.00,
            total_reviews=0,
            points=0,
            reputation_level="Bronze Contributor"
        )
        db.add(rep)
        db.commit()
        db.refresh(db_user)
        return db_user

    @staticmethod
    def update(db: Session, db_user: User, user_in: UserUpdate) -> User:
        update_data = user_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_user, field, value)
        db.commit()
        db.refresh(db_user)
        return db_user
