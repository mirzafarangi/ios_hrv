#!/bin/bash

echo "🔧 Fixing Xcode Package Dependencies..."

# Clean all caches
echo "1. Cleaning caches..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ios_hrv-* 2>/dev/null
rm -rf .swiftpm 2>/dev/null
rm -rf ios_hrv.xcodeproj/project.xcworkspace/xcshareddata/swiftpm 2>/dev/null
rm -rf ios_hrv.xcodeproj/project.xcworkspace/xcuserdata 2>/dev/null
rm -rf build 2>/dev/null

echo "2. Resetting package resolved file..."
rm -f ios_hrv.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved 2>/dev/null

echo "3. Resolving packages..."
xcodebuild -resolvePackageDependencies -project ios_hrv.xcodeproj -clonedSourcePackagesDirPath .swiftpm

echo "4. Building project..."
xcodebuild -project ios_hrv.xcodeproj \
           -scheme ios_hrv \
           -configuration Debug \
           -sdk iphonesimulator \
           -derivedDataPath build \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO \
           build

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
else
    echo "❌ Build failed. Opening Xcode to manually resolve packages..."
    echo "Please:"
    echo "1. Open ios_hrv.xcodeproj in Xcode"
    echo "2. Go to File > Packages > Reset Package Caches"
    echo "3. Go to File > Packages > Resolve Package Versions"
    echo "4. Try building again"
fi
