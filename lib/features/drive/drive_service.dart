import 'dart:io';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:myapp/features/drive/file_model.dart';
import 'package:permission_handler/permission_handler.dart';

class DriveService {
  static const _storage = FlutterSecureStorage();
  static const _driveItemsKey = 'driveItems';

  // Dummy initial data
  final List<DriveItem> _initialDriveItems = [
    DriveItem(id: 'f1', name: 'Documents', type: FileType.folder, createdAt: DateTime.now()),
    DriveItem(id: 'f2', name: 'Photos', type: FileType.folder, createdAt: DateTime.now()),
    DriveItem(id: 'file1', name: 'MyDocument.pdf', type: FileType.document, parentId: 'f1', createdAt: DateTime.now(), size: 1024 * 500, downloadUrl: 'http://example.com/mydocument.pdf'),
    DriveItem(id: 'file2', name: 'Vacation.jpg', type: FileType.image, parentId: 'f2', createdAt: DateTime.now(), size: 1024 * 1024 * 2, downloadUrl: 'http://example.com/vacation.jpg'),
  ];

  /// Get all items or items for a specific folder
  Future<List<DriveItem>> getDriveItems({String? parentId}) async {
    final String? itemsJson = await _storage.read(key: _driveItemsKey);
    List<DriveItem> allItems;
    if (itemsJson != null) {
      try {
        final List<dynamic> jsonList = json.decode(itemsJson);
        allItems = jsonList.map((json) => DriveItem.fromJson(json)).toList();
      } catch (e) {
         print("Error decoding drive items: $e");
         allItems = _initialDriveItems;
      }
    } else {
      // If no items are stored, save initial dummy items for initial use
      await _saveDriveItems(_initialDriveItems);
      allItems = _initialDriveItems;
    }

    // Return items that match the parentId
    return allItems.where((item) => item.parentId == parentId).toList();
  }

  // Helper to get ALL items (internal)
  Future<List<DriveItem>> _getAllItems() async {
    final String? itemsJson = await _storage.read(key: _driveItemsKey);
    if (itemsJson != null) {
      try {
        final List<dynamic> jsonList = json.decode(itemsJson);
        return jsonList.map((json) => DriveItem.fromJson(json)).toList();
      } catch (e) {
        return _initialDriveItems;
      }
    }
    return _initialDriveItems;
  }

  Future<void> _saveDriveItems(List<DriveItem> items) async {
    final String itemsJson = json.encode(items.map((item) => item.toJson()).toList());
    await _storage.write(key: _driveItemsKey, value: itemsJson);
  }

  Future<void> uploadFile(String fileName, List<int> fileBytes, {String? parentId}) async {
    List<DriveItem> allItems = await _getAllItems();
    final newFile = DriveItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: fileName,
      type: FileType.document, // Simplified for now
      parentId: parentId,
      createdAt: DateTime.now(),
      size: fileBytes.length,
      downloadUrl: 'http://example.com/' + fileName.replaceAll(' ', '_').toLowerCase(), // Dummy URL
    );
    allItems.add(newFile);
    await _saveDriveItems(allItems);
  }

  /// Gets the download path: /storage/emulated/0/foss-drive/
  Future<String> _getDownloadPath() async {
    // Check permissions first
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isGranted) {
        // Android 11+ All files access
      } else if (await Permission.storage.request().isGranted) {
         // Legacy storage
      } else {
        // Try anyway, or handle denied
        print("Storage permission might be denied.");
      }
    }

    // Target path: /storage/emulated/0/foss-drive/
    // We can try to construct this manually or use getExternalStorageDirectory()
    // getExternalStorageDirectory() usually gives /storage/emulated/0/Android/data/com.package/files/
    // To get the root /storage/emulated/0/foss-drive, we need to be careful.

    // Attempting to write to /storage/emulated/0/foss-drive requires MANAGE_EXTERNAL_STORAGE on Android 11+
    // OR using the MediaStore API (which is harder in raw Dart).
    // For this prototype, we will try to use the public Documents folder or similar if possible,
    // or the specific path requested if permission is granted.

    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/foss-drive');
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory.path;
  }

  /// Gets the secure offline storage path (internal app data)
  Future<String> _getOfflineStoragePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${directory.path}/offline_files');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    return offlineDir.path;
  }

  Future<void> downloadFile(DriveItem file) async {
    if (file.downloadUrl == null) {
      // If it's a file uploaded via our "Upload" dummy, it has no real URL.
      // In a real app, we'd have a backend.
      // Here, we will just create a dummy file at the destination.
    }

    print('Downloading ${file.name}...');

    try {
        final String downloadPath = await _getDownloadPath();
        final File localFile = File('$downloadPath/${file.name}');

        // Write dummy content
        await localFile.writeAsString('This is the content of ${file.name}.\nDownloaded from Foss Drive.');
        print('File saved to: ${localFile.path}');
    } catch (e) {
        print("Error saving to external storage: $e");
        // Fallback or notify user
    }
  }

  Future<void> createFolder(String folderName, {String? parentId}) async {
    List<DriveItem> allItems = await _getAllItems();
    final newFolder = DriveItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: folderName,
      type: FileType.folder,
      parentId: parentId,
      createdAt: DateTime.now(),
    );
    allItems.add(newFolder);
    await _saveDriveItems(allItems);
  }

  Future<List<DriveItem>> getOfflineFiles() async {
    List<DriveItem> allItems = await _getAllItems();
    return allItems.where((item) => item.isOfflineAvailable).toList();
  }

  Future<void> toggleOfflineAvailability(DriveItem item) async {
    List<DriveItem> allItems = await _getAllItems();
    int index = allItems.indexWhere((i) => i.id == item.id);

    if (index != -1) {
      bool newStatus = !item.isOfflineAvailable;
      allItems[index] = allItems[index].copyWith(isOfflineAvailable: newStatus);
      await _saveDriveItems(allItems);

      // Handle actual file caching
      try {
        final offlinePath = await _getOfflineStoragePath();
        final File offlineFile = File('$offlinePath/${item.id}_${item.name}');

        if (newStatus) {
            // Save to offline storage
             await offlineFile.writeAsString('Offline content for ${item.name}');
        } else {
            // Remove from offline storage
            if (await offlineFile.exists()) {
                await offlineFile.delete();
            }
        }
      } catch (e) {
          print("Error handling offline file storage: $e");
      }
    }
  }
}
