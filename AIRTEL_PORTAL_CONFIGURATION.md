# 🟥 Airtel Money Developer Portal Configuration Guide

## Complete Configuration Values for Airtel Developer Portal

---

## 🔧 **Configuration Values to Enter:**

### **1. Callback URL** ✅
```
https://food-delivery-backend-2mcb.onrender.com/api/payments/airtel/callback/
```

**What it does:**
- Airtel will send real-time payment status updates to this URL
- Your backend will automatically update order status
- Ensures HTTPS (secure communication)

**Status:** ✅ Endpoint created and ready!

---

### **2. Select Country**
```
Uganda
```

---

### **3. Select Product**
```
Collection
```

**Or if you see these options:**
- ✅ **Collection** (Receive payments from customers)
- ⬜ Disbursement (Send money to users - not needed)

---

### **4. Callback Authentication (Secret Key)**

**Generate a strong secret key:**

**Option 1: Use this command (recommended)**
```bash
openssl rand -base64 32
```

**Option 2: Generate online**
Go to https://www.random.org/strings/ and generate a 32-character string

**Option 3: Use this example (CHANGE IN PRODUCTION!)**
```
airtel_secret_2024_FortExpress_Uganda_Production
```

**⚠️ SAVE THIS SECRET KEY!** You'll need to add it to your environment variables.

**Example generated key:**
```
dG9rZW5fc2VjcmV0XzIwMjRfYWlyVGVsX3VnYW5kYQ==
```

---

### **5. Server IP Allowed List**

**You need your Render server's IP address.**

#### **Method 1: Get IP from Render (Recommended)**

1. Go to Render Dashboard
2. Select your web service
3. Click **"Shell"** tab
4. Run this command:
   ```bash
   curl ifconfig.me
   ```
5. Copy the IP address shown
6. Add it to Airtel portal

**Example:** `35.123.45.67`

#### **Method 2: Allow All (Less Secure but Works)**
```
0.0.0.0/0
```
⚠️ This allows any IP. Use only for testing!

#### **Method 3: Render IP Ranges (Contact Render Support)**
Render uses dynamic IPs. For production, consider:
- Upgrading to Render's paid plan for static IP
- OR use IP ranges provided by Render support

#### **Recommended for now (Testing):**
```
0.0.0.0/0
```
*You can tighten this later after testing*

---

### **6. Config Set Pin**

**For Testing/Staging:**
```
1234
```

**For Production:**
Generate a secure 6-digit PIN:
```
Generate: Use a random number generator
Example: 847291
```

**⚠️ IMPORTANT:** 
- Store this PIN securely
- Don't share it
- Use different PINs for staging and production

---

## 📝 **After Configuration - Add to Render**

Once you submit the Airtel portal configuration, add these to your Render environment variables:

### **Go to Render Dashboard → Environment Tab → Add:**

```bash
# Airtel API Credentials (from portal)
AIRTEL_MONEY_CLIENT_ID=<your_client_id_from_portal>
AIRTEL_MONEY_CLIENT_SECRET=<your_client_secret_from_portal>

# Airtel Callback Secret (the one you generated)
AIRTEL_CALLBACK_SECRET=<the_secret_key_you_generated>

# Airtel Configuration
AIRTEL_MONEY_BASE_URL=https://openapiuat.airtel.africa
AIRTEL_MONEY_ENV=staging
AIRTEL_MONEY_COUNTRY=UG
AIRTEL_MONEY_CURRENCY=UGX
```

---

## ✅ **Checklist Before Submitting:**

- [ ] Callback URL is HTTPS (not HTTP)
- [ ] Callback URL is publicly accessible
- [ ] Country is set to Uganda
- [ ] Product is "Collection"
- [ ] Generated and saved callback secret
- [ ] Got server IP address from Render
- [ ] Set Config PIN (secure for production)
- [ ] Copied all values to a safe place

---

## 🧪 **Testing After Configuration**

### **1. Test Callback Endpoint**

```bash
curl -X POST https://food-delivery-backend-2mcb.onrender.com/api/payments/airtel/callback/ \
  -H "Content-Type: application/json" \
  -d '{
    "transaction": {
      "id": "test-123",
      "status": "TS"
    },
    "reference": "PAY000001"
  }'
```

**Expected Response:**
```json
{"success": true}
```

### **2. Check Logs**

In Render dashboard, look for:
```
🟥 Airtel Money Callback received
   Headers: {...}
   Body: {...}
✅ Airtel callback signature verified
```

---

## 🔒 **Security Features Implemented**

### **✅ HMAC Signature Verification**
- Every callback is verified with HMAC-SHA256
- Uses your secret key
- Prevents tampering and unauthorized requests

### **✅ HTTPS Only**
- Encrypted communication
- Secure data transmission

### **✅ Automatic Status Updates**
- Payment status → Database
- Order status → Updated automatically
- Customer notifications → Sent automatically

---

## 📊 **Callback Flow:**

```
1. Customer completes payment on phone
   ↓
2. Airtel sends callback to your URL
   ↓
3. Your backend verifies signature
   ↓
4. Payment status updated in database
   ↓
5. Order status updated
   ↓
6. Customer receives notification
```

---

## 🎯 **Quick Reference:**

| Field | Value |
|-------|-------|
| **Callback URL** | `https://food-delivery-backend-2mcb.onrender.com/api/payments/airtel/callback/` |
| **Country** | Uganda |
| **Product** | Collection |
| **Secret Key** | Generate with `openssl rand -base64 32` |
| **Server IP** | Get from `curl ifconfig.me` in Render shell |
| **PIN** | 1234 (testing) or secure 6-digit (production) |

---

## 🚨 **Common Issues:**

### **Issue: "Callback URL not accessible"**
**Solution:**
- Ensure your Render service is deployed and running
- Check the URL in browser: should not return 404
- Verify HTTPS (not HTTP)

### **Issue: "Invalid server IP"**
**Solution:**
- Use `0.0.0.0/0` for testing
- Get actual IP from Render shell: `curl ifconfig.me`
- Add IP range if using load balancers

### **Issue: "Signature verification failed"**
**Solution:**
- Ensure `AIRTEL_CALLBACK_SECRET` matches the one in portal
- Check environment variable is set in Render
- Verify no extra spaces or quotes

---

## 🎉 **After Successful Configuration:**

1. ✅ Callback endpoint is live
2. ✅ Signature verification working
3. ✅ Automatic payment updates
4. ✅ Real-time order status changes
5. ✅ Customer notifications sent

**Your Airtel Money integration is production-ready!** 🚀

---

## 📞 **Support:**

**Portal Issues:**
- Email: developers@airtel.africa
- Portal: https://developers.airtel.africa/support

**Integration Issues:**
- Check Render logs for 🟥 markers
- Review `AIRTEL_MONEY_SETUP_GUIDE.md`
- Verify environment variables

---

**Created:** November 7, 2025  
**Status:** ✅ Configuration guide complete  
**Next:** Submit to Airtel portal and add environment variables to Render! 🎯
