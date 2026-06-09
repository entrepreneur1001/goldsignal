# GoldSignal Cloud Functions

## `checkPriceAlerts`

Runs every **60 minutes** (Cloud Scheduler). It:

1. **Fetches fresh global prices** (livepriceofgold scraper)
2. **Fetches fresh EGP local prices** (iSagha HTML scrape)
3. **Writes** `prices/latest` and `prices/local_EGP` to Firestore
4. Queries all active alerts via collection group `alerts` where `isActive == true`
5. Evaluates price, percent-change, and 24h percent-change conditions (same logic as the Flutter app)
6. Deactivates triggered alerts in Firestore
7. Sends FCM push to `users/{uid}.fcmToken`

## `refreshPricesScheduled`

Runs every **15 minutes** (Cloud Scheduler). It:

1. Refreshes global and EGP local prices (same fetchers as above)
2. Updates `prices/latest` (including `prevRates` for global 24h % alerts) and `prices/local_EGP` (including per-karat `changePercent`)

This is the **only writer** of `prices/*` documents. Flutter clients read the shared cache but no longer write to Firestore (rules deny client writes).

No user needs to open the app for prices to refresh or background alerts to fire. Users only need to sign in once and grant notification permission (FCM token).

## Prerequisites

- Firebase project `goldsignal1001` on the **Blaze** plan (required for scheduled functions)
- Firebase CLI: `npm install -g firebase-tools` (or `npx firebase-tools`)
- Logged in: `firebase login`
- Project selected: `firebase use goldsignal1001`

## Deploy

From the repo root:

```bash
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,functions --project goldsignal1001
```

First deploy creates Cloud Scheduler jobs automatically.

## Cost (typical small app)

For a personal / early-stage app this setup is usually **pennies per month** or within Firebase free tiers:

| Service | Usage | Free tier (approx.) |
|---------|--------|---------------------|
| Cloud Functions | ~96 price refreshes/day (15 min) + 24 alert runs/day | 2M invocations/month |
| Firestore reads | ~2 price docs + alert query per run | 50K reads/day |
| Cloud Scheduler | 2 jobs | 3 free jobs/account |
| FCM push | Per triggered alert | Free |

**While the app is open**, alerts are still checked on every price refresh (client-side, no extra Cloud Function cost).

Set a [Firebase budget alert](https://console.firebase.google.com/project/goldsignal1001/usage) (e.g. $5/month) in Google Cloud Console → Billing → Budgets for peace of mind.

## iOS push (APNs)

1. Firebase Console → Project Settings → Cloud Messaging
2. Upload your APNs key or certificate
3. Rebuild the iOS app after enabling push capability in Xcode

## Logs

```bash
firebase functions:log --only checkPriceAlerts --project goldsignal1001
firebase functions:log --only refreshPricesScheduled --project goldsignal1001
```

## Price documents

| Document | Written by | Used for |
|----------|------------|----------|
| `prices/latest` | Cloud Functions only | Global prices + 24h % baseline (`prevRates`) |
| `prices/local_EGP` | Cloud Functions only | EGP buy/sell alerts + iSagha `changePercent` |

Clients may **read** these documents when authenticated; Firestore rules block client **writes**.
