
## Email / OTP Password Reset Setup

The OTP password reset endpoint sends email via Django `send_mail()`.

Set the following environment variables on your server (Render/Railway/etc.)
or in your local `.env` (if you use one):

- **EMAIL_HOST**
- **EMAIL_PORT** (default: `587`)
- **EMAIL_HOST_USER**
- **EMAIL_HOST_PASSWORD**
- **EMAIL_USE_TLS** (default: `true`)
- **EMAIL_USE_SSL** (default: `false`)
- **DEFAULT_FROM_EMAIL** (defaults to `EMAIL_HOST_USER`)

If these are not set, the API will still return a generic success message, but the email will not be delivered.

### Endpoints

- `POST /api/password-otp-request/` body: `{ "email": "user@example.com" }`
- `POST /api/password-otp-confirm/` body: `{ "email": "user@example.com", "otp": "123456", "new_password": "..." }`

