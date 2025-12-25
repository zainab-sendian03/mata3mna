@echo off
REM Flutter Web Deployment Script for Firebase Hosting (Windows)

echo 🚀 Starting deployment process...

REM Build Flutter web app (Admin Dashboard only)
echo 📦 Building Flutter web app (Admin Dashboard)...
flutter build web --release -t lib/main_dashboard.dart

REM Check if build was successful
if %ERRORLEVEL% EQU 0 (
    echo ✅ Build successful!
    
    REM Deploy to Firebase Hosting
    echo 🔥 Deploying to Firebase Hosting...
    firebase deploy --only hosting
    
    if %ERRORLEVEL% EQU 0 (
        echo 🎉 Deployment successful!
    ) else (
        echo ❌ Deployment failed!
        exit /b 1
    )
) else (
    echo ❌ Build failed!
    exit /b 1
)

