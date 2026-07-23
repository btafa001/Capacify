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

  /// Gathers everything we hold about the user into a single JSON map:
  /// account, company profile, their posts, their sent contact requests,
  /// their reviews and their favourites. Read-only.
  Future<Map<String, dynamic>> collectMyData(String uid) async {
    final out = <String, dynamic>{
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'userId': uid,
    };

    Map<String, dynamic> clean(Map<String, dynamic> m) => m.map((k, v) =>
        MapEntry(k, v is Timestamp ? v.toDate().toIso8601String() : v));

    final user = await _db.collection('users').doc(uid).get();
    out['account'] = user.data() == null ? null : clean(user.data()!);

    // Company doc id == owner uid by convention.
    final company = await _db.collection('companies').doc(uid).get();
    out['company'] = company.data() == null ? null : clean(company.data()!);

    final owners = await _db
        .collection('capacityOwners')
        .where('posterCompanyId', isEqualTo: uid)
        .get();
    out['myPosts'] = owners.docs.map((d) => {'id': d.id, ...clean(d.data())}).toList();

    final requests = await _db
        .collection('contact_requests')
        .where('requesterCompanyId', isEqualTo: uid)
        .get();
    out['mySentRequests'] =
        requests.docs.map((d) => {'id': d.id, ...clean(d.data())}).toList();

    final ratings = await _db
        .collection('companyRatings')
        .where('raterUserId', isEqualTo: uid)
        .get();
    out['myReviews'] = ratings.docs.map((d) => {'id': d.id, ...clean(d.data())}).toList();

    final favs = await _db
        .collection('userFavorites')
        .where('userId', isEqualTo: uid)
        .get();
    out['myFavorites'] = favs.docs.map((d) => {'id': d.id, ...clean(d.data())}).toList();

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

  /// Erases the user's personal data (Art. 17). Posts/companies are soft-delete
  /// only (firestore.rules block hard deletes to preserve marketplace history),
  /// so instead their *personal* fields are anonymised: the company name/contact
  /// are wiped and marked deleted, posts are cancelled, and the locked identity
  /// sidecars have their contact details cleared so no reveal can surface them.
  /// Reviews and favourites (freely deletable) are removed outright, the account
  /// doc is deleted, and finally the Auth user itself is deleted.
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

    // 4) Recursively erase chat threads + messages (immutable to clients by
    // rules, so this runs server-side via the purgeUserData Cloud Function
    // while still authenticated). Best-effort — never block account deletion.
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
