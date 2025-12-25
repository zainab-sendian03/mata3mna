#!/bin/bash

# Flutter Web Deployment Script for Firebase Hosting
echo "🚀 Starting deployment process..."

# Build Flutter web app (Admin Dashboard only)
echo "📦 Building Flutter web app (Admin Dashboard)..."
flutter build web --release -t lib/main_dashboard.dart

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Deploy to Firebase Hosting
    echo "🔥 Deploying to Firebase Hosting..."
    firebase deploy --only hosting
    
    if [ $? -eq 0 ]; then
        echo "🎉 Deployment successful!"
    else
        echo "❌ Deployment failed!"
        exit 1
    fi
else
    echo "❌ Build failed!"
    exit 1
fi

