#!/bin/bash

set -e

# Define constants
REGION="eu-west-1"
BUCKET_NAME="hs-frontend"  # S3 bucket for frontend files
DISTRIBUTION_ID="E1PUO62JAP45MD"  # CloudFront distribution ID for www.ragepictures.com
BUILD_DIR="build"  # Local React app build directory
BACKEND_API_URL="https://api.ragepictures.com"  # Backend API URL


# Step 2: Build React App with the backend API URL
echo "Building React app with BACKEND_API_URL=$BACKEND_API_URL..."
REACT_APP_API_URL="$BACKEND_API_URL" npm run build || { echo "React build failed"; exit 1; }

# Step 3: Upload the React app build to S3
if [ -d "$BUILD_DIR" ]; then
    echo "Uploading React app build to S3 bucket $BUCKET_NAME..."
    aws s3 sync "$BUILD_DIR"/ s3://"$BUCKET_NAME"/ --delete
    echo "React app successfully uploaded to S3."
else
    echo "Build directory $BUILD_DIR does not exist. Build might have failed."
    exit 1
fi

# Step 4: Create CloudFront Invalidation
echo "Creating CloudFront cache invalidation for distribution $DISTRIBUTION_ID..."
aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths "/*"
echo "CloudFront cache invalidation complete."

echo "Frontend deployment complete! Your website is live at: https://www.ragepictures.com"
