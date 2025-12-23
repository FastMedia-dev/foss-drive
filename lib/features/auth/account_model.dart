class Account {
  final String id;
  final String email;
  final String name;

  Account({
    required this.id,
    required this.email,
    required this.name,
  });

  // For simplicity, we'll use a basic fromJson and toJson
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json["id"],
      email: json["email"],
      name: json["name"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "email": email,
      "name": name,
    };
  }
}
