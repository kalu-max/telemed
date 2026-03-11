class UserProfile {
  final String name;
  final String email;
  final String phone;
  final String dateOfBirth;
  final String gender;
  final String bloodType;
  final String address;
  final String? profileImageUrl;

  UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodType,
    required this.address,
    this.profileImageUrl,
  });
}
