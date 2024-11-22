#!/bin/bash

set -e

# Define constants
REGION="eu-west-1"
BUCKET_NAME="hs-frontend"
CLOUDFRONT_ORIGIN_ACCESS_IDENTITY="frontend-oai"
LOG_GROUP="/cloudfront/frontend"
BUILD_DIR="build" # Local React build directory
BACKEND_API_URL=${1:-"http://34.244.165.36"} # Backend URL as argument, defaults to your backend
CUSTOM_DOMAIN="www.ragepictures.com" # Replace with your custom domain name
HOSTED_ZONE_ID="Z0740850TUIJ293TTJXN" # Replace with your Route 53 Hosted Zone ID

# Helper function to exit with error
error_exit() {
    echo "$1" >&2
    exit 1
}

echo "=== AWS Static React App Deployment Script ==="

# Step 1: Check if the S3 bucket exists
BUCKET_EXISTS=$(aws s3api head-bucket --bucket "$BUCKET_NAME" 2>&1 || true)
if [[ "$BUCKET_EXISTS" == *"NotFound"* ]]; then
    echo "S3 Bucket $BUCKET_NAME does not exist. Creating bucket..."
    aws s3 mb s3://"$BUCKET_NAME" --region "$REGION"
    aws s3 website s3://"$BUCKET_NAME"/ --index-document index.html --error-document index.html
    echo "S3 Bucket $BUCKET_NAME created and configured for static website hosting."
else
    echo "S3 Bucket $BUCKET_NAME already exists."
fi

# Step 2: Remove Block Public Access for S3 Bucket
echo "Removing Block Public Access settings on S3 bucket $BUCKET_NAME..."
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration '{"BlockPublicAcls": false, "IgnorePublicAcls": false, "BlockPublicPolicy": false, "RestrictPublicBuckets": false}' \
  --region "$REGION"
echo "Block public access settings updated."

# Step 3: Attach Bucket Policy for Public Access
echo "Configuring bucket policy..."
POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
        }
    ]
}
EOF
)
echo "$POLICY" > bucket-policy.json
aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy file://bucket-policy.json
rm -f bucket-policy.json
echo "Bucket policy applied."

# Step 4: Build React App
if [ -d "$BUILD_DIR" ]; then
    echo "Cleaning up existing build directory..."
    rm -rf "$BUILD_DIR"
fi
echo "Building React app with BACKEND_API_URL=$BACKEND_API_URL..."
REACT_APP_API_URL="$BACKEND_API_URL" npm run build || error_exit "React build failed."

# Step 5: Upload React App Build to S3
if [ -d "$BUILD_DIR" ]; then
    echo "Uploading React app build to S3..."
    aws s3 sync "$BUILD_DIR"/ s3://"$BUCKET_NAME"/
    echo "React app successfully uploaded to S3."
else
    error_exit "Build directory ($BUILD_DIR) does not exist. Build might have failed."
fi

# Step 6: Check or Request SSL Certificate for Custom Domain
echo "Checking for an existing SSL certificate for $CUSTOM_DOMAIN..."
EXISTING_CERTIFICATE_ARN=$(aws acm list-certificates \
  --query "CertificateSummaryList[?DomainName=='$CUSTOM_DOMAIN'].CertificateArn | [0]" \
  --output text \
  --region "$REGION")

if [ "$EXISTING_CERTIFICATE_ARN" != "None" ]; then
  echo "Existing certificate found: $EXISTING_CERTIFICATE_ARN"
  CERTIFICATE_ARN="$EXISTING_CERTIFICATE_ARN"
else
  echo "No existing certificate found. Requesting a new SSL certificate for $CUSTOM_DOMAIN..."
  CERTIFICATE_ARN=$(aws acm request-certificate \
    --domain-name "$CUSTOM_DOMAIN" \
    --validation-method DNS \
    --query "CertificateArn" \
    --output text \
    --region "$REGION")
  echo "New certificate requested. ARN: $CERTIFICATE_ARN"
fi

# Step 7: Output DNS validation details
VALIDATION_DETAILS=$(aws acm describe-certificate \
  --certificate-arn "$CERTIFICATE_ARN" \
  --query "Certificate.DomainValidationOptions[0].ResourceRecord" \
  --region "$REGION")
echo "Add the following CNAME record to validate your domain:"
echo "$VALIDATION_DETAILS"

echo "Waiting for certificate validation..."
while true; do
    STATUS=$(aws acm describe-certificate --certificate-arn "$CERTIFICATE_ARN" --query "Certificate.Status" --output text --region "$REGION")
    if [ "$STATUS" == "ISSUED" ]; then
        echo "Certificate issued successfully!"
        break
    else
        echo "Certificate status: $STATUS. Waiting for validation..."
        sleep 30
    fi
done

# Step 8: Check or Create CloudFront Distribution
DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[0].DomainName=='$BUCKET_NAME.s3.amazonaws.com'].Id" --output text)
if [ "$DISTRIBUTION_ID" != "None" ]; then
    echo "CloudFront distribution already exists: $DISTRIBUTION_ID"
else
    echo "Creating CloudFront distribution..."
    DISTRIBUTION_CONFIG=$(cat <<EOF
{
    "CallerReference": "$(date +%s)",
    "Aliases": {
        "Quantity": 1,
        "Items": [
            "$CUSTOM_DOMAIN"
        ]
    },
    "DefaultRootObject": "index.html",
    "Origins": {
        "Quantity": 1,
        "Items": [
            {
                "Id": "$BUCKET_NAME",
                "DomainName": "$BUCKET_NAME.s3.amazonaws.com",
                "OriginPath": "",
                "S3OriginConfig": {
                    "OriginAccessIdentity": ""
                }
            }
        ]
    },
    "DefaultCacheBehavior": {
        "TargetOriginId": "$BUCKET_NAME",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"],
            "CachedMethods": {
                "Quantity": 2,
                "Items": ["GET", "HEAD"]
            }
        },
        "SmoothStreaming": false,
        "Compress": true,
        "LambdaFunctionAssociations": {
            "Quantity": 0
        },
        "FieldLevelEncryptionId": "",
        "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6"
    },
    "ViewerCertificate": {
        "ACMCertificateArn": "$CERTIFICATE_ARN",
        "SSLSupportMethod": "sni-only",
        "MinimumProtocolVersion": "TLSv1.2_2021"
    },
    "Comment": "CloudFront distribution for React app",
    "PriceClass": "PriceClass_100",
    "Enabled": true
}
EOF
)
    echo "$DISTRIBUTION_CONFIG" > distribution-config.json
    aws cloudfront create-distribution --distribution-config file://distribution-config.json
    rm -f distribution-config.json
    echo "CloudFront distribution created."
fi

# Step 9: Add DNS Record for Custom Domain
echo "Adding DNS record for $CUSTOM_DOMAIN..."
CLOUDFRONT_DOMAIN=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[0].DomainName=='$BUCKET_NAME.s3.amazonaws.com'].DomainName" --output text)
aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch '{
      "Changes": [
          {
              "Action": "UPSERT",
              "ResourceRecordSet": {
                  "Name": "'"$CUSTOM_DOMAIN"'",
                  "Type": "CNAME",
                  "TTL": 300,
                  "ResourceRecords": [
                      {
                          "Value": "'"$CLOUDFRONT_DOMAIN"'"
                      }
                  ]
              }
          }
      ]
  }'
echo "DNS record added for $CUSTOM_DOMAIN."

echo "Deployment complete! Your React app is now live at: https://$CUSTOM_DOMAIN"
