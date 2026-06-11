# LocalMate - Product Specification Document (Version 1.0)

## Overview

LocalMate is a mobile application that helps newcomers discover trusted local services recommended by local residents.

The primary goal is to create a community-driven directory of local businesses and service providers that may not have a strong online presence.

Examples:

* Plumbers
* Electricians
* Mechanics
* Home Tutors
* Tailors
* Tiffin Centers
* PG Owners
* Vegetable Vendors
* Small Shops
* Local Restaurants

LocalMate is initially launching in Hyderabad.

---

# Problem Statement

Many local businesses are difficult to discover online because:

* They do not have websites.
* They are not listed on Google Maps.
* They are not digitally literate.
* They do not actively maintain online profiles.

Newcomers often struggle to find reliable local services.

LocalMate bridges this gap through community-contributed listings.

---

# Core Vision

Create the most trusted community-powered local services directory.

The platform focuses on:

* Trust
* Community contribution
* Local knowledge
* Simple discovery

---

# Target Users

## Contributors

Local residents who add and maintain service listings.

Examples:

* Students
* Employees
* Residents
* Community members

Responsibilities:

* Add services
* Upload images
* Maintain listing information
* Earn reputation and rewards

---

## Newcomers

Users searching for local services.

Examples:

* Students moving to Hyderabad
* Working professionals
* Families relocating
* Visitors

Responsibilities:

* Search services
* Save services
* Review services
* Review contributors

---

# User Roles

A user can be:

* Contributor
* Newcomer
* Both

There is only one account type.

Features are unlocked based on actions.

---

# Authentication

Supported methods:

* Mobile OTP Login
* Google Login

Future:

* Apple Sign In

---

# Contributor Features

## Create Profile

Fields:

* Name
* Mobile Number
* Email (optional)
* Profile Photo

---

## Add New Listing

Required Fields:

### Service Information

* Service Name
* Category
* Owner Name
* Owner Phone Number

### Location

* Latitude
* Longitude
* Address

### Working Information

* Working Days
* Working Hours

### Media

* Multiple Images

### Description

Optional text description.

---

## Duplicate Prevention

A listing is considered duplicate if:

* Owner Phone Number matches
* Category matches

Duplicate listings are not allowed.

If duplicate exists:

Show existing listing.

Allow contributor to add comments or suggestions.

---

## My Listings

Contributor can:

* View all created listings
* Edit own listings
* View listing performance

---

## Contributor Profile

Display:

* Profile Information
* Total Listings
* Reputation Score
* Points
* Reviews Received

---

## Rewards

Initial Version:

Non-monetary rewards only.

Examples:

* Points
* Badges
* Reputation Levels

Examples:

* Bronze Contributor
* Silver Contributor
* Gold Contributor

Future:

* Redeemable Rewards
* Coupons
* Partner Benefits

---

# Newcomer Features

## Search Services

Search by:

* Service Name
* Category
* Keywords

---

## Browse Categories

Examples:

* Electrician
* Plumber
* Tutor
* Mechanic
* Restaurant
* Tailor
* PG
* Gym

---

## Nearby Services

Show services near current location.

Sort by distance.

---

## Save Listings

Users can bookmark listings.

Saved listings available in profile.

---

## Listing Details

Display:

* Service Name
* Category
* Description
* Images
* Working Hours
* Owner Name
* Owner Phone Number
* Contributor Name
* Contributor Phone Number
* Reviews
* Ratings
* Location

Actions:

* Call Owner
* Call Contributor
* Open Navigation

---

# Reviews

## Service Reviews

Users can review services.

Fields:

* Rating (1-5)
* Comment

---

## Contributor Reviews

Users can review contributors.

Fields:

* Rating (1-5)
* Comment

Purpose:

Measure quality of recommendations.

---

# Reputation System

Each contributor receives:

* Average Rating
* Total Reviews
* Total Listings
* Contribution Score

Example:

John Doe

* 120 Listings
* 4.8 Rating
* Gold Contributor

---

# Payments

Version 1:

No in-app payments.

If newcomer wants to thank contributor:

* Contact contributor directly
* Use UPI
* Use QR Code

This will be considered later.

No wallet system in MVP.

---

# Geographic Scope

Initial Launch:

Hyderabad

Future:

* Telangana
* India
* Global Expansion

---

# Categories

Initial Categories:

* Electrician
* Plumber
* Mechanic
* Tutor
* Tailor
* Restaurant
* Tiffin Center
* Grocery Store
* Vegetable Vendor
* PG
* Gym
* Doctor
* Medical Shop
* Beauty Salon

Categories should be configurable from database.

---

# Admin Panel (Minimal MVP)

Admin can:

* View Users
* View Listings
* View Reviews
* Disable Listings
* Disable Users

Future:

* Content Moderation
* Fraud Detection
* Duplicate Resolution

---

# Technology Stack

## Mobile

Flutter

Packages:

* Riverpod
* GoRouter
* Dio

---

## Backend

FastAPI

Libraries:

* SQLAlchemy
* Alembic
* Pydantic

Architecture:

* Clean Architecture
* Repository Pattern

---

## Database

PostgreSQL

---

## Cache

Redis

---

## Authentication

JWT

---

## Notifications

Firebase Cloud Messaging

Future Phase

---

## Maps

Google Maps API

Features:

* Nearby Search
* Location Selection
* Navigation

---

# Infrastructure

Initial Infrastructure:

Single GCP Virtual Machine

Operating System:

Ubuntu 24.04

Components:

* Nginx
* FastAPI
* PostgreSQL
* Redis

All services run on same VM.

---

# Storage

Version 1:

Local File Storage

Example:

/opt/localmate/uploads

Store:

* Profile Images
* Listing Images

Future:

* S3
* MinIO
* Cloud Storage

---

# Non Functional Requirements

## Performance

API Response:

< 500 ms average

---

## Availability

Target:

99% uptime

---

## Security

* Passwordless Authentication
* JWT Authentication
* HTTPS
* Input Validation

---

# Future Features

## Service Provider Accounts

Allow business owners to claim listings.

Not included in MVP.

---

## QR Based Rewards

Allow contributors to receive appreciation payments.

Not included in MVP.

---

## AI Recommendations

Personalized service recommendations.

Not included in MVP.

---

## Multi Language Support

Languages:

* English
* Telugu
* Hindi

Not included in MVP.

---

# MVP Goal

Launch quickly.

Validate whether:

1. Contributors actively add listings.
2. Newcomers use listings.
3. Reviews are generated.
4. Community trust develops.

Focus on simplicity.

Do not build advanced marketplace features until product-market fit is validated.
