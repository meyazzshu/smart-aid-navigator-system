# Smart Aid Navigator

### Optimizing Resource Delivery for Vulnerable Communities

Smart Aid Navigator (SAN) is an integrated multi-platform humanitarian aid management and delivery system designed to support NGOs, shelter managers, delivery staff, and public users in coordinating aid distribution and accessing essential humanitarian resources.

The system consists of a web application, mobile application, RESTful backend API, and centralized MySQL database.

---

## Project Overview

Smart Aid Navigator was developed to improve the management, coordination, and delivery of humanitarian aid through a centralized digital platform.

The system supports activities such as:

- Aid and donation management
- Shelter management
- Beneficiary management
- Inventory management
- Delivery management
- Multi-stop delivery planning
- Route visualization
- Shelter and aid information
- Online donations
- Proof-of-delivery submission
- Notifications
- Reporting and analytics

## System Components

### Web Application

The web application provides management and operational functionality for system administrators, NGOs, and shelter managers.

**Technologies:**

- ASP.NET Core MVC
- C#
- Razor
- HTML
- CSS
- JavaScript
- Bootstrap

### Mobile Application

The mobile application provides mobile-oriented functionality for public users and NGO/delivery staff.

**Technologies:**

- Flutter
- Dart
- Google Maps Flutter
- Geolocation services
- Firebase

### Backend API

The backend provides the RESTful API layer connecting the web application, mobile application, and database.

**Technologies:**

- PHP
- Slim Framework
- REST API
- JWT Authentication
- Composer
- PHPUnit
- PHPStan

### Database

- MySQL

---

## Key Features

### Web Dashboard

- User authentication
- Role-based access control
- Dashboard and analytics
- Shelter management
- Beneficiary management
- Aid request management
- Inventory management
- Donation management
- Delivery management
- Route planning
- Interactive maps
- Reports

### Mobile Application

- User registration and authentication
- Aid and shelter information
- Interactive map
- Shelter navigation
- Aid requests
- Donation functionality
- Shelter booking
- Delivery information
- Delivery status updates
- Navigation
- Proof-of-delivery submission
- Notifications

### Route Planning

SAN integrates Google Maps Platform for route generation and multi-stop delivery planning.

The route planning functionality provides:

- Route visualization
- Multi-stop waypoint support
- Estimated distance
- Estimated travel duration
- Navigation support

---

## Technology Stack

Component & Technologies

Web - ASP.NET Core MVC, C#, Razor, Bootstrap, JavaScript
Mobile - Flutter, Dart
Backend - PHP, Slim Framework, REST API
Database - MySQL
Maps - Google Maps Platform
Notifications - Firebase Cloud Messaging
Payment - ToyyibPay
Storage - Supabase Storage
API Testing - Postman
Testing - PHPUnit, Flutter Test, PHPStan

---

## Project Structure


smart-aid-navigator/
│
├── web/
│   └── SmartAidNavigator.Web/
│
├── api/
│   └── san_api/
│
├── mobile/
│   └── san_mobile/
│
└── docs/
    └── media/