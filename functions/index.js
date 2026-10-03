/**
 * Funciones de la nube de Viernes: avisan al instante (mensajes push) cuando
 *  - alguien te envía un recordatorio,
 *  - completan un recordatorio que enviaste,
 *  - te asignan algo en una lista compartida,
 *  - te agregan a una lista.
 *
 * Los mensajes son «de datos»: la app decide qué mostrar y, si alguien te
 * envía un recordatorio, lo agrega a tu agenda aunque la app esté cerrada.
 *
 * Cada teléfono deja su dirección en `push_tokens/{token}` con su correo
 * (ver lib/features/push/push_service.dart).
 *
 * Requiere el plan Blaze de Firebase. Ver docs/PUSH.md.
 */
const {setGlobalOptions} = require("firebase-functions/v2");
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

// La base de datos está en us-east1: las funciones van en la misma región.
setGlobalOptions({region: "us-east1", maxInstances: 5});

const db = getFirestore();

/** Direcciones push de una persona, por correo o por uid. */
async function tokensWhere(field, value) {
  if (!value) return [];
  const snapshot = await db
      .collection("push_tokens")
      .where(field, "==", value)
      .get();
  return snapshot.docs.map((doc) => doc.id);
}

/**
 * Envía [data] a cada dirección. Las direcciones que ya no existen (la app
 * se desinstaló) se borran.
 */
async function send(tokens, data) {
  if (tokens.length === 0) return;
  const clean = {};
  for (const [key, value] of Object.entries(data)) {
    if (value !== undefined && value !== null) clean[key] = String(value);
  }
  const response = await getMessaging().sendEachForMulticast({
    tokens,
    data: clean,
    android: {priority: "high", ttl: 24 * 60 * 60 * 1000},
  });
  const stale = [];
  response.responses.forEach((result, i) => {
    const code = result.error && result.error.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      stale.push(tokens[i]);
    }
  });
  await Promise.all(
      stale.map((token) => db.collection("push_tokens").doc(token).delete()),
  );
  logger.info(`Enviado ${data.type} a ${tokens.length} (${stale.length} viejos)`);
}

/** Alguien te envió un recordatorio. */
exports.onSharedReminderCreated = onDocumentCreated(
    "shared_reminders/{id}",
    async (event) => {
      const data = event.data && event.data.data();
      if (!data || data.status !== "sent") return;
      await send(await tokensWhere("email", data.toEmail), {
        type: "shared_reminder",
        id: event.params.id,
        title: data.title,
        fromName: data.fromName,
      });
    },
);

/** Completaron lo que enviaste. */
exports.onSharedReminderUpdated = onDocumentUpdated(
    "shared_reminders/{id}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      if (before.status === "done" || after.status !== "done") return;
      await send(await tokensWhere("uid", after.fromUid), {
        type: "shared_done",
        id: event.params.id,
        title: after.title,
        toEmail: after.toEmail,
      });
    },
);

/** Te asignaron algo en una lista (o se lo cambiaron a ti). */
exports.onListItemWritten = onDocumentWritten(
    "lists/{listId}/items/{itemId}",
    async (event) => {
      const after = event.data.after.exists ? event.data.after.data() : null;
      if (!after || !after.assignedTo || after.done) return;
      const before = event.data.before.exists ?
        event.data.before.data() :
        null;
      if (before && before.assignedTo === after.assignedTo) return;
      const list = await db.collection("lists").doc(event.params.listId).get();
      const listName = list.exists ? list.data().name : "";
      // Quién lo agregó a la lista (nombre), para el texto del aviso.
      const assigner = after.addedBy || "";
      await send(await tokensWhere("email", after.assignedTo), {
        type: "list_assigned",
        listId: event.params.listId,
        listName,
        itemId: event.params.itemId,
        text: after.text,
        by: assigner,
      });
    },
);

/** Te agregaron a una lista. */
exports.onListUpdated = onDocumentUpdated("lists/{listId}", async (event) => {
  const before = event.data.before.data().memberEmails || [];
  const after = event.data.after.data();
  const added = (after.memberEmails || []).filter((e) => !before.includes(e));
  for (const email of added) {
    await send(await tokensWhere("email", email), {
      type: "list_invite",
      listId: event.params.listId,
      listName: after.name,
    });
  }
});

/** Al crear una lista con otras personas, también se les avisa. */
exports.onListCreated = onDocumentCreated("lists/{listId}", async (event) => {
  const data = event.data && event.data.data();
  if (!data) return;
  const owner = await db
      .collection("push_tokens")
      .where("uid", "==", data.ownerUid)
      .limit(1)
      .get();
  const ownerEmail = owner.empty ? null : owner.docs[0].data().email;
  for (const email of data.memberEmails || []) {
    if (email === ownerEmail) continue;
    await send(await tokensWhere("email", email), {
      type: "list_invite",
      listId: event.params.listId,
      listName: data.name,
    });
  }
});
