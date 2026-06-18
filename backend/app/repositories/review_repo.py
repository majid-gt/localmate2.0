from sqlalchemy.orm import Session
from typing import List, Optional
from app.models.models import ServiceReview, ContributorReview, Listing
from app.schemas.schemas import ServiceReviewCreate, ContributorReviewCreate
from app.services.reputation_service import ReputationService
import uuid

class ReviewRepository:
    @staticmethod
    def create_service_review(db: Session, review_in: ServiceReviewCreate, listing_id: str, author_id: str) -> ServiceReview:
        db_review = ServiceReview(
            id=str(uuid.uuid4()),
            listing_id=listing_id,
            author_id=author_id,
            rating=review_in.rating,
            comment=review_in.comment
        )
        db.add(db_review)
        db.commit()
        db.refresh(db_review)

        # Trigger reputation recalculation for the contributor who created this listing
        listing = db.query(Listing).filter(Listing.id == listing_id).first()
        if listing and listing.contributor_id:
            ReputationService.recalculate_reputation(db, listing.contributor_id)

        return db_review

    @staticmethod
    def get_service_reviews(db: Session, listing_id: str) -> List[ServiceReview]:
        return db.query(ServiceReview).filter(ServiceReview.listing_id == listing_id).order_by(ServiceReview.created_at.desc()).all()

    @staticmethod
    def create_contributor_review(db: Session, review_in: ContributorReviewCreate, contributor_id: str, author_id: str) -> ContributorReview:
        db_review = ContributorReview(
            id=str(uuid.uuid4()),
            contributor_id=contributor_id,
            author_id=author_id,
            rating=review_in.rating,
            comment=review_in.comment,
            listing_id=review_in.listing_id,
            image_url=review_in.image_url,
            special_points=review_in.special_points or 0
        )
        db.add(db_review)
        db.commit()
        db.refresh(db_review)

        # Trigger reputation recalculation for the contributor directly reviewed
        ReputationService.recalculate_reputation(db, contributor_id)

        return db_review

    @staticmethod
    def get_contributor_reviews(db: Session, contributor_id: str) -> List[ContributorReview]:
        return db.query(ContributorReview).filter(ContributorReview.contributor_id == contributor_id).order_by(ContributorReview.created_at.desc()).all()
