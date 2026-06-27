# Daily Diary App v1.0

## Product Overview

Daily Diary is a mobile-first journaling application designed to help users capture memories, thoughts, moods, and daily activities through either detailed journal entries or quick structured diary forms.

The application prioritizes simplicity, speed, and consistency while supporting image uploads and calendar-based browsing.

---

# Design Goals

### Simplicity

Users should be able to create an entry within 30 seconds.

### Consistency

Every screen follows the same spacing, colors, typography, and navigation patterns.

### Emotional Comfort

The interface should feel calm, personal, and distraction-free.

### Mobile First

The entire experience is optimized for Android devices.

---

# Color System

## Primary

```css
#6366F1
```

Used for:

* Primary buttons
* Active navigation icons
* Floating action button
* Interactive states

## Background

```css
#F8FAFC
```

## Card

```css
#FFFFFF
```

## Border

```css
#E5E7EB
```

## Text Primary

```css
#111827
```

## Text Secondary

```css
#6B7280
```

## Success

```css
#22C55E
```

## Warning

```css
#F59E0B
```

## Error

```css
#EF4444
```

---

# Typography

## Headings

* Font Weight: 700
* Size: 24–32px

Examples:

* Daily Diary
* Welcome Back
* Calendar

## Subheadings

* Font Weight: 500
* Size: 16–18px

## Body

* Font Weight: 400
* Size: 14–16px

---

# Navigation Structure

Splash Screen
↓
Login / Register
↓
Home
↓
Create Entry
↓
Full Diary OR Quick Diary
↓
Save Entry
↓
Calendar
↓
Entry Detail

---

# Screen Specifications

## 1. Splash Screen

### Purpose

Introduce the application.

### Components

#### Hero Illustration

Nature-themed artwork:

* Mountains
* Lake
* Sunrise

#### App Name

Daily Diary

#### Subtitle

Your thoughts, your story

#### CTA

Get Started

### Action

Navigates to Login Screen.

---

## 2. Login Screen

### Components

#### Heading

Welcome Back 👋

#### Inputs

* Email
* Password

#### Actions

* Login
* Forgot Password
* Continue with Google

#### Footer

Don't have an account? Sign Up

### Validation

* Email required
* Password required

---

## 3. Register Screen

### Components

#### Heading

Create Account

#### Inputs

* Full Name
* Email
* Password

#### Actions

* Sign Up
* Continue with Google

#### Footer

Already have an account? Login

### Validation

* Valid email
* Password minimum length
* Name required

---

## 4. Home Screen

### Purpose

Display diary timeline.

### Header

Hi, User 👋

Good to see you again

### Search Bar

Used for future diary search functionality.

### Diary Feed

Each card contains:

* Title
* Preview text
* Time
* Thumbnail image

### Floating Action Button

Position:
Bottom center

Action:
Create new entry

---

## Bottom Navigation

### Tabs

Home

Add

Calendar

Profile

---

## 5. Create Entry Screen

### Purpose

Allow users to choose diary type.

### Option 1

Full Diary

Description:
Write detailed thoughts and experiences.

### Option 2

Quick Diary

Description:
Answer a few quick questions.

---

## 6. Full Diary Screen

### Components

#### Title Field

Single line input.

#### Diary Content

Multiline editor.

#### Image Upload

Optional.

Maximum:
1 image

#### Save Button

Located in top-right corner.

### Validation

* Title required
* Content required

---

## 7. Quick Diary Screen

### Components

#### Mood Selector

Options:

😞
🙁
😐
🙂
😁

#### Energy Slider

Range:
1–10

#### Best Moment

Text field

#### Biggest Challenge

Text field

#### Save Button

Top-right corner

### Validation

Mood required.

---

## 8. Calendar Screen

### Purpose

Browse historical entries.

### Features

* Monthly calendar
* Highlight dates with entries
* Tap date to view entry

### Selected Date

Uses primary purple color.

### Preview Card

Shows:

* Title
* Short preview
* Thumbnail

---

## 9. Entry Detail Screen

### Purpose

Display complete diary.

### Components

#### Title

Large heading

#### Date

Formatted date

#### Entry Type Badge

* Full Diary
* Quick Diary

#### Image

Large preview

#### Content

Complete journal text

### Actions

* Edit
* Delete

---

## 10. Edit Entry Screen

### Features

* Update title
* Update content
* Replace image
* Save changes

### Validation

Same as create screen.

---

## 11. Image Upload Screen

### Tabs

Gallery

Camera

### Rules

Maximum images:
1

Maximum file size:
5 MB

### Flow

Select Image
→ Preview
→ Upload
→ Save URL

---

## 12. Profile Screen

### Header

Profile Picture

User Name

Email

### Statistics

My Entries

Quick Diaries

### Menu Items

Calendar

Settings

Logout

---

# Cloudinary Integration

## Upload Flow

User selects image
↓
Image compressed
↓
Upload to Cloudinary
↓
Cloudinary returns URL
↓
URL stored in PostgreSQL

### Storage Rules

Maximum images per entry:
1

Supported formats:

* JPG
* PNG
* WEBP

Maximum size:
5 MB

---

# Empty States

## No Diaries

"No entries yet. Start writing your first memory today."

## No Calendar Entries

"Nothing recorded on this day."

---

# Error States

## Network Error

"Unable to connect. Please try again."

## Upload Error

"Image upload failed. Please retry."

## Authentication Error

"Invalid email or password."

---

# Accessibility

* Touch targets minimum 48px
* Support dark mode in future phase
* Proper contrast ratios
* Large readable typography

---

# Backend Architecture

Flutter App
↓
FastAPI Backend
↓
PostgreSQL

Additional Services

Cloudinary
↓
Image Storage

Deployment

Render
↓
FastAPI API
↓
Managed PostgreSQL

---

# Phase 1 Deliverables

Authentication

* Login
* Register
* JWT Authentication

Diary Management

* Create Diary
* Edit Diary
* Delete Diary
* View Diary

Quick Diary

* Mood Tracking
* Energy Tracking
* Best Moment
* Biggest Challenge

Media

* Single Image Upload
* Cloudinary Integration

Calendar

* Monthly View
* Entry Navigation

Profile

* Basic User Information
* Logout

Deployment

* Public FastAPI URL on Render
* Android APK Release

---

# Success Criteria

A user should be able to:

1. Create an account
2. Log in securely
3. Create a full diary entry
4. Create a quick diary entry
5. Upload one image
6. Browse entries using a calendar
7. Edit entries
8. Delete entries
9. Access the application through a publicly deployed backend

Target release: v1.0 MVP
