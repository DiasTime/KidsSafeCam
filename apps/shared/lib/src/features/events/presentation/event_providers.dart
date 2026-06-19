import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/baby_event.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/repositories/firestore_event_repository.dart';
import '../domain/repositories/event_repository.dart';

/// The app's [EventRepository]. Override in tests with a fake.
final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => FirestoreEventRepository(),
);

/// Streams the signed-in user's events, newest first. Empty when signed out.
final eventsProvider = StreamProvider<List<BabyEvent>>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) return Stream.value(const <BabyEvent>[]);
  return ref.watch(eventRepositoryProvider).watchEvents(user.id);
});
