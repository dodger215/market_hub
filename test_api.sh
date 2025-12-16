#!/bin/bash
# test_api.sh

echo "=== Testing Realtime Market API ===\n"

BASE_URL="http://localhost:4000/api"

echo "1. Testing health endpoint..."
curl -s "$BASE_URL/health" | jq .

echo "\n2. Testing username availability..."
curl -s "$BASE_URL/auth/check-username/testuser123" | jq .

echo "\n3. Testing registration..."
curl -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+12345678901", "username": "testuser123"}' | jq .

echo "\n4. Testing OTP request..."
curl -X POST "$BASE_URL/auth/request-otp" \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+12345678901"}' | jq .

echo "\n5. Testing OTP verification (use OTP from above)..."
echo "Enter OTP: "
read OTP

curl -X POST "$BASE_URL/auth/verify-otp" \
  -H "Content-Type: application/json" \
  -d "{\"phone_number\": \"+12345678901\", \"otp\": \"$OTP\"}" | jq .