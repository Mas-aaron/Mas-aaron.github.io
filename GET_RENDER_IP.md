# 🔍 How to Get Your Render Server IP Address

## ⚠️ CRITICAL: Airtel requires IP whitelisting!

Without whitelisting your server IP, **all Airtel payment requests will fail!**

---

## 🚀 **Method 1: Get IP from Render Shell (Easiest)**

### **Steps:**

1. Go to your Render Dashboard: https://dashboard.render.com
2. Select your web service: `food-delivery-backend`
3. Click the **"Shell"** tab (top right)
4. Wait for shell to connect
5. Run this command:
   ```bash
   curl -s ifconfig.me && echo
   ```
6. **Copy the IP address shown** (e.g., `35.123.45.67`)
7. Add it to Airtel portal under "Server IP Allowed List"

### **Example Output:**
```
35.123.45.67
```
☝️ This is your server's public IP address

---

## 🚀 **Method 2: Multiple IPs (If you have multiple instances)**

Run this to get all possible IPs:
```bash
curl -s ifconfig.me && echo
curl -s api.ipify.org && echo
curl -s icanhazip.com && echo
hostname -I
```

**Add ALL unique IPs to the whitelist!**

---

## 🚀 **Method 3: From Your Backend Logs**

1. Go to Render Dashboard → Logs
2. Make a test API call to your backend
3. Look for the IP in connection logs
4. Add that IP to whitelist

---

## ⚠️ **IMPORTANT: Render IP Behavior**

### **Free/Starter Plans:**
- Render uses **dynamic IPs**
- IP can change when service restarts
- **Problem:** You'll need to update whitelist after restarts

### **Solutions:**

#### **Option A: Paid Plan (Recommended for Production)**
- Upgrade to Render's **Pro Plan** or higher
- Get a **static IP address**
- IP never changes
- More reliable for production

#### **Option B: Update IP After Restarts (Free Plan)**
- Monitor for IP changes
- Update Airtel whitelist when IP changes
- Not ideal for production

#### **Option C: Use IP Ranges (If Render provides)**
- Contact Render support
- Ask for their IP ranges
- Whitelist entire range
- More stable

---

## 📋 **What to Add to Airtel Portal**

Go to: **Airtel Developer Portal → Settings → Server IP Allowed List**

### **For Testing (Quick Start):**
```
0.0.0.0/0
```
⚠️ **This allows ALL IPs** - Use only for initial testing!

### **For Production (Secure):**
```
35.123.45.67
```
*(Replace with your actual Render IP from Method 1)*

### **If You Have Multiple IPs:**
```
35.123.45.67
35.123.45.68
35.123.45.69
```
*Add each IP on a separate line*

### **If Using IP Range (Advanced):**
```
35.123.45.0/24
```
*This allows 35.123.45.0 - 35.123.45.255*

---

## 🧪 **How to Test IP Whitelisting**

### **Step 1: Get Your Current IP**
```bash
# In Render Shell
curl ifconfig.me
```

### **Step 2: Add to Airtel Portal**
- Copy the IP
- Go to Airtel Portal → Settings → Server IP Allowed List
- Click "Add IP"
- Paste your IP
- Save

