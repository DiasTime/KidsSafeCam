import 'package:equatable/equatable.dart';

/// An authenticated user of the system (a parent/owner).
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, email, displayName];
}
