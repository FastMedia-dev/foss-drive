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
  final String? thumbnailUrl;
  final String? mimeType;
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
    this.thumbnailUrl,
    this.mimeType,
    this.isOfflineAvailable = false,
  });

  factory DriveItem.fromJson(Map<String, dynamic> json) {
    return DriveItem(
      id: json["id"],
      name: json["name"],
      type: FileType.values.firstWhere((e) => e.toString() == json["type"]),
      parentId: json["parentId"],
      createdAt: DateTime.parse(json["createdAt"]),
      lastModified: json["lastModified"] != null ? DateTime.parse(json["lastModified"]) : null,
      size: json["size"],
      downloadUrl: json["downloadUrl"],
      thumbnailUrl: json["thumbnailUrl"],
      mimeType: json["mimeType"],
      isOfflineAvailable: json["isOfflineAvailable"] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "type": type.toString(),
      "parentId": parentId,
      "createdAt": createdAt.toIso8601String(),
      "lastModified": lastModified?.toIso8601String(),
      "size": size,
      "downloadUrl": downloadUrl,
      "thumbnailUrl": thumbnailUrl,
      "mimeType": mimeType,
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
    String? thumbnailUrl,
    String? mimeType,
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
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mimeType: mimeType ?? this.mimeType,
      isOfflineAvailable: isOfflineAvailable ?? this.isOfflineAvailable,
    );
  }
}
