from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models.models import User, Listing, ServiceReview, ContributorReview, ReputationScore

class ReputationService:
    @staticmethod
    def recalculate_reputation(db: Session, user_id: str) -> ReputationScore:
        # Check if reputation score record exists
        rep = db.query(ReputationScore).filter(ReputationScore.user_id == user_id).first()
        if not rep:
            rep = ReputationScore(user_id=user_id, total_listings=0, avg_rating=0.00, total_reviews=0, points=0, reputation_level="Bronze Contributor")
            db.add(rep)
            db.flush()

        # 1. Total active listings
        active_listings = db.query(Listing).filter(Listing.contributor_id == user_id, Listing.status == "active").all()
        rep.total_listings = len(active_listings)

        # Points: +10 for each active listing
        listing_points = rep.total_listings * 10

        # 2. Reviews received by this contributor's listings
        listing_ids = [l.id for l in active_listings]
        reviews_on_listings = []
        if listing_ids:
            reviews_on_listings = db.query(ServiceReview).filter(ServiceReview.listing_id.in_(listing_ids)).all()
        
        # 3. Contributor reviews received directly
        contributor_reviews = db.query(ContributorReview).filter(ContributorReview.contributor_id == user_id).all()

        total_review_count = len(reviews_on_listings) + len(contributor_reviews)
        rep.total_reviews = total_review_count

        # Calculate average rating of recommendations
        all_ratings = [r.rating for r in reviews_on_listings] + [r.rating for r in contributor_reviews]
        if all_ratings:
            rep.avg_rating = sum(all_ratings) / len(all_ratings)
        else:
            rep.avg_rating = 0.00

        # Points for reviews: rating * 2 for reviews on listings, rating * 5 + special_points for contributor reviews
        review_points = sum(r.rating * 2 for r in reviews_on_listings) + sum(r.rating * 5 + r.special_points for r in contributor_reviews)

        # Total points
        rep.points = listing_points + review_points

        # Calculate level
        if rep.points >= 500:
            rep.reputation_level = "Gold Contributor"
        elif rep.points >= 100:
            rep.reputation_level = "Silver Contributor"
        else:
            rep.reputation_level = "Bronze Contributor"

        db.commit()
        db.refresh(rep)
        return rep
