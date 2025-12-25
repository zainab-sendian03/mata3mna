# مطاعمنا (Mata3mna)

A comprehensive restaurant management Flutter application with admin dashboard, owner management, and customer ordering system.

## Overview

مطاعمنا is a multi-role restaurant management platform built with Flutter, Firebase, and Supabase. It provides a complete solution for managing restaurants, menu items, and customer orders.

## Features

### Admin Dashboard
- **Restaurant Management**: Create, edit, and delete restaurants
- **Owner Account Management**: Create owner accounts with email/password authentication
- **Menu Item Management**: Manage menu items across all restaurants
- **Category Management**: Organize menu items by categories
- **Location Management**: Manage governorates and cities
- **Session Management**: Auto-login with "Remember Me" functionality
- **Password Validation**: Strong password requirements for new owner accounts

### Owner Features
- Restaurant profile management
- Menu item management
- Order management
- Restaurant information completion

### Customer Features
- Browse restaurants
- View menus
- Place orders
- Shopping cart functionality

## Recent Updates

### Admin Session Management
- ✅ **Remember Me Feature**: Admins can stay logged in across sessions
- ✅ **Auto-login**: Valid Firebase Auth sessions automatically log in admins
- ✅ **Session Restoration**: Admin session is preserved when creating new owner accounts
- ✅ **Password Storage**: Secure in-memory password storage for session restoration

### Restaurant Management Improvements
- ✅ **Password Validation**: Strong password requirements (8+ chars, uppercase, lowercase, number)
- ✅ **Restaurant Name Display**: Shows restaurant names instead of emails in owner selection
- ✅ **Loading States**: Button loading indicators during operations
- ✅ **Error Handling**: Improved error messages and user feedback

### Technical Improvements
- ✅ **Form Validation**: Comprehensive validation for all input fields
- ✅ **Responsive Design**: Optimized for desktop, tablet, and mobile
- ✅ **RTL Support**: Full Arabic language support with RTL layout

## Tech Stack

- **Framework**: Flutter
- **State Management**: GetX
- **Backend**: 
  - Firebase Authentication
  - Cloud Firestore
  - Supabase (Storage)
- **Local Storage**: SharedPreferences
- **UI**: Material Design with custom theming

## Project Structure

```
lib/
├── config/              # App configuration (routes, themes)
├── core/                # Core utilities (cache, constants)
├── features/
│   ├── auth/           # Authentication (login, signup)
│   ├── dashboard/      # Admin dashboard
│   ├── restaurant_info/ # Restaurant profile management
│   ├── home/           # Customer home screen
│   └── cart/           # Shopping cart
└── main.dart           # Main app entry point
└── main_dashboard.dart # Dashboard-only entry point (web)
```

## Getting Started

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Firebase project configured
- Supabase project configured

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd mata3mna
```

2. Install dependencies
```bash
flutter pub get
```

3. Configure Firebase
   - Add your `firebase_options.dart` file
   - Configure Firebase Authentication
   - Set up Firestore security rules

4. Configure Supabase
   - Update Supabase URL and anon key in `main.dart` and `main_dashboard.dart`

5. Run the application
```bash
# For mobile app
flutter run

# For dashboard (web)
flutter run -d chrome lib/main_dashboard.dart
```

## User Roles

### Admin
- Full access to all management features
- Can create restaurants and owner accounts
- Manages all restaurants and menu items

### Owner
- Manages their own restaurant
- Can add/edit menu items
- Views and manages orders

### Customer
- Browses restaurants and menus
- Places orders
- Manages shopping cart

## Key Features Details

### Admin Password Management
When an admin creates a new owner account:
- Admin password is stored in memory during login
- Session is automatically restored after creating owner
- If password is not stored (auto-login), admin will be prompted

### Restaurant Creation
- Admin can select existing owner or create new owner
- New owners require:
  - Valid email address
  - Strong password (8+ chars, uppercase, lowercase, number)
- Restaurant is automatically linked to owner

### Remember Me
- Admin can enable "Remember Me" on login
- Email is auto-filled on next visit
- Auto-login if Firebase Auth session is valid

## Development

### Running Tests
```bash
flutter test
```

### Building for Production
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## License

This project is private and proprietary.

## Support

For issues or questions, please contact the development team.
