/**
 * Afterimage Cloud Functions
 *
 * Server-side fan-out so secondary surfaces have a real backend:
 *   - onShotCreated     → denormalize album previews/count/cover/location + activity + push
 *   - onCommentCreated  → activity + push to the roll
 *   - onAlbumCreated    → "started a roll" activity to the creator's friends
 *   - onReactionChanged → notify the shot owner
 *   - onFriendRequest*  → notifications + maintain both users' friendIds
 *   - scheduledRevealCheck → countdown + reveal-ready notifications
 *
 * `users/{uid}/feed` powers the activity rail; `users/{uid}/notifications`
 * powers the notifications screen. Both are written ONLY here (admin SDK).
 */
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// MARK: - Helpers

interface ActorLite { uid: string; username: string; photoURL: string | null; }

async function actor(uid: string): Promise<ActorLite> {
  const snap = await db.collection("users").doc(uid).get();
  const d = snap.data() || {};
  return { uid, username: d.username ? `@${d.username}` : "@someone", photoURL: d.photoURL ?? null };
}

interface FeedEvent {
  kind: string;
  actorUid: string;
  actorUsername: string;
  actorPhotoURL: string | null;
  albumId?: string;
  albumName?: string | null;
  detail?: string | null;
}

/** Writes one feed doc into each recipient's `feed` subcollection. */
async function fanOutActivity(recipientUids: string[], event: FeedEvent): Promise<void> {
  if (recipientUids.length === 0) return;
  const batch = db.batch();
  for (const uid of recipientUids) {
    const ref = db.collection("users").doc(uid).collection("feed").doc();
    batch.set(ref, { ...event, happenedAt: FieldValue.serverTimestamp() });
  }
  await batch.commit();
}

interface NotifDoc {
  kind: string;
  title: string;
  subtitle: string;
  icon: string;
  albumId?: string | null;
}

async function notify(recipientUids: string[], notif: NotifDoc): Promise<void> {
  if (recipientUids.length === 0) return;
  const batch = db.batch();
  for (const uid of recipientUids) {
    const ref = db.collection("users").doc(uid).collection("notifications").doc();
    batch.set(ref, { ...notif, read: false, createdAt: FieldValue.serverTimestamp() });
  }
  await batch.commit();
}

/** Best-effort FCM push to a set of users (reads their fcmTokens). */
async function pushTo(recipientUids: string[], title: string, body: string,
                      data: Record<string, string> = {}): Promise<void> {
  if (recipientUids.length === 0) return;
  const tokens: string[] = [];
  const reads = await Promise.all(
    recipientUids.map((uid) => db.collection("users").doc(uid).get())
  );
  for (const snap of reads) {
    const t = (snap.data()?.fcmTokens as string[] | undefined) ?? [];
    tokens.push(...t);
  }
  if (tokens.length === 0) return;
  try {
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data,
    });
  } catch (e) {
    console.error("push failed", e);
  }
}

function snippet(text: string, max = 40): string {
  const t = (text || "").trim();
  return t.length > max ? `${t.slice(0, max)}…` : t;
}

// MARK: - Shots

export const onShotCreated = onDocumentCreated(
  "albums/{albumId}/shots/{shotId}",
  async (event) => {
    const shot = event.data?.data();
    if (!shot) return;
    const albumId = event.params.albumId;
    const albumRef = db.collection("albums").doc(albumId);

    // Denormalize album fields used by the feed/profile film-strip cards.
    await db.runTransaction(async (t) => {
      const albumSnap = await t.get(albumRef);
      const album = albumSnap.data();
      if (!album) return;
      const previews: string[] = (album.previewURLs ?? []).slice();
      if (previews.length < 6 && shot.photoURL) previews.push(shot.photoURL);
      const update: Record<string, unknown> = {
        shotCount: (album.shotCount ?? 0) + 1,
        previewURLs: previews,
      };
      if (!album.coverPhotoURL) update.coverPhotoURL = shot.photoURL;
      if (album.latitude == null && shot.latitude != null) {
        update.latitude = shot.latitude;
        update.longitude = shot.longitude;
        if (shot.locationName) update.locationName = shot.locationName;
      }
      t.update(albumRef, update);
    });

    const album = (await albumRef.get()).data();
    if (!album) return;
    const members: string[] = (album.memberIds ?? []).filter((u: string) => u !== shot.userId);
    const a = await actor(shot.userId);
    // The actor sees their OWN activity on the wire too — so include them in the
    // feed fan-out. They are still excluded from the push (no self-notifications).
    await fanOutActivity([shot.userId, ...members], {
      kind: "addedShot",
      actorUid: a.uid, actorUsername: a.username, actorPhotoURL: a.photoURL,
      albumId, albumName: album.name, detail: null,
    });
    await pushTo(members, `${a.username} added a shot`, album.name ?? "a roll",
                 { albumId, kind: "addedShot" });
  }
);

// MARK: - Comments