### **Step 3: Test Payment**
```bash
# Make a test payment request
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

### **Expected Result:**
- ✅ **Success:** Payment request goes through
- ❌ **Failure:** "Forbidden" or "IP not whitelisted" error

---

## 🔧 **Render Shell Commands Reference**

### **Get Public IP:**
```bash
curl ifconfig.me
```

### **Get All Network Info:**
```bash
curl ifconfig.me && echo
ip addr show
hostname -I
```

### **Test Outbound Connection:**
```bash
curl -I https://openapiuat.airtel.africa
```

### **Check DNS:**
```bash
nslookup openapiuat.airtel.africa
```

---

## 🚨 **What Happens if IP Not Whitelisted?**

### **Airtel API Responses:**

❌ **403 Forbidden:**
```json
{
  "error": "IP address not whitelisted",
  "message": "Access denied"
}
```

❌ **Connection Refused:**
```
Failed to connect to Airtel API
Network error: Connection refused
```

❌ **Timeout:**
```
Request timeout
Unable to reach Airtel servers
```

### **In Your Logs:**
```
❌ Airtel API Error: 403 - Forbidden
💥 Network error: Connection refused
🔐 403 Forbidden - Invalid server IP
```

---

## 📊 **Recommended Configuration**

### **Development/Testing:**
```
Server IP: 0.0.0.0/0
Duration: Temporary (during testing only)
Security: Low (but convenient)
```

### **Staging:**
```
Server IP: Your actual Render IP
Duration: Update when IP changes
Security: Medium
```

### **Production:**
```
Server IP: Static IP (Render Pro plan)
Duration: Permanent
Security: High
Action: Upgrade to Render Pro for static IP
```

---

## 🎯 **Action Plan**

### **NOW (For Testing):**

1. ✅ Go to Render Shell
2. ✅ Run: `curl ifconfig.me`
3. ✅ Copy the IP address
4. ✅ Add to Airtel Portal → Server IP Allowed List
5. ✅ Save changes
6. ✅ Test a payment

### **LATER (For Production):**

1. ⏳ Upgrade to Render Pro plan
2. ⏳ Get static IP from Render
3. ⏳ Update Airtel whitelist with static IP
4. ⏳ Remove dynamic IP from whitelist
5. ⏳ Test thoroughly

---

## 💡 **Pro Tips**

### **Monitor IP Changes:**
Create a simple script to alert you if IP changes:
```python
# In your Django app
def check_ip_change():
    import requests
    current_ip = requests.get('https://ifconfig.me').text
    # Store in database and alert if changed
```

### **Fallback Strategy:**
- Keep a record of your current IP
- Set up monitoring alerts
- Have process to quickly update Airtel whitelist

### **Documentation:**
- Document your current IP
- Keep history of IP changes
- Note when you update Airtel whitelist

---

## 🆘 **Troubleshooting**

### **Problem: IP keeps changing**
**Solution:** Upgrade to Render Pro plan for static IP

### **Problem: Can't access Render Shell**
**Solution:** 
1. Check if service is running
2. Redeploy if needed
3. Use Render logs to find IP

### **Problem: Multiple IPs showing**
**Solution:** 
1. Whitelist all of them
2. Or use IP range notation
3. Contact Render support for their IP ranges

### **Problem: Still getting blocked after whitelisting**
**Solution:**
1. Double-check IP is correct
2. Wait 5-10 minutes for changes to propagate
3. Try removing and re-adding IP
4. Contact Airtel support

---

## 📞 **Support Contacts**

### **Render Support:**
- Dashboard: https://dashboard.render.com/support
- Docs: https://render.com/docs/static-ips
- Email: support@render.com
- Question: "How do I get a static IP for my web service?"

### **Airtel Support:**
- Portal: https://developers.airtel.africa/support
- Email: developers@airtel.africa
- Question: "How to whitelist dynamic IPs?"

---

## ✅ **Quick Checklist**

Before testing Airtel payments:

- [ ] Got server IP from Render Shell (`curl ifconfig.me`)
- [ ] Added IP to Airtel Portal → Server IP Allowed List
- [ ] Saved changes in Airtel Portal
- [ ] Waited 5 minutes for changes to apply
- [ ] Tested payment endpoint
- [ ] Verified in logs that request went through
- [ ] Documented the IP for future reference

---

## 🎉 **Success Criteria**

You'll know it's working when:

✅ Payment requests complete successfully
✅ No "403 Forbidden" errors
✅ Airtel API responds normally
✅ Logs show successful token generation
✅ Payments process without network errors

---

**Created:** November 7, 2025  
**Status:** 🚨 Critical Configuration Required  
**Action:** Get your Render IP NOW and whitelist it! ⏰
