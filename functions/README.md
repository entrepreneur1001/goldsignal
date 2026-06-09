# GoldSignal Cloud Functions

## `checkPriceAlerts`

Runs every **60 minutes** (Cloud Scheduler). It:

1. **Fetches fresh global prices** (livepriceofgold scraper)
2. **Fetches fresh EGP local prices** (iSagha HTML scrape)
3. **Writes** `prices/latest` and `prices/local_EGP` to Firestore
4. Queries all active alerts via collection group `alerts` where `isActive == true`
5. Evaluates above/below conditions (same logic as the Flutter app)
6. Deactivates triggered alerts in Firestore
7. Sends FCM push to `users/{uid}.fcmToken`

No user needs to open the app for prices to refresh or background alerts to fire. Users only need to sign in once and grant notification permission (FCM token).

## Prerequisites

- Firebase project `goldsignal1001` on the **Blaze** plan (required for scheduled functions)
- Firebase CLI: `npm install -g firebase-tools`
- Logged in: `firebase login`
- Project selected: `firebase use goldsignal1001`

## Deploy

From the repo root:

```bash
cd functions && npm install && cd ..
firebase deploy --only functions,firestore:indexes
```

First deploy creates the Cloud Scheduler job automatically.

## Cost (typical small app)

For a personal / early-stage app this setup is usually **pennies per month** or within Firebase free tiers:

| Service | Usage | Free tier (approx.) |
|---------|--------|---------------------|
| Cloud Functions | ~24 runs/day (hourly) | 2M invocations/month |
| Firestore reads | ~2 price docs + alert query per run | 50K reads/day |
| Cloud Scheduler | 1 job | 3 free jobs/account |
| FCM push | Per triggered alert | Free |

**While the app is open**, alerts are still checked on every price refresh (client-side, no extra Cloud Function cost).

Set a [Firebase budget alert](https://console.firebase.google.com/project/goldsignal1001/usage) (e.g. $5/month) in Google Cloud Console → Billing → Budgets for peace of mind.

## iOS push (APNs)

1. Firebase Console → Project Settings → Cloud Messaging
2. Upload your APNs key or certificate
3. Rebuild the iOS app after enabling push capability in Xcode

## Logs

```bash
firebase functions:log --only checkPriceAlerts
```

## Price documents

| Document | Written by | Used for |
|----------|------------|----------|
| `prices/latest` | Cloud Function (+ app cache) | Global currency alerts |
| `prices/local_EGP` | Cloud Function (+ app cache) | EGP buy/sell alerts |

The Cloud Function refreshes both documents every hour even if no app is open.
