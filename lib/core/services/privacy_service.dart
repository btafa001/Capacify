import 'dart:convert';
import 'dart:js_interop';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

/// GDPR data-subject rights (Art. 15 access / Art. 20 portability / Art. 17
/// erasure), implemented client-side against Firestore + Auth. No backend
/// required: every read/write here is one the signed-in user is already
/// permitted to do under firestore.rules.
class PrivacyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Gathers everything we hold about the user into a single JSON map (Art. 15):
  /// account, company profile, their posts, the contact requests they SENT and
  /// the ones they RECEIVED as a poster, their reviews, favourites, saved
  /// searches, notification inbox, and every chat thread they're a party to
  /// with its full message history. Read-only — every query here is one the
  /// signed-in user is already permitted to run under firestore.rules.
  Future<Map<String, dynamic>> collectMyData(String uid) async {
    final out = <String, dynamic>{
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'userId': uid,
    };

    final user = await _db.collection('users').doc(uid).get();
    out['account'] = user.data() == null ? null : _cleanMap(user.data()!);

    // Company doc id == owner uid by convention.
    final company = await _db.collection('companies').doc(uid).get();
    out['company'] = company.data() == null ? null : _cleanMap(company.data()!);

    final owners = await _db
        .collection('capacityOwners')
        .where('posterCompanyId', isEqualTo: uid)
        .get();
    out['myPosts'] =
        owners.docs.map((d) => {'id': d.id, ..._cleanMap(d.data())}).toList();

    final requests = await _db
        .collection('contact_requests')
        .where('requesterCompanyId', isEqualTo: uid)
        .get();
    out['mySentRequests'] =
        requests.docs.map((d) => {'id': d.id, ..._cleanMap(d.data())}).toList();

    // Requests the user RECEIVED as a poster — matched by their own post ids
    // (the same postId-whereIn query received_requests_screen.dart uses; the
    // read rule grants the poster access per doc via the capacityOwners
    // sidecar). Without this, half of the user's contact history was invisible
    // to their own export.
    out['myReceivedRequests'] =
        await _collectReceivedRequests(owners.docs.map((d) => d.id).toList());

    final ratings = await _db
        .collection('companyRatings')
        .where('raterUserId', isEqualTo: uid)
        .get();
    out['myReviews'] =
        ratings.docs.map((d) => {'id': d.id, ..._cleanMap(d.data())}).toList();

    final favs = await _db
        .collection('userFavorites')
        .where('userId', isEqualTo: uid)
        .get();
    out['myFavorites'] =
        favs.docs.map((d) => {'id': d.id, ..._cleanMap(d.data())}).toList();

    final savedSearches = await _db
        .collection('savedSearches')
        .where('ownerId', isEqualTo: uid)
        .get();
    out['mySavedSearches'] = savedSearches.docs
        .map((d) => {'id': d.id, ..._cleanMap(d.data())})
        .toList();

    final notifications = await _db
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .get();
    out['myNotifications'] = notifications.docs
        .map((d) => {'id': d.id, ..._cleanMap(d.data())})
        .toList();

    // Chat threads the user is a party to, each with its ordered messages.
    out['myChats'] = await _collectChats(uid);

    return out;
  }

  /// Triggers a browser download of the export as a pretty-printed JSON file.
  Future<void> downloadMyData(String uid) async {
    final data = await collectMyData(uid);
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final blob = web.Blob(
      [json.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = 'capacify-daten-$uid.json';
    anchor.click();
    web.URL.revokeObjectURL(url);
  }

  /// Contact requests the user received on their own posts, matched by post id.
  /// Chunked to Firestore's 10-value `whereIn` limit, mirroring the live
  /// received-requests query so the same per-doc read rule applies.
  Future<List<Map<String, dynamic>>> _collectReceivedRequests(
    List<String> myPostIds,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < myPostIds.length; i += 10) {
      final end = (i + 10) < myPostIds.length ? i + 10 : myPostIds.length;
      final chunk = myPostIds.sublist(i, end);
      final snap = await _db
          .collection('contact_requests')
          .where('postId', whereIn: chunk)
          .get();
      out.addAll(snap.docs.map((d) => {'id': d.id, ..._cleanMap(d.data())}));
    }
    return out;
  }

  /// Every chat the user participates in, each with its ordered message history.
  Future<List<Map<String, dynamic>>> _collectChats(String uid) async {
    final chats = await _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();
    final out = <Map<String, dynamic>>[];
    for (final c in chats.docs) {
      final msgs =
          await c.reference.collection('messages').orderBy('createdAt').get();
      out.add({
        'id': c.id,
        ..._cleanMap(c.data()),
        'messages':
            msgs.docs.map((m) => {'id': m.id, ..._cleanMap(m.data())}).toList(),
      });
    }
    return out;
  }

  /// Recursively converts Firestore [Timestamp]s (at ANY depth) to ISO-8601
  /// strings so the assembled export is always JSON-encodable. The shallow
  /// version this replaced missed timestamps nested inside maps — chat docs
  /// carry them under `reads`/`typing`/`notifiedEmailAt`, which would have
  /// thrown inside the JsonEncoder the moment chats joined the export.
  static Map<String, dynamic> _cleanMap(Map<String, dynamic> m) =>
      m.map((k, v) => MapEntry(k, _cleanValue(v)));

  static dynamic _cleanValue(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _cleanValue(val)));
    }
    if (v is List) return v.map(_cleanValue).toList();
    return v;
  }

  /// Erases the user's personal data (Art. 17). Posts/companies are soft-delete
  /// only (firestore.rules block hard deletes to preserve marketplace history),
  /// so instead their *personal* fields are anonymised: the company name/contact
  /// are wiped and marked deleted, posts are cancelled, and the locked identity
  /// sidecars have their contact details cleared so no reveal can surface them.
  /// Reviews, favourites, saved searches and the user's own blocks (all freely
  /// deletable by the owner under the rules) are removed outright client-side.
  /// Everything the client's own rules forbid it to touch — chat threads,
  /// notifications, the credits wallet, and the requester name denormalised onto
  /// sent contact_requests — is erased server-side by the purgeUserData Cloud
  /// Function (step 4). The account doc is deleted, then the Auth user itself.
  ///
  /// Auth deletion needs a recent login; if it throws requires-recent-login the
  /// caller should ask the user to re-authenticate and retry.
  Future<void> deleteMyAccount(String uid) async {
    // 1) Anonymise company + cancel/clear each post and its identity sidecar.
    final owners = await _db
        .collection('capacityOwners')
        .where('posterCompanyId', isEqualTo: uid)
        .get();
    for (final o in owners.docs) {
      final batch = _db.batch();
      batch.update(o.reference, {
        'companyName': 'Gelöschtes Unternehmen',
        'contactPhone': '',
        'contactEmail': '',
      });
      batch.update(_db.collection('capacities').doc(o.id), {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    }

    // 2) Anonymise the company profile (soft — can't hard-delete by rules).
    // The contact fields cleared here are the legacy inline copies on the
    // public doc; the live ones now live in the gated companyContacts sidecar
    // and are cleared separately below. Both are scrubbed, or a deleted
    // account would leave its real email/phone/address behind in whichever
    // location this pass missed.
    final companyRef = _db.collection('companies').doc(uid);
    if ((await companyRef.get()).exists) {
      await companyRef.update({
        'name': 'Gelöschtes Unternehmen',
        'phone': FieldValue.delete(),
        'email': FieldValue.delete(),
        'address': FieldValue.delete(),
        'postalCode': FieldValue.delete(),
        'profileComplete': false,
        'website': '',
        'description': '',
        'vatNumber': '',
        'trades': <String>[],
        'deleted': true,
      });
    }

    // 2b) Clear the gated contact sidecar — the authoritative home for
    // email/phone/address since the contact split. Emptied rather than
    // deleted, matching the soft-delete posture of the profile above (the
    // rules permit the owner to write their own block, not remove it).
    final contactRef = _db.collection('companyContacts').doc(uid);
    if ((await contactRef.get()).exists) {
      await contactRef.set({
        'email': '',
        'phone': '',
        'address': '',
        'postalCode': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 3) Delete freely-removable personal records.
    final ratings = await _db
        .collection('companyRatings')
        .where('raterUserId', isEqualTo: uid)
        .get();
    for (final r in ratings.docs) {
      await r.reference.delete();
    }
    final favs = await _db
        .collection('userFavorites')
        .where('userId', isEqualTo: uid)
        .get();
    for (final f in favs.docs) {
      await f.reference.delete();
    }
    final savedSearches = await _db
        .collection('savedSearches')
        .where('ownerId', isEqualTo: uid)
        .get();
    for (final s in savedSearches.docs) {
      await s.reference.delete();
    }
    // Only blocks the user CREATED — the rules let the blocker delete their own
    // block, not blocks other companies placed against them (those belong to the
    // other party and carry no name of ours, only our id).
    final blocks = await _db
        .collection('userBlocks')
        .where('blockerCompanyId', isEqualTo: uid)
        .get();
    for (final b in blocks.docs) {
      await b.reference.delete();
    }

    // 4) Server-side erasure of everything the client's own rules forbid it to
    // touch: chat threads + messages (client-immutable), notifications
    // (delete:false) both the user's own inbox and the ones about them carrying
    // their company name, the credits wallet (delete:false), and the
    // requesterCompanyName denormalised onto the contact_requests they sent
    // (which the requester can't rewrite). Runs via purgeUserData (Admin SDK,
    // bypasses rules) while still authenticated. Best-effort — a transient
    // failure must never block account deletion (worst case is a re-runnable
    // purge, strictly better than a half-deleted account).
    //
    // NOTE — explicit product decision: purgeUserData recursiveDelete()s the
    // user's chat threads, which HARD-deletes the counterparty's only copy of
    // that business correspondence (chats/messages are client-immutable and live
    // nowhere else). Chosen deliberately as "erase on request" over the
    // alternative of anonymise-and-retain-for-the-other-party; revisit if a
    // counterparty ever needs to keep the thread for their own records.
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west3')
          .httpsCallable('purgeUserData')
          .call();
    } catch (_) {}

    // 5) Delete the account doc, then the Auth user.
    await _db.collection('users').doc(uid).delete();
    await _auth.currentUser?.delete();
  }
}

final privacyServiceProvider = Provider<PrivacyService>((ref) => PrivacyService());
