# GCS Bucket Public Access Configuration

## Step 1: Configure Bucket via Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/storage)
2. Select your project: `fortexpress-5641c`
3. Find your bucket: `storage-bucket-fortexpress`
4. Click on the bucket name to open it

## Step 2: Set Bucket Permissions

1. Click on the **"Permissions"** tab
2. Click **"Grant Access"**
3. Add the following:
   - **New principals**: `allUsers`
   - **Role**: `Storage Object Viewer`
4. Click **"Save"**

## Step 3: Configure CORS (if needed)

1. In the bucket details, click on the **"Configuration"** tab
2. Scroll down to **"CORS"** section
3. Click **"Edit"**
4. Add this CORS configuration:

```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
```

## Step 4: Verify Public Access

After configuration, test that images are publicly accessible:
- Upload a test image via the Django API
- Try accessing the GCS URL directly in a browser
- The image should load without authentication

## Alternative: Command Line Setup

If you prefer using the command line, run:

```bash
# Make bucket publicly readable
gsutil iam ch allUsers:objectViewer gs://storage-bucket-fortexpress

# Set CORS configuration
gsutil cors set cors.json gs://storage-bucket-fortexpress
```

Where `cors.json` contains:
```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
```
