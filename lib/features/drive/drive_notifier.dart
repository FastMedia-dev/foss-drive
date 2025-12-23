import 'package:flutter/material.dart';
import 'package:myapp/features/drive/drive_service.dart';
import 'package:myapp/features/drive/file_model.dart';

class DriveNotifier with ChangeNotifier {
  final DriveService _driveService = DriveService();
  List<DriveItem> _currentFolderItems = [];
  List<DriveItem> get currentFolderItems => _currentFolderItems;

  String? _currentParentId; // Null for root folder
  List<String> _pathHistory = []; // To navigate back

  DriveNotifier() {
    _loadDriveItems();
  }

  Future<void> _loadDriveItems({String? parentId}) async {
    _currentParentId = parentId;
    _currentFolderItems = await _driveService.getDriveItems(parentId: parentId);
    notifyListeners();
  }

  Future<void> openFolder(DriveItem folder) async {
    if (folder.type == FileType.folder) {
      _pathHistory.add(_currentParentId ?? 
        // If currentParentId is null, it means we are at the root, so add an empty string to history
        // so we can go back to root from sub-folder
        
        '');
      await _loadDriveItems(parentId: folder.id);
    }
  }

  Future<void> goBack() async {
    if (_pathHistory.isNotEmpty) {
      String? previousParentId = _pathHistory.removeLast();
      if (previousParentId == '') previousParentId = null; // Back to root
      await _loadDriveItems(parentId: previousParentId);
    }
  }

  Future<void> uploadFile(String fileName, List<int> fileBytes) async {
    await _driveService.uploadFile(fileName, fileBytes, parentId: _currentParentId);
    await _loadDriveItems(parentId: _currentParentId);
  }

  Future<void> createFolder(String folderName) async {
    await _driveService.createFolder(folderName, parentId: _currentParentId);
    await _loadDriveItems(parentId: _currentParentId);
  }

  Future<void> downloadFile(DriveItem file) async {
    await _driveService.downloadFile(file);
    // After download, update the item's offline availability status
    await _loadDriveItems(parentId: _currentParentId);
  }

  Future<void> toggleOfflineAvailability(DriveItem item) async {
    await _driveService.toggleOfflineAvailability(item);
    await _loadDriveItems(parentId: _currentParentId);
  }

  Future<List<DriveItem>> getOfflineFiles() async {
    return await _driveService.getOfflineFiles();
  }
}
