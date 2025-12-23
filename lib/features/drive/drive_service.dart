import 'dart:io';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:myapp/features/drive/file_model.dart';

class DriveService {
  static const _storage = FlutterSecureStorage();
  static const _driveItemsKey = 'driveItems';
  static const _offlineStoragePath = '/foss-drive'; // Relative path

  // Dummy initial data
  final List<DriveItem> _initialDriveItems = [
    DriveItem(id: 'f1', name: 'Documents', type: FileType.folder, createdAt: DateTime.now()),
    DriveItem(id: 'f2', name: 'Photos', type: FileType.folder, createdAt: DateTime.now()),
    DriveItem(id: 'file1', name: 'MyDocument.pdf', type: FileType.document, parentId: 'f1', createdAt: DateTime.now(), size: 1024 * 500, downloadUrl: 'http://example.com/mydocument.pdf'),
    DriveItem(id: 'file2', name: 'Vacation.jpg', type: FileType.image, parentId: 'f2', createdAt: DateTime.now(), size: 1024 * 1024 * 2, downloadUrl: 'http://example.com/vacation.jpg'),
  ];

  Future<List<DriveItem>> getDriveItems({String? parentId}) async {
    final String? itemsJson = await _storage.read(key: _driveItemsKey);
    List<DriveItem> allItems;
    if (itemsJson != null) {
      final List<dynamic> jsonList = json.decode(itemsJson);
      allItems = jsonList.map((json) => DriveItem.fromJson(json)).toList();
    } else {
      // If no items are stored, save initial dummy items for initial use
      await _saveDriveItems(_initialDriveItems);
      allItems = _initialDriveItems;
    }
    return allItems.where((item) => item.parentId == parentId).toList();
  }

  Future<void> _saveDriveItems(List<DriveItem> items) async {
    final String itemsJson = json.encode(items.map((item) => item.toJson()).toList());
    await _storage.write(key: _driveItemsKey, value: itemsJson);
  }

  Future<void> uploadFile(String fileName, List<int> fileBytes, {String? parentId}) async {
    List<DriveItem> allItems = await getDriveItems(); // Get all items, not just top-level
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

  Future<String> _getDownloadPath() async {
    // This will get the external storage directory on Android or Documents directory on iOS
    final Directory? externalStorageDir = await getExternalStorageDirectory();
    if (externalStorageDir == null) {
      throw Exception('Could not get external storage directory.');
    }
    final String downloadPath = '${externalStorageDir.path}/foss-drive';
    final Directory appDir = Directory(downloadPath);
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return downloadPath;
  }

  Future<void> downloadFile(DriveItem file) async {
    if (file.downloadUrl == null) {
      throw Exception('File does not have a download URL.');
    }
    // Simulate file download
    print('Downloading ${file.name} from ${file.downloadUrl}');
    // In a real app, you would use http or dio to download the file
    // For now, we\'ll just simulate writing a dummy file.
    final String downloadPath = await _getDownloadPath();
    final File localFile = File('$downloadPath/${file.name}');
    await localFile.writeAsString('Dummy content for ${file.name}');
    print('File saved to: ${localFile.path}');

    // Update offline status
    List<DriveItem> allItems = await getDriveItems();
    int index = allItems.indexWhere((item) => item.id == file.id);
    if (index != -1) {
      allItems[index] = allItems[index].copyWith(isOfflineAvailable: true);
      await _saveDriveItems(allItems);
    }
  }

  Future<void> createFolder(String folderName, {String? parentId}) async {
    List<DriveItem> allItems = await getDriveItems();
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
    List<DriveItem> allItems = await getDriveItems();
    return allItems.where((item) => item.isOfflineAvailable).toList();
  }

  Future<void> toggleOfflineAvailability(DriveItem item) async {
    List<DriveItem> allItems = await getDriveItems();
    int index = allItems.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      allItems[index] = allItems[index].copyWith(isOfflineAvailable: !item.isOfflineAvailable);
      await _saveDriveItems(allItems);
    }
  }
}
