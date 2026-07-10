import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'contact_request_service.dart';
import 'capacity_provider.dart';
import '../models/contact_request_model.dart';

final contactRequestServiceProvider =
    Provider<ContactRequestService>((ref) => ContactRequestService());

/// The signed-in requester's own sent requests (for "Meine Anfragen").
final myContactRequestsProvider =
    StreamProvider.family<List<ContactRequestModel>, String>((ref, requesterCompanyId) {
  return ref.watch(contactRequestServiceProvider).myRequests(requesterCompanyId);
});

typedef PostRequestKey = ({String requesterCompanyId, String postId});

/// My request for one specific post — drives the card/detail action state.
final myRequestForPostProvider =
    StreamProvider.family<ContactRequestModel?, PostRequestKey>((ref, key) {
  return ref.watch(contactRequestServiceProvider).myRequestForPost(
        requesterCompanyId: key.requesterCompanyId,
        postId: key.postId,
      );
});

/// One request by its doc id (chatId == requestId) — drives the chat's
/// collaboration-confirm banner. Both parties may read it.
final contactRequestByIdProvider =
    StreamProvider.family<ContactRequestModel?, String>((ref, requestId) {
  return ref.watch(contactRequestServiceProvider).requestById(requestId);
});

/// Requests directed at the poster's own posts ("Erhaltene Anfragen").
/// Composed from the poster's own posts → their postIds → received requests.
final receivedRequestsProvider =
    StreamProvider.family<List<ContactRequestModel>, String>((ref, companyId) {
  final posts = ref.watch(myCapacitiesProvider(companyId)).valueOrNull ?? [];
  final postIds = posts.map((p) => p.id).toList();
  return ref.watch(contactRequestServiceProvider).receivedRequests(postIds);
});

/// Founder/admin queue of all contact requests.
final allContactRequestsProvider =
    StreamProvider<List<ContactRequestModel>>((ref) {
  return ref.watch(contactRequestServiceProvider).allRequests();
});
