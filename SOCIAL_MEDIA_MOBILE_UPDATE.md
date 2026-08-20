# My Digital Diary Mobile — Social Media Management Update

Implemented in the uploaded Flutter project:

- Social Media Planner available from Dashboard Tools.
- Create and edit scheduled posts.
- Long-press/select individual posts.
- Select all and bulk delete.
- Native sharing for due WhatsApp Status / WhatsApp Channel posts.
- Social Media Settings directly under Profile.
- WhatsApp number, WhatsApp Channel name and Channel URL settings.
- Instagram, Facebook, TikTok and LinkedIn identity management.
- Admin-only `Admin Social Media` menu for users whose role is `admin` or `super_admin`.

## User API endpoints expected

- GET `/api/profile/social-media`
- PUT `/api/profile/social-media/whatsapp`
- POST `/api/profile/social-media/accounts`
- DELETE `/api/profile/social-media/accounts/{account}`
- GET `/api/social-media-planner`
- POST `/api/social-media-planner`
- PUT `/api/social-media-planner/{socialMediaPost}`
- DELETE `/api/social-media-planner/{socialMediaPost}`
- POST `/api/social-media-planner/bulk-delete`
- GET `/api/social-media-planner/ready-to-share`

## Admin Mobile API expected

The new Admin screen expects:

- GET `/api/admin/social-media`
- PUT `/api/admin/social-media/users/{user}/whatsapp`
- DELETE `/api/admin/social-media/users/{user}/accounts/{account}`

Until those Laravel admin API routes/controllers are deployed, the Admin screen deliberately shows an API-not-available message instead of crashing the app.

## Recommended Laravel admin overview response

```json
{
  "data": {
    "summary": {
      "users": 10,
      "accounts": 18,
      "whatsapp_configured": 7,
      "scheduled_posts": 23
    },
    "users": [
      {
        "id": 1,
        "name": "Example User",
        "email": "user@example.com",
        "whatsapp_number": "+256700000000",
        "accounts_count": 2,
        "scheduled_posts_count": 3
      }
    ]
  }
}
```

## Build verification

Run locally using the Flutter SDK configured for this project:

```powershell
& "D:\development\flutter\bin\flutter.bat" clean
& "D:\development\flutter\bin\flutter.bat" pub get
& "D:\development\flutter\bin\flutter.bat" analyze
& "D:\development\flutter\bin\flutter.bat" run
```