export const onCommentCreated = onDocumentCreated(
  "albums/{albumId}/comments/{commentId}",
  async (event) => {
    const comment = event.data?.data();
    if (!comment) return;
    const albumId = event.params.albumId;
    const album = (await db.collection("albums").doc(albumId).get()).data();
    if (!album) return;
    const members: string[] = (album.memberIds ?? []).filter((u: string) => u !== comment.userId);
    const a = await actor(comment.userId);
    // Include the commenter so they see their own comment on the wire.
    await fanOutActivity([comment.userId, ...members], {
      kind: "commented",
      actorUid: a.uid, actorUsername: a.username, actorPhotoURL: a.photoURL,
      albumId, albumName: album.name, detail: `“${snippet(comment.text)}”`,
    });
    await pushTo(members, `${a.username} commented on ${album.name}`,
                 snippet(comment.text), { albumId, kind: "commented" });
  }
);

// MARK: - Albums

export const onAlbumCreated = onDocumentCreated("albums/{albumId}", async (event) => {
  const album = event.data?.data();
  if (!album) return;
  const albumId = event.params.albumId;
  const a = await actor(album.creatorId);
  const creatorProfile = (await db.collection("users").doc(album.creatorId).get()).data();
  const friendIds: string[] = creatorProfile?.friendIds ?? [];
  // Include the creator so "started a roll" shows on their own wire too.
  await fanOutActivity([album.creatorId, ...friendIds], {
    kind: "startedRoll",
    actorUid: a.uid, actorUsername: a.username, actorPhotoURL: a.photoURL,
    albumId, albumName: album.name, detail: null,
  });
});

// MARK: - Reactions

export const onReactionChanged = onDocumentUpdated(
  "albums/{albumId}/shots/{shotId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    const beforeCount = countReactions(before.reactions);
    const afterCount = countReactions(after.reactions);
    if (afterCount <= beforeCount) return;        // only on a newly-added reaction
    const ownerUid = after.userId as string;
    await notify([ownerUid], {
      kind: "reaction",
      title: "someone reacted to your shot",
      subtitle: "tap to see the roll",
      icon: "heart.fill",
      albumId: event.params.albumId,
    });
    await pushTo([ownerUid], "new reaction", "someone reacted to your shot",
                 { albumId: event.params.albumId, kind: "reaction" });
  }
);

function countReactions(reactions: Record<string, string[]> | undefined): number {
  if (!reactions) return 0;
  return Object.values(reactions).reduce((sum, arr) => sum + (arr?.length ?? 0), 0);
}

// MARK: - Friend requests

export const onFriendRequestCreated = onDocumentCreated("friendRequests/{reqId}", async (event) => {
  const req = event.data?.data();
  if (!req || req.status !== "pending") return;
  const a = await actor(req.fromUid);
  await notify([req.toUid], {
    kind: "friendRequest",
    title: `${a.username} wants to connect`,
    subtitle: "tap to accept",
    icon: "person.crop.circle.badge.plus",
  });
  await pushTo([req.toUid], "new friend request", `${a.username} wants to connect`,
               { kind: "friendRequest" });
});

export const onFriendRequestUpdated = onDocumentUpdated("friendRequests/{reqId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (before.status === after.status || after.status !== "accepted") return;
  const { fromUid, toUid } = after;
  // Maintain both friend lists.
  await Promise.all([
    db.collection("users").doc(fromUid).update({ friendIds: FieldValue.arrayUnion(toUid) }),
    db.collection("users").doc(toUid).update({ friendIds: FieldValue.arrayUnion(fromUid) }),
  ]);
  const accepter = await actor(toUid);
  await notify([fromUid], {
    kind: "friendRequest",
    title: `${accepter.username} accepted your request`,
    subtitle: "you're connected",
    icon: "person.2.fill",
  });
  await pushTo([fromUid], "you're connected", `${accepter.username} accepted your request`,
               { kind: "friendAccepted" });
});

// MARK: - Scheduled reveal / countdown

export const scheduledRevealCheck = onSchedule("every 30 minutes", async () => {
  const now = admin.firestore.Timestamp.now();
  const soon = admin.firestore.Timestamp.fromMillis(now.toMillis() + 2 * 60 * 60 * 1000);

  // Reveal-ready: revealAt has passed and we haven't told the members yet.
  const readySnap = await db.collection("albums").where("revealAt", "<=", now).get();
  for (const doc of readySnap.docs) {
    const album = doc.data();
    if (album.revealNotified) continue;
    const members: string[] = album.memberIds ?? [];
    await notify(members, {
      kind: "revealReady",
      title: `${album.name} is ready!`,
      subtitle: `${album.shotCount ?? 0} shots developed.`,
      icon: "film.fill",
      albumId: doc.id,
    });
    await pushTo(members, `${album.name} is ready`, "your roll has developed",
                 { albumId: doc.id, kind: "revealReady" });
    await doc.ref.update({ revealNotified: true });
  }

  // Countdown: reveals within the next ~2h and not yet warned.
  const soonSnap = await db.collection("albums")
    .where("revealAt", ">", now)
    .where("revealAt", "<=", soon)
    .get();
  for (const doc of soonSnap.docs) {
    const album = doc.data();
    if (album.countdownNotified) continue;
    const members: string[] = album.memberIds ?? [];
    await notify(members, {
      kind: "countdown",
      title: `${album.name} develops soon`,
      subtitle: "last chance to add shots.",
      icon: "clock.fill",
      albumId: doc.id,
    });
    await pushTo(members, `${album.name} develops soon`, "last chance to add shots",
                 { albumId: doc.id, kind: "countdown" });
    await doc.ref.update({ countdownNotified: true });
  }
});
