# MTN Mobile Money Integration Setup Guide

## Overview
This guide walks you through setting up MTN Mobile Money payment integration for the FortExpress food delivery backend.

## Prerequisites
1. MTN Mobile Money Developer Account
2. Subscription Key from MTN Developer Portal
3. Access to backend server with environment variable configuration

## Step-by-Step Setup

### 1. Get Your Subscription Key

1. Visit [MTN MoMo Developer Portal](https://momodeveloper.mtn.com/)
2. Sign up or log in to your account
3. Subscribe to the **Collections** product (for receiving payments)
4. Copy your **Primary Key** (Subscription Key)

### 2. Configure Environment Variables

Add the following environment variables to your server (Render, Railway, etc.):

```bash
MTN_MOMO_SUBSCRIPTION_KEY=your_primary_key_here
MTN_MOMO_BASE_URL=https://sandbox.momodeveloper.mtn.com
MTN_MOMO_ENVIRONMENT=sandbox
```

**Important:** Leave `MTN_MOMO_USER_ID` and `MTN_MOMO_API_KEY` empty for now - we'll generate these in the next steps.

### 3. Create API User (One-time Setup)

Run this command on your server to create an API user:

```bash
python manage.py setup_mtn_api --create-user
```

This will output something like:
```
✅ API User created successfully!
   User ID (X-Reference-Id): e9eeda8c-3de2-486e-abdd-1619850dc9e5

⚠️  IMPORTANT: Update your settings with this User ID:
   MTN_MOMO_CONFIG['USER_ID'] = 'e9eeda8c-3de2-486e-abdd-1619850dc9e5'
```

**Save this User ID!** You'll need to add it as an environment variable:

```bash
MTN_MOMO_USER_ID=e9eeda8c-3de2-486e-abdd-1619850dc9e5
```

### 4. Generate API Key

Run this command to generate an API key for your user:

```bash
python manage.py setup_mtn_api --get-api-key
```

This will output:
```
✅ API Key generated successfully!
   API Key: 6a4d8bc2f3e14d9ab5c7e8f1a2b3c4d5

⚠️  IMPORTANT: Update your settings with this API Key:
   MTN_MOMO_CONFIG['API_KEY'] = '6a4d8bc2f3e14d9ab5c7e8f1a2b3c4d5'
```

**Save this API Key!** Add it as an environment variable:

```bash
MTN_MOMO_API_KEY=6a4d8bc2f3e14d9ab5c7e8f1a2b3c4d5
```

### 5. Test Your Configuration

Run this command to verify everything is working:

```bash
python manage.py setup_mtn_api --test-credentials
```

Expected output:
```
✅ Credentials are valid!
   Access Token: eyJ0eXAiOiJKV1QiLCJh...
   Expires in: 3600 seconds

🎉 MTN API integration is ready to use!
```

### 6. Restart Your Server

After setting all environment variables, restart your server to load the new configuration.

## Environment Variables Summary

At the end of setup, you should have these environment variables configured:

```bash
# MTN Mobile Money Configuration
MTN_MOMO_SUBSCRIPTION_KEY=fed46b6bae2e4676a77e8b98b5ebc4f8
MTN_MOMO_USER_ID=e9eeda8c-3de2-486e-abdd-1619850dc9e5
MTN_MOMO_API_KEY=6a4d8bc2f3e14d9ab5c7e8f1a2b3c4d5
MTN_MOMO_BASE_URL=https://sandbox.momodeveloper.mtn.com
MTN_MOMO_ENVIRONMENT=sandbox
```

## Troubleshooting

### Error: "401 Unauthorized - Invalid API User ID or API Key"

**Solution:** 
- Verify your `MTN_MOMO_USER_ID` and `MTN_MOMO_API_KEY` are correct
- Make sure you've restarted the server after setting environment variables
- Re-run the API key generation: `python manage.py setup_mtn_api --get-api-key`

### Error: "403 Forbidden - Invalid Subscription Key"

**Solution:**
- Check your `MTN_MOMO_SUBSCRIPTION_KEY` is correct
- Make sure you're using the Primary Key from the Collections product
- Verify the subscription is active on the MTN Developer Portal

### Error: "404 Not Found - API User does not exist"

**Solution:**
- Run `python manage.py setup_mtn_api --create-user` to create the user
- Update `MTN_MOMO_USER_ID` with the generated ID

### Error: "400 Bad Request - Empty response"

**Possible causes:**
1. **Invalid phone number format:** MTN expects format `256783876390` (no + or spaces)
2. **API user not properly provisioned:** Re-run the setup steps 3-4
3. **Callback host mismatch:** Make sure your server URL is accessible

**To debug:**
```bash
# Check detailed logs in your server console
# Look for lines starting with 🔧, ✅, or ❌
```

### Testing with Sandbox

In sandbox mode, use these test phone numbers:
- `256783876390` - Will succeed
- `256783876391` - Will fail (for testing error handling)

**Note:** In sandbox, you won't receive actual USSD prompts. The API will simulate the response.

## Moving to Production

When you're ready for production:

1. Subscribe to MTN Mobile Money **Production** API
2. Update environment variables:
   ```bash
   MTN_MOMO_BASE_URL=https://momodeveloper.mtn.com
   MTN_MOMO_ENVIRONMENT=mtuganda  # For Uganda
   ```
3. Re-run the setup steps with production credentials
4. Test with small real transactions first

## Support

- MTN Developer Portal: https://momodeveloper.mtn.com/
- API Documentation: https://momodeveloper.mtn.com/api-documentation
- Support Email: momo.api.support@mtn.com

## Files Modified

- `backend/payments/mtn_mobile_money.py` - Main integration code
- `backend/api/management/commands/setup_mtn_api.py` - Setup command
- `backend/food_delivery/settings.py` - Configuration
- `backend/api/views.py` - Payment endpoint

## Version History

- **v2.2** (Nov 6, 2025) - Fixed API user provisioning, removed auto-provisioning
- **v2.1** (Oct 19, 2025) - Enhanced error handling and logging
- **v2.0** (Initial) - Direct MTN API integration
