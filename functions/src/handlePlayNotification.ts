/**
 * Firebase Cloud Function: handlePlayNotification
 *
 * Zpracovává Real-time Developer Notifications od Google Play.
 * Automaticky aktualizuje Firestore při:
 * - Obnovení předplatného (renewal)
 * - Zrušení předplatného (cancellation)
 * - Grace period
 * - Pozastavení účtu (account hold)
 * - Obnovení po pozastavení
 *
 * SETUP:
 * 1. Vytvořte Pub/Sub topic v Google Cloud Console
 * 2. Propojte topic s Google Play Console (Nastavení zpeněžení)
 * 3. Přidejte oprávnění pro google-play-developer-notifications@system.gserviceaccount.com
 * 4. Deploy: firebase deploy --only functions
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { google } from "googleapis";
import * as path from "path";

// Inicializace Firebase Admin (pokud ještě není)
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

// ============================================================================
// KONFIGURACE
// ============================================================================
const PACKAGE_NAME = "cz.filip.svatebniplanovac";
const SUBSCRIPTIONS_COLLECTION = "subscriptions";
const NOTIFICATION_LOG_COLLECTION = "play_notifications_log";

// Cesta k service account JSON souboru
const SERVICE_ACCOUNT_PATH = path.join(__dirname, "../play-billing-key.json");

// ============================================================================
// TYPY - Google Play Real-time Developer Notification
// ============================================================================

/**
 * Typy subscription notifikací od Google Play
 * https://developer.android.com/google/play/billing/rtdn-reference
 */
enum SubscriptionNotificationType {
  SUBSCRIPTION_RECOVERED = 1,        // Obnoveno z account hold
  SUBSCRIPTION_RENEWED = 2,          // Automaticky obnoveno
  SUBSCRIPTION_CANCELED = 3,         // Zrušeno (uživatelem nebo systémem)
  SUBSCRIPTION_PURCHASED = 4,        // Nový nákup
  SUBSCRIPTION_ON_HOLD = 5,          // Account hold (platba selhala)
  SUBSCRIPTION_IN_GRACE_PERIOD = 6,  // Grace period
  SUBSCRIPTION_RESTARTED = 7,        // Restartováno po zrušení
  SUBSCRIPTION_PRICE_CHANGE_CONFIRMED = 8, // Změna ceny potvrzena
  SUBSCRIPTION_DEFERRED = 9,         // Odloženo
  SUBSCRIPTION_PAUSED = 10,          // Pozastaveno uživatelem
  SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED = 11, // Změna plánu pozastavení
  SUBSCRIPTION_REVOKED = 12,         // Odvoláno (refund)
  SUBSCRIPTION_EXPIRED = 13,         // Vypršelo
}

interface SubscriptionNotification {
  version: string;
  notificationType: SubscriptionNotificationType;
  purchaseToken: string;
  subscriptionId: string;
}

interface DeveloperNotification {
  version: string;
  packageName: string;
  eventTimeMillis: string;
  subscriptionNotification?: SubscriptionNotification;
  testNotification?: {
    version: string;
  };
}

// ============================================================================
// HELPER: Získání Google Play API klienta
// ============================================================================
async function getPlayDeveloperClient() {
  const auth = new google.auth.GoogleAuth({
    keyFile: SERVICE_ACCOUNT_PATH,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });

  const authClient = await auth.getClient();
  return google.androidpublisher({
    version: "v3",
    auth: authClient as any,
  });
}

// ============================================================================
// HELPER: Získání aktuálních dat o předplatném z Google Play API
// ============================================================================
async function getSubscriptionDetails(
  purchaseToken: string,
  subscriptionId: string
) {
  const playDeveloper = await getPlayDeveloperClient();

  const response = await playDeveloper.purchases.subscriptions.get({
    packageName: PACKAGE_NAME,
    subscriptionId: subscriptionId,
    token: purchaseToken,
  });

  return response.data;
}

// ============================================================================
// HELPER: Najít uživatele podle purchaseToken
// ============================================================================
async function findUserByPurchaseToken(
  purchaseToken: string
): Promise<string | null> {
  const snapshot = await db
    .collection(SUBSCRIPTIONS_COLLECTION)
    .where("purchaseToken", "==", purchaseToken)
    .limit(1)
    .get();

  if (snapshot.empty) {
    return null;
  }

  return snapshot.docs[0].id; // Document ID je UID uživatele
}

