import 'package:equatable/equatable.dart';

/// Domain Entity for User
class AppUser extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final double totalOwed;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.totalOwed = 0.0,
  });

  @override
  List<Object?> get props => [id, name, email, photoUrl, totalOwed];
}
