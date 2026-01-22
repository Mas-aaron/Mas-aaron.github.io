# 🟥 Airtel Money Integration Setup Guide

## Complete Guide for Airtel Money Uganda Integration

**Created:** November 7, 2025  
**Status:** ✅ Production Ready  
**Version:** 1.0

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [API Registration](#api-registration)
4. [Configuration](#configuration)
5. [Testing](#testing)
6. [Production Deployment](#production-deployment)
7. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This integration provides **direct integration with Airtel Money API** for Uganda (UG) mobile money payments. It supports:

- ✅ Payment requests (Collection)
- ✅ Payment status checking
- ✅ Refunds
- ✅ OAuth2 authentication
- ✅ Comprehensive error handling
- ✅ Production and UAT/Staging environments

---

## 📦 Prerequisites

### **1. Developer Account**
- Sign up at [Airtel Developers Portal](https://developers.airtel.africa)
- Verify your email and complete KYC
- Request API access for Uganda

### **2. Required Credentials**
You need the following from Airtel:
- **CLIENT_ID** - OAuth client identifier
- **CLIENT_SECRET** - OAuth client secret
- **API Access** - For Collection API

### **3. Phone Number Requirements**
- **Airtel Uganda prefixes:** `070`, `075`
- **Format accepted:** 
  - `0701234567` (10 digits)
  - `256701234567` (12 digits)
  - `+256701234567` (13 digits with +)

### **4. Minimum Transaction Amount**
- **Staging/UAT:** 500 UGX minimum
- **Production:** 500 UGX minimum

---

## 🔧 API Registration

### **Step 1: Register on Airtel Developers Portal**

1. Go to https://developers.airtel.africa
2. Click **"Sign Up"** and complete registration
3. Verify your email
4. Complete business KYC (required for production)

### **Step 2: Create Application**

1. Log in to developer portal
2. Go to **"My Apps"**
3. Click **"Create New App"**
4. Fill in application details:
   - **App Name:** FortExpress Food Delivery
   - **Description:** Mobile money payments for food delivery
   - **Category:** E-commerce
   - **Country:** Uganda
   - **Products:** Collection (Payments)

5. Submit for approval

### **Step 3: Get API Credentials**

After approval, you'll receive:
```
CLIENT_ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
CLIENT_SECRET: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**⚠️ IMPORTANT:** Keep these credentials secure!

---

## ⚙️ Configuration

### **1. Environment Variables**

Add to your `.env` file or environment:

```bash
# Airtel Money Configuration
AIRTEL_MONEY_CLIENT_ID=your_client_id_here
AIRTEL_MONEY_CLIENT_SECRET=your_client_secret_here

# UAT/Staging (for testing)
AIRTEL_MONEY_BASE_URL=https://openapiuat.airtel.africa
AIRTEL_MONEY_ENV=staging

# Production (after go-live)
# AIRTEL_MONEY_BASE_URL=https://openapi.airtel.africa
# AIRTEL_MONEY_ENV=production

# Country and Currency
AIRTEL_MONEY_COUNTRY=UG
AIRTEL_MONEY_CURRENCY=UGX
```

### **2. Django Settings**

Configuration is already added in `food_delivery/settings.py`:

```python
AIRTEL_MONEY_CONFIG = {
    'CLIENT_ID': os.getenv('AIRTEL_MONEY_CLIENT_ID', 'your_client_id_here'),
    'CLIENT_SECRET': os.getenv('AIRTEL_MONEY_CLIENT_SECRET', 'your_client_secret_here'),
    'BASE_URL': os.getenv('AIRTEL_MONEY_BASE_URL', 'https://openapiuat.airtel.africa'),
    'GRANT_TYPE': 'client_credentials',
    'ENV': os.getenv('AIRTEL_MONEY_ENV', 'staging'),
    'COUNTRY': os.getenv('AIRTEL_MONEY_COUNTRY', 'UG'),
    'CURRENCY': os.getenv('AIRTEL_MONEY_CURRENCY', 'UGX'),
}
```

### **3. Render Environment Variables**

For Render deployment:

1. Go to your Render dashboard
2. Select your web service
3. Go to **Environment** tab
4. Add these variables:
   ```
   AIRTEL_MONEY_CLIENT_ID = <your_client_id>
   AIRTEL_MONEY_CLIENT_SECRET = <your_client_secret>
   AIRTEL_MONEY_BASE_URL = https://openapiuat.airtel.africa
   AIRTEL_MONEY_ENV = staging
   AIRTEL_MONEY_COUNTRY = UG
   AIRTEL_MONEY_CURRENCY = UGX
   ```
5. Click **"Save Changes"**
6. Service will redeploy automatically

---

## 🧪 Testing

### **Test 1: Payment Request (API Call)**

```bash
curl -X POST https://food-delivery-backend-2mcb.onrender.com/api/payments/initiate/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Token YOUR_TOKEN" \
  -d '{
    "order_id": "123",
    "payment_method": "airtel_money",
    "amount": "5000",
    "phone_number": "256701234567"
  }'
```

**Expected Response (Success):**
```json
{
  "success": true,
  "transaction_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "message": "Payment request sent. Please check your phone and enter your PIN.",
  "payment_id": 123
}
```

**Expected Response (Error):**
```json
{
  "success": false,
  "error": "Invalid Airtel phone number format. Must start with 070 or 075"
}
```

### **Test 2: Using Flutter App**

1. Open food delivery app
2. Add items to cart
3. Go to checkout
4. Select **"Airtel Money"** as payment method
5. Enter Airtel number: `0701234567`
6. Tap **"Pay Now"**
7. Check phone for USSD prompt
8. Enter PIN to complete payment

### **Test 3: Common Test Scenarios**

#### **Valid Airtel Number:**
```json
{
  "phone_number": "256701234567",  ✅
  "phone_number": "0701234567",    ✅
  "phone_number": "+256701234567"  ✅
}
```

#### **Invalid Numbers:**
```json
{
  "phone_number": "256781234567",  ❌ MTN number
  "phone_number": "123456789",     ❌ Too short
  "phone_number": "256901234567"   ❌ Invalid prefix
}
```

#### **Amount Tests:**
```json
{
  "amount": "5000",    ✅ Valid
  "amount": "500",     ✅ Minimum
  "amount": "100",     ❌ Below minimum
  "amount": "0"        ❌ Invalid
}
```

---

## 🚀 Production Deployment

### **Step 1: Complete KYC**

1. Submit business documents to Airtel
2. Wait for approval (usually 2-5 business days)
3. Receive production credentials

### **Step 2: Update Environment Variables**

```bash
# Production Configuration
AIRTEL_MONEY_BASE_URL=https://openapi.airtel.africa
AIRTEL_MONEY_ENV=production
AIRTEL_MONEY_CLIENT_ID=<production_client_id>
AIRTEL_MONEY_CLIENT_SECRET=<production_client_secret>
```

### **Step 3: Test in Production**

1. Start with small test transactions
2. Verify callbacks work correctly
3. Check payment status updates
4. Test refunds

### **Step 4: Go Live**

1. Update app to use Airtel Money
2. Monitor transaction success rate
3. Set up alerts for failures
4. Monitor logs for errors

---

## 🔍 Troubleshooting

### **Error: "Failed to obtain Airtel access token"**

**Cause:** Invalid CLIENT_ID or CLIENT_SECRET

**Solution:**
1. Check credentials in environment variables
2. Verify credentials are from Airtel portal
3. Ensure no extra spaces or quotes
4. Check if using correct environment (staging vs production)

```bash
# Check current config
python manage.py shell
>>> from django.conf import settings
>>> print(settings.AIRTEL_MONEY_CONFIG)
```

---

### **Error: "Invalid Airtel phone number format"**

**Cause:** Phone number doesn't match Airtel prefixes

**Solution:**
- Airtel Uganda uses: `070X`, `075X`
- Format: `256701234567` or `0701234567`
- NOT valid: `256781234567` (MTN), `256901234567` (invalid)

---

### **Error: "Amount below Airtel minimum of 500 UGX"**

**Cause:** Transaction amount < 500 UGX

**Solution:**
- Airtel requires minimum 500 UGX
- Add delivery fee if order too small
- Enforce minimum order amount in frontend

```python
# In frontend validation
if cart_total < 500:
    show_error("Minimum order amount is UGX 500")
```

---

### **Error: "Authentication failed"**

**Cause:** Token expired or invalid

**Solution:**
- Tokens expire after 1 hour
- API automatically refreshes tokens
- Check if CLIENT_SECRET is correct
- Verify API access is enabled

---

### **Error: "Transaction pending too long"**

**Cause:** User hasn't completed USSD prompt

**Solution:**
1. Check user's phone for pending prompt
2. User has 5 minutes to complete
3. After timeout, transaction automatically fails
4. Can retry payment

---

### **Checking Logs**

```bash
# On Render
# Go to: Dashboard → Your Service → Logs

# Look for Airtel-specific logs:
grep "🟥" logs.txt  # Airtel logs
grep "Airtel" logs.txt

# Common patterns:
"✅ Airtel access token obtained"  # Success
"❌ Airtel token request failed"   # Auth error
"✅ Payment request accepted"      # Payment sent
"❌ Amount below Airtel minimum"   # Validation error
```

---

## 📊 API Endpoints

### **1. OAuth Token**
```
POST /auth/oauth2/token
```
**Purpose:** Get access token  
**Called by:** System (automatic)  
**Frequency:** Every hour

### **2. Payment Request**
```
POST /merchant/v1/payments/
```
**Purpose:** Initiate payment  
**Called by:** Your API  
**Response:** Transaction ID

### **3. Payment Status**
```
GET /standard/v1/payments/{transaction_id}
```
**Purpose:** Check payment status  
**Called by:** System (after payment)  
**Response:** Transaction status

### **4. Refund**
```
POST /standard/v1/payments/refund
```
**Purpose:** Refund transaction  
**Called by:** Manual/System  
**Response:** Refund confirmation

---

## 📱 Transaction Statuses

| Status Code | Meaning | Action |
|-------------|---------|--------|
| `TS` | Successful | Complete order |
| `TF` | Failed | Show error, allow retry |
| `TA` | Ambiguous | Check again later |
| `TIP` | In Progress | Wait for completion |

---

## 🔒 Security Best Practices

### **1. Credential Storage**
- ✅ Use environment variables
- ✅ Never commit credentials to Git
- ✅ Use different keys for staging/production
- ❌ Don't hardcode in code

### **2. API Security**
- ✅ Use HTTPS only
- ✅ Validate phone numbers
- ✅ Log all transactions
- ✅ Monitor for fraud

### **3. Error Handling**
- ✅ Don't expose API errors to users
- ✅ Log detailed errors server-side
- ✅ Show user-friendly messages
- ✅ Implement retry logic

---

## 📈 Monitoring

### **Key Metrics to Track**

1. **Success Rate**
   - Target: >95%
   - Alert if <90%

2. **Response Time**
   - Target: <5s
   - Alert if >10s

3. **Failed Payments**
   - Track reasons
   - Identify patterns

4. **Token Refresh**
   - Should happen hourly
   - Alert if failing

### **Dashboard Metrics**

```python
# In Django admin or monitoring tool
- Total Airtel transactions
- Success rate (last 24h)
- Average response time
- Failed transaction reasons
- Top error codes
```

---

## 🆘 Support Contacts

### **Airtel Developer Support**
- **Email:** developers@airtel.africa
- **Portal:** https://developers.airtel.africa/support
- **Response Time:** 1-2 business days

### **Technical Issues**
- Check status: https://status.airtel.africa
- API docs: https://developers.airtel.africa/documentation

---

## ✅ Deployment Checklist

### **Before Going Live:**
- [ ] KYC completed and approved
- [ ] Production credentials obtained
- [ ] Environment variables updated
- [ ] Tested with real Airtel numbers
- [ ] Verified callbacks work
- [ ] Set up monitoring alerts
- [ ] Documented rollback plan
- [ ] Tested refund flow
- [ ] Updated user documentation
- [ ] Informed support team

### **After Launch:**
- [ ] Monitor first 100 transactions
- [ ] Check success rate
- [ ] Verify no errors in logs
- [ ] Test peak load handling
- [ ] Review customer feedback

---

## 🎉 Integration Complete!

Your Airtel Money integration is now ready! 🚀

**Key Features:**
- ✅ Direct API integration (no third-party)
- ✅ Real-time payment processing
- ✅ Automatic status updates
- ✅ Comprehensive error handling
- ✅ Production-ready code
- ✅ Full logging and monitoring

**Next Steps:**
1. Test with staging credentials
2. Complete KYC for production
3. Deploy to production
4. Monitor and optimize

---

**Questions?** Check logs or contact Airtel support! 💪🟥
