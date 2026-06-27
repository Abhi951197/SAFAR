# Product Requirements Document (PRD)

# Daily Diary App

Version: 1.0 MVP

Author: Abhishek Pal

Status: Planning

Target Platform: Android

Backend: FastAPI

Database: PostgreSQL

Deployment: Render

Storage: Cloudinary

---

# 1. Product Overview

Daily Diary is a mobile journaling application that enables users to capture daily memories, thoughts, emotions, and experiences through either detailed diary entries or quick structured journals.

The primary goal is to help users build a journaling habit while keeping the process simple and accessible.

The application supports image attachments, calendar-based navigation, and secure cloud storage.

---

# 2. Problem Statement

Many people want to maintain a diary but often stop because:

* Writing long entries takes time.
* Existing journaling apps feel complicated.
* Users forget to maintain consistency.
* Quick daily reflections are difficult to capture.

The product solves this problem by providing:

1. Full diary entries for detailed journaling.
2. Quick diary entries for busy days.
3. Calendar navigation for memory retrieval.
4. Simple image-based memory preservation.

---

# 3. Product Vision

Become a personal memory companion that allows users to record, revisit, and understand their life experiences.

Future versions will include:

* Voice journals
* AI summaries
* Mood tracking
* Personal memory search
* Life analytics

---

# 4. Goals

## Primary Goals

* Enable users to record daily memories.
* Reduce friction for daily journaling.
* Support image-based memory storage.
* Create a consistent journaling experience.

## Secondary Goals

* Build a scalable backend architecture.
* Prepare infrastructure for AI features.
* Support future multi-device synchronization.

---

# 5. Success Metrics

## Product Metrics

### User Registration

Target:

* 50 registered users

### Diary Creation

Target:

* 100+ diary entries created

### Retention

Target:

* 30% users return within 7 days

### Engagement

Target:

* Average 3+ entries per user

---

# 6. Target Audience

## Primary Audience

Students

Examples:

* College students
* University students
* Exam preparation users

## Secondary Audience

Working professionals

Examples:

* Software engineers
* Remote workers
* Freelancers

## User Characteristics

* Mobile-first users
* Interested in self-reflection
* Need quick journaling options
* Want private personal records

---

# 7. User Personas

## Persona 1: Busy Student

Age: 18–25

Goals:

* Record daily achievements
* Track academic progress

Pain Points:

* Limited time
* Forgetfulness

Preferred Feature:

Quick Diary

---

## Persona 2: Working Professional

Age: 22–35

Goals:

* Record experiences
* Maintain work-life reflections

Pain Points:

* Inconsistent journaling habits

Preferred Feature:

Full Diary

---

# 8. User Stories

## Authentication

As a user,

I want to create an account

So that my diary remains private.

---

As a user,

I want to log into my account

So that I can access my journals.

---

## Full Diary

As a user,

I want to write detailed diary entries

So that I can preserve memories.

---

As a user,

I want to edit my diary

So that I can update information later.

---

As a user,

I want to delete diary entries

So that I can manage my content.

---

## Quick Diary

As a user,

I want to answer a few simple questions

So that I can journal even when I am busy.

---

## Calendar

As a user,

I want to view my entries by date

So that I can revisit past memories.

---

## Media Upload

As a user,

I want to upload an image

So that I can preserve visual memories.

---

# 9. Functional Requirements

## Authentication

### FR-1

User shall register using:

* Name
* Email
* Password

### FR-2

User shall log in securely.

### FR-3

System shall use JWT authentication.

### FR-4

Users shall remain authenticated between sessions.

---

## Diary Management

### FR-5

User shall create diary entries.

### FR-6

User shall view diary entries.

### FR-7

User shall edit diary entries.

### FR-8

User shall delete diary entries.

---

## Quick Diary

### FR-9

User shall select mood.

### FR-10

User shall select energy level.

### FR-11

User shall provide best moment.

### FR-12

User shall provide biggest challenge.

---

## Calendar

### FR-13

User shall view entries in monthly calendar format.

### FR-14

User shall select dates.

### FR-15

System shall display entries associated with selected dates.

---

## Image Upload

### FR-16

User shall upload one image per entry.

### FR-17

System shall store images in Cloudinary.

### FR-18

System shall save Cloudinary URLs in PostgreSQL.

---

# 10. Non-Functional Requirements

## Performance

API response time:

< 500 ms

Image upload:

< 5 seconds

---

## Availability

Target:

99% uptime

---

## Security

Passwords must be hashed.

JWT authentication required.

HTTPS required.

Users may only access their own diaries.

---

## Scalability

Architecture must support:

* 10,000 users
* 100,000+ diary entries

without major redesign.

---

# 11. MVP Scope (Phase 1)

Included:

✅ Authentication

✅ Full Diary

✅ Quick Diary

✅ Image Upload

✅ Calendar View

✅ Profile Screen

✅ Render Deployment

✅ Cloudinary Integration

---

Excluded:

❌ Voice Recording

❌ AI Summaries

❌ Push Notifications

❌ Mood Analytics

❌ Memory Search

❌ Multi-device Sync

❌ Offline Mode

These features belong to future phases.

---

# 12. Technical Architecture

Frontend

Flutter

↓

Backend

FastAPI

↓

Database

PostgreSQL

↓

Storage

Cloudinary

↓

Deployment

Render

---

# 13. Database Entities

## Users

Fields:

* id
* name
* email
* password_hash
* created_at

---

## Diary Entries

Fields:

* id
* user_id
* title
* content
* entry_type
* mood
* energy
* best_moment
* challenge
* image_url
* entry_date
* created_at
* updated_at

---

# 14. API Requirements

Authentication

POST /auth/register

POST /auth/login

GET /auth/me

---

Diary

GET /entries

GET /entries/{id}

POST /entries

PUT /entries/{id}

DELETE /entries/{id}

---

Image Upload

POST /upload/image

---

# 15. Release Criteria

Version 1.0 may be released when:

* User registration works.
* Login works.
* JWT authentication works.
* Full diary works.
* Quick diary works.
* Image upload works.
* Calendar navigation works.
* Backend deployed on Render.
* Database deployed and accessible.
* No critical bugs remain.

---

# 16. Future Roadmap

## Phase 2

* Voice Journaling
* Search
* Analytics Dashboard

## Phase 3

* AI Daily Summary
* Mood Analysis
* Smart Tags

## Phase 4

* Memory Search Assistant
* Semantic Retrieval
* Personal Knowledge Base

## Phase 5

* Offline Support
* Notifications
* Multi-device Sync
* Production Scaling

---

# Product Success Definition

The product is successful when a user can consistently record daily experiences in less than one minute, revisit memories easily through the calendar, and maintain a personal journal without friction.
