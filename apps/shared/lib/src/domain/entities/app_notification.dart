import 'package:equatable/equatable.dart';

/// An in-app notification record backing the parent app's notification history.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.eventId,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String? eventId;

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    body,
    read,
    createdAt,
    eventId,
  ];
}
