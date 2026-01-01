/**
 * Firebase Cloud Function: verifyPlaySubscription
 *
 * Server-side validace Google Play subscription nákupu.
 * Ověřuje purchaseToken přes Google Play Developer API.
 *
 * SETUP:
 * 1. Vygeneruj NOVÝ service account JSON klíč v Google Cloud Console
 * 2. Ulož ho jako functions/play-billing-key.json
 * 3. Přidej play-billing-key.json do .gitignore!
 * 4. Deploy: firebase deploy --only functions
 *
 * DŮLEŽITÉ: Nikdy necommituj JSON klíč do gitu!
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
const PACKAGE_NAME = "cz.filip.svatebniplanovac";  // OPRAVENO!
const SUBSCRIPTIONS_COLLECTION = "subscriptions";
const PROCESSED_ORDERS_COLLECTION = "processed_orders";

// Cesta k service account JSON souboru
const SERVICE_ACCOUNT_PATH = path.join(__dirname, "../play-billing-key.json");

// ============================================================================
// TYPY
// ============================================================================
interface VerifyRequest {
  uid: string;
  productId: string;
  purchaseToken: string;
  platform: "android" | "ios";
}

interface VerifyResponse {
  valid: boolean;
  orderId?: string;
  expiryTimeMillis?: string;
  autoRenewing?: boolean;
  priceAmountMicros?: string;
  priceCurrencyCode?: string;
  error?: string;
  alreadyProcessed?: boolean;
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
// HLAVNÍ FUNKCE: verifyPlaySubscription
// ============================================================================
export const verifyPlaySubscription = functions
  .region("europe-west1")
  .https.onCall(async (data: VerifyRequest, context): Promise<VerifyResponse> => {
    // 1. Ověření autentizace
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Uživatel musí být přihlášen."
      );
    }

    const callerUid = context.auth.uid;

    // 2. Validace vstupních dat
    const { uid, productId, purchaseToken, platform } = data;

    if (!uid || !productId || !purchaseToken) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Chybí povinné parametry: uid, productId, purchaseToken"
      );
    }

    // Ověření, že caller je stejný jako uid (bezpečnost)
    if (callerUid !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "UID nesouhlasí s přihlášeným uživatelem."
      );
    }

    // Prozatím pouze Android
    if (platform !== "android") {
      throw new functions.https.HttpsError(
        "unimplemented",
        "Pouze Android platform je momentálně podporován."
      );
    }

    functions.logger.info("Verifying purchase", {
      uid,
      productId,
      tokenPrefix: purchaseToken.substring(0, 20) + "...",
    });

    try {
      // 3. Získání Google Play API klienta
      functions.logger.info("Getting Play Developer client...");
      const playDeveloper = await getPlayDeveloperClient();

      // 4. Ověření subscription přes Google Play Developer API
      functions.logger.info("Calling Google Play API", {
        packageName: PACKAGE_NAME,
        subscriptionId: productId,
      });

      const response = await playDeveloper.purchases.subscriptions.get({
        packageName: PACKAGE_NAME,
        subscriptionId: productId,
        token: purchaseToken,
      });

      const subscriptionData = response.data;

      functions.logger.info("Google Play API response SUCCESS", {
        orderId: subscriptionData.orderId,
        paymentState: subscriptionData.paymentState,
        expiryTimeMillis: subscriptionData.expiryTimeMillis,
        autoRenewing: subscriptionData.autoRenewing,
      });

      // 5. Kontrola validity
      // paymentState: 0 = pending, 1 = received, 2 = free trial, 3 = deferred
      const isValid =
        subscriptionData.paymentState === 1 ||
        subscriptionData.paymentState === 2;

      if (!isValid) {
        functions.logger.warn("Invalid payment state", {
          paymentState: subscriptionData.paymentState,
        });
        return {
          valid: false,
          error: "Platba nebyla dokončena nebo je v čekajícím stavu.",
        };
      }

      const orderId = subscriptionData.orderId || "";

      // 6. Kontrola duplicit - už byl tento orderId zpracován?
      const orderDocRef = db
        .collection(PROCESSED_ORDERS_COLLECTION)
        .doc(orderId);
      const orderDoc = await orderDocRef.get();

      if (orderDoc.exists) {
        const existingData = orderDoc.data();
        functions.logger.info("Order already processed", {
          orderId,
          existingUid: existingData?.uid,
        });

        // Idempotentní odpověď - pokud je to stejný user, vrátíme OK
        if (existingData?.uid === uid) {
          return {
            valid: true,
            orderId,
            expiryTimeMillis: subscriptionData.expiryTimeMillis || undefined,
            autoRenewing: subscriptionData.autoRenewing || false,
            alreadyProcessed: true,
          };
        } else {
          // Jiný user se snaží použít stejný token - podezřelé
          throw new functions.https.HttpsError(
            "already-exists",
            "Tento nákup byl již zpracován pro jiného uživatele."
          );
        }
      }

      // 7. Uložení do Firestore - subscription dokument
      const expiryDate = subscriptionData.expiryTimeMillis
        ? new Date(parseInt(subscriptionData.expiryTimeMillis))
        : null;

      const subscriptionDoc = {
        userId: uid,
        tier: "premium",
        productId,
        purchaseToken,
        orderId,
        platform: "android",
        autoRenewing: subscriptionData.autoRenewing || false,
        expiresAt: expiryDate
          ? admin.firestore.Timestamp.fromDate(expiryDate)
          : null,
        priceAmountMicros: subscriptionData.priceAmountMicros || null,
        priceCurrencyCode: subscriptionData.priceCurrencyCode || null,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Batch write - atomicky uložíme subscription i processed order
      const batch = db.batch();

      // Subscription dokument
      const subscriptionRef = db.collection(SUBSCRIPTIONS_COLLECTION).doc(uid);
      batch.set(subscriptionRef, subscriptionDoc, { merge: true });

      // Processed order (pro deduplikaci)
      batch.set(orderDocRef, {
        uid,
        productId,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: expiryDate
          ? admin.firestore.Timestamp.fromDate(expiryDate)
          : null,
      });

      await batch.commit();

      functions.logger.info("Subscription verified and saved", {
        uid,
        orderId,
        expiresAt: expiryDate?.toISOString(),
      });

      // 8. Úspěšná odpověď
      return {
        valid: true,
        orderId,
        expiryTimeMillis: subscriptionData.expiryTimeMillis || undefined,
        autoRenewing: subscriptionData.autoRenewing || false,
        priceAmountMicros: subscriptionData.priceAmountMicros || undefined,
        priceCurrencyCode: subscriptionData.priceCurrencyCode || undefined,
      };
    } catch (error: any) {
      functions.logger.error("Verification error", {
        errorMessage: error.message,
        errorCode: error.code,
        errorResponse: error.response?.data,
      });

      // Specifické Google API chyby
      if (error.code === 404 || error.message?.includes("404")) {
        return {
          valid: false,
          error: "Nákup nebyl nalezen v Google Play. Zkontrolujte productId a purchaseToken.",
        };
      }

      if (error.code === 401 || error.message?.includes("401") || error.message?.includes("invalid_grant")) {
        return {
          valid: false,
          error: "Chyba autentizace ke Google Play API. Zkontrolujte service account klíč.",
        };
      }

      if (error.code === 403 || error.message?.includes("403") || error.message?.includes("Access denied")) {
        return {
          valid: false,
          error: "Nedostatečná oprávnění. Přidejte service account do Play Console s oprávněním 'Spravovat objednávky'.",
        };
      }

      if (error.code === 410) {
        return {
          valid: false,
          error: "Nákup byl zrušen nebo expiroval.",
        };
      }

      // Chyba načtení credentials
      if (error.message?.includes("ENOENT") || error.message?.includes("keyFile")) {
        return {
          valid: false,
          error: "Chybí soubor play-billing-key.json ve functions složce.",
        };
      }

      // Obecná chyba
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        `Chyba při ověřování nákupu: ${error.message}`
      );
    }
  });

// ============================================================================
// BONUS: Scheduled function pro kontrolu expirovaných subscriptions
// ============================================================================
export const checkExpiredSubscriptions = functions
  .region("europe-west1")
  .pubsub.schedule("every 24 hours")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const expiredQuery = await db
      .collection(SUBSCRIPTIONS_COLLECTION)
      .where("tier", "==", "premium")
      .where("expiresAt", "<", now)
      .get();

    functions.logger.info(`Found ${expiredQuery.size} expired subscriptions`);

    const batch = db.batch();

    expiredQuery.docs.forEach((doc) => {
      batch.update(doc.ref, {
        tier: "free",
        expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    if (!expiredQuery.empty) {
      await batch.commit();
      functions.logger.info("Expired subscriptions downgraded to free");
    }

    return null;
  });
