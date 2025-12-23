class Account {
  final String id;
  final String email;
  final String name;
  final String? photoUrl; // Added for profile picture
  final String credentialJson; // The raw service account JSON

  Account({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    required this.credentialJson,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json["id"],
      email: json["email"],
      name: json["name"],
      photoUrl: json["photoUrl"],
      credentialJson: json["credentialJson"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "email": email,
      "name": name,
      "photoUrl": photoUrl,
      "credentialJson": credentialJson,
    };
  }
}