// ============================================================================
// HELPER: Logování notifikace
// ============================================================================
async function logNotification(
  notification: DeveloperNotification,
  status: "processed" | "error" | "skipped",
  details?: string
) {
  try {
    await db.collection(NOTIFICATION_LOG_COLLECTION).add({
      packageName: notification.packageName,
      eventTimeMillis: notification.eventTimeMillis,
      notificationType:
        notification.subscriptionNotification?.notificationType || "test",
      subscriptionId:
        notification.subscriptionNotification?.subscriptionId || null,
      purchaseToken: notification.subscriptionNotification?.purchaseToken
        ? notification.subscriptionNotification.purchaseToken.substring(0, 30) +
          "..."
        : null,
      status,
      details,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    functions.logger.error("Failed to log notification", { error });
  }
}

// ============================================================================
// HLAVNÍ FUNKCE: handlePlayNotification
// ============================================================================
export const handlePlayNotification = functions
  .region("europe-west1")
  .pubsub.topic("play-subscriptions")
  .onPublish(async (message) => {
    // 1. Dekódování zprávy
    let notification: DeveloperNotification;

    try {
      const messageData = message.data
        ? Buffer.from(message.data, "base64").toString("utf-8")
        : null;

      if (!messageData) {
        functions.logger.error("Empty message data");
        return;
      }

      notification = JSON.parse(messageData);
      functions.logger.info("Received Play notification", {
        packageName: notification.packageName,
        eventTimeMillis: notification.eventTimeMillis,
      });
    } catch (error) {
      functions.logger.error("Failed to parse notification", { error });
      return;
    }

    // 2. Kontrola package name
    if (notification.packageName !== PACKAGE_NAME) {
      functions.logger.warn("Unknown package name", {
        received: notification.packageName,
        expected: PACKAGE_NAME,
      });
      await logNotification(notification, "skipped", "Unknown package name");
      return;
    }

    // 3. Test notifikace - jen zalogovat
    if (notification.testNotification) {
      functions.logger.info("Received test notification", {
        version: notification.testNotification.version,
      });
      await logNotification(notification, "processed", "Test notification");
      return;
    }

    // 4. Subscription notifikace
    const subNotification = notification.subscriptionNotification;
    if (!subNotification) {
      functions.logger.warn("No subscription notification in message");
      await logNotification(
        notification,
        "skipped",
        "No subscription notification"
      );
      return;
    }

    const { notificationType, purchaseToken, subscriptionId } = subNotification;

    functions.logger.info("Processing subscription notification", {
      notificationType,
      subscriptionId,
      tokenPrefix: purchaseToken.substring(0, 20) + "...",
    });

    // 5. Najít uživatele podle purchaseToken
    const uid = await findUserByPurchaseToken(purchaseToken);

    if (!uid) {
      functions.logger.warn("User not found for purchaseToken", {
        tokenPrefix: purchaseToken.substring(0, 20) + "...",
      });
      await logNotification(notification, "skipped", "User not found");
      return;
    }

    functions.logger.info("Found user for subscription", { uid });

    // 6. Zpracování podle typu notifikace
    try {
      switch (notificationType) {
        // =====================================================================
        // POZITIVNÍ UDÁLOSTI - uživatel má/bude mít Premium
        // =====================================================================
        case SubscriptionNotificationType.SUBSCRIPTION_PURCHASED:
        case SubscriptionNotificationType.SUBSCRIPTION_RENEWED:
        case SubscriptionNotificationType.SUBSCRIPTION_RECOVERED:
        case SubscriptionNotificationType.SUBSCRIPTION_RESTARTED:
          await handleSubscriptionActive(
            uid,
            purchaseToken,
            subscriptionId,
            notificationType
          );
          break;

        // =====================================================================
        // GRACE PERIOD - stále Premium, ale platba selhala
        // =====================================================================
        case SubscriptionNotificationType.SUBSCRIPTION_IN_GRACE_PERIOD:
          await handleGracePeriod(uid, purchaseToken, subscriptionId);
          break;

        // =====================================================================
        // ACCOUNT HOLD - dočasně bez Premium, čeká se na platbu
        // =====================================================================
        case SubscriptionNotificationType.SUBSCRIPTION_ON_HOLD:
        case SubscriptionNotificationType.SUBSCRIPTION_PAUSED:
          await handleSubscriptionHold(uid, notificationType);
          break;

        // =====================================================================
        // ZRUŠENÍ/EXPIRACE - uživatel přijde o Premium
        // =====================================================================
        case SubscriptionNotificationType.SUBSCRIPTION_CANCELED:
          await handleSubscriptionCanceled(uid, purchaseToken, subscriptionId);
          break;

        case SubscriptionNotificationType.SUBSCRIPTION_EXPIRED:
        case SubscriptionNotificationType.SUBSCRIPTION_REVOKED:
          await handleSubscriptionExpired(uid, notificationType);
          break;

        // =====================================================================
        // OSTATNÍ - jen zalogovat
        // =====================================================================
        case SubscriptionNotificationType.SUBSCRIPTION_PRICE_CHANGE_CONFIRMED:
        case SubscriptionNotificationType.SUBSCRIPTION_DEFERRED:
        case SubscriptionNotificationType.SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED:
          functions.logger.info("Notification type logged only", {
            notificationType,
          });
          break;

        default:
          functions.logger.warn("Unknown notification type", {
            notificationType,
          });
      }

      await logNotification(notification, "processed");
    } catch (error: any) {
      functions.logger.error("Error processing notification", {
        error: error.message,
        uid,
        notificationType,
      });
      await logNotification(notification, "error", error.message);
    }
  });

// ============================================================================
// HANDLERY PRO JEDNOTLIVÉ TYPY NOTIFIKACÍ
// ============================================================================

/**
 * Aktivní předplatné - nové, obnovené, recovered, restarted
 */
async function handleSubscriptionActive(
  uid: string,
  purchaseToken: string,
  subscriptionId: string,
  notificationType: SubscriptionNotificationType
) {
  functions.logger.info("Handling active subscription", {
    uid,
    notificationType,
  });

  // Získat aktuální data z Google Play API
  const subscriptionData = await getSubscriptionDetails(
    purchaseToken,
    subscriptionId
  );

  const expiryDate = subscriptionData.expiryTimeMillis
    ? new Date(parseInt(subscriptionData.expiryTimeMillis))
    : null;

  // Aktualizovat Firestore
  await db
    .collection(SUBSCRIPTIONS_COLLECTION)
    .doc(uid)
    .set(
      {
        tier: "premium",
        productId: subscriptionId,
        purchaseToken,
        autoRenewing: subscriptionData.autoRenewing || false,
        expiresAt: expiryDate
          ? admin.firestore.Timestamp.fromDate(expiryDate)
          : null,
        status: "active",
        lastNotificationType: notificationType,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  functions.logger.info("Subscription activated/renewed", {
    uid,
    expiresAt: expiryDate?.toISOString(),
    autoRenewing: subscriptionData.autoRenewing,
  });
}

/**
 * Grace period - uživatel má stále Premium, ale platba selhala
 */
async function handleGracePeriod(
  uid: string,
  purchaseToken: string,
  subscriptionId: string
) {
  functions.logger.info("Handling grace period", { uid });

  const subscriptionData = await getSubscriptionDetails(
    purchaseToken,
    subscriptionId
  );

  const expiryDate = subscriptionData.expiryTimeMillis
    ? new Date(parseInt(subscriptionData.expiryTimeMillis))
    : null;

  // Stále Premium, ale označíme status
  await db
    .collection(SUBSCRIPTIONS_COLLECTION)
    .doc(uid)
    .set(
      {
        tier: "premium", // Stále Premium během grace period
        status: "grace_period",
        expiresAt: expiryDate
          ? admin.firestore.Timestamp.fromDate(expiryDate)
          : null,
        lastNotificationType:
          SubscriptionNotificationType.SUBSCRIPTION_IN_GRACE_PERIOD,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  functions.logger.info("Subscription in grace period", { uid });
}

/**
 * Account hold / Paused - dočasně bez přístupu
 */
async function handleSubscriptionHold(
  uid: string,
  notificationType: SubscriptionNotificationType
) {
  functions.logger.info("Handling subscription hold/pause", {
    uid,
    notificationType,
  });

  const status =
    notificationType === SubscriptionNotificationType.SUBSCRIPTION_ON_HOLD
      ? "on_hold"
      : "paused";

  // Dočasně downgrade na free
  await db
    .collection(SUBSCRIPTIONS_COLLECTION)
    .doc(uid)
    .set(
      {
        tier: "free", // Dočasně free
        status,
        lastNotificationType: notificationType,
        holdStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  functions.logger.info("Subscription on hold/paused", { uid, status });
}

/**
 * Zrušené předplatné - může stále být aktivní do konce období
 */
async function handleSubscriptionCanceled(
  uid: string,
  purchaseToken: string,
  subscriptionId: string
) {
  functions.logger.info("Handling subscription canceled", { uid });

  const subscriptionData = await getSubscriptionDetails(
    purchaseToken,
    subscriptionId
  );

  const expiryDate = subscriptionData.expiryTimeMillis
    ? new Date(parseInt(subscriptionData.expiryTimeMillis))
    : null;

  const now = new Date();
  const isStillActive = expiryDate && expiryDate > now;

  await db
    .collection(SUBSCRIPTIONS_COLLECTION)
    .doc(uid)
    .set(
      {
        tier: isStillActive ? "premium" : "free",
        status: "canceled",
        autoRenewing: false, // Už se nebude obnovovat
        expiresAt: expiryDate
          ? admin.firestore.Timestamp.fromDate(expiryDate)
          : null,
        canceledAt: admin.firestore.FieldValue.serverTimestamp(),
        lastNotificationType:
          SubscriptionNotificationType.SUBSCRIPTION_CANCELED,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  functions.logger.info("Subscription canceled", {
    uid,
    isStillActive,
    expiresAt: expiryDate?.toISOString(),
  });
}

/**
 * Vypršené nebo revokované předplatné - okamžitý downgrade
 */
async function handleSubscriptionExpired(
  uid: string,
  notificationType: SubscriptionNotificationType
) {
  functions.logger.info("Handling subscription expired/revoked", {
    uid,
    notificationType,
  });

  const status =
    notificationType === SubscriptionNotificationType.SUBSCRIPTION_REVOKED
      ? "revoked"
      : "expired";

  await db
    .collection(SUBSCRIPTIONS_COLLECTION)
    .doc(uid)
    .set(
      {
        tier: "free",
        status,
        autoRenewing: false,
        expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        lastNotificationType: notificationType,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  functions.logger.info("Subscription expired/revoked - downgraded to free", {
    uid,
    status,
  });
}
