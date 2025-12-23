enum FileType {
  folder,
  document,
  image,
  video,
  audio,
  other,
}

class DriveItem {
  final String id;
  final String name;
  final FileType type;
  final String? parentId;
  final DateTime createdAt;
  final DateTime? lastModified;
  final int? size; // in bytes
  final String? downloadUrl; // For dummy download
  bool isOfflineAvailable; // To mark for offline access

  DriveItem({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    required this.createdAt,
    this.lastModified,
    this.size,
    this.downloadUrl,
    this.isOfflineAvailable = false,
  });

  // For simplicity, we\'ll use a basic fromJson and toJson
  factory DriveItem.fromJson(Map<String, dynamic> json) {
    return DriveItem(
      id: json["id"],
      name: json["name"],
      type: FileType.values.firstWhere((e) => e.toString() == json["type"]), // Convert string back to enum
      parentId: json["parentId"],
      createdAt: DateTime.parse(json["createdAt"]),
      lastModified: json["lastModified"] != null ? DateTime.parse(json["lastModified"]) : null,
      size: json["size"],
      downloadUrl: json["downloadUrl"],
      isOfflineAvailable: json["isOfflineAvailable"] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "type": type.toString(), // Convert enum to string
      "parentId": parentId,
      "createdAt": createdAt.toIso8601String(),
      "lastModified": lastModified?.toIso8601String(),
      "size": size,
      "downloadUrl": downloadUrl,
      "isOfflineAvailable": isOfflineAvailable,
    };
  }

  DriveItem copyWith({
    String? id,
    String? name,
    FileType? type,
    String? parentId,
    DateTime? createdAt,
    DateTime? lastModified,
    int? size,
    String? downloadUrl,
    bool? isOfflineAvailable,
  }) {
    return DriveItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      size: size ?? this.size,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      isOfflineAvailable: isOfflineAvailable ?? this.isOfflineAvailable,
    );
  }
}
