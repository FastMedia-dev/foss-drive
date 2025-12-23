import 'dart:io';
import 'package:flutter/material.dart';
import 'package:myapp/features/drive/drive_service.dart';
import 'package:myapp/features/drive/file_model.dart';

class DriveNotifier with ChangeNotifier {
  final DriveService _driveService = DriveService();
  List<DriveItem> _currentFolderItems = [];
  List<DriveItem> get currentFolderItems => _currentFolderItems;

  String? _currentParentId; // Null for root folder
  String? get currentParentId => _currentParentId;

  String? _currentFolderName;
  String? get currentFolderName => _currentFolderName;

  List<String> _pathHistory = []; // To navigate back
  List<String> _nameHistory = [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  DriveNotifier() {
    // Initial load happens after login usually
  }

  // Call this when switching accounts to reset state
  void reset() {
      _currentFolderItems = [];
      _currentParentId = null;
      _currentFolderName = null;
      _pathHistory = [];
      _nameHistory = [];
      notifyListeners();
  }

  Future<void> refresh() async {
    // If not logged in, this might fail, but UI usually handles check
    await _loadDriveItems(parentId: _currentParentId);
  }

  Future<void> _loadDriveItems({String? parentId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      var items = await _driveService.getDriveItems(parentId: parentId);
      // Check offline status
      items = await _driveService.checkOfflineStatus(items);
      _currentFolderItems = items;
      _currentParentId = parentId;
    } catch (e) {
      print("Error loading items: $e");
      // If error (e.g., auth failed), clear items
      _currentFolderItems = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> openFolder(DriveItem folder) async {
    if (folder.type == FileType.folder) {
      _pathHistory.add(_currentParentId ?? '');
      _nameHistory.add(_currentFolderName ?? 'Home');

      _currentFolderName = folder.name;

      await _loadDriveItems(parentId: folder.id);
    }
  }

  Future<void> goBack() async {
    if (_pathHistory.isNotEmpty) {
      String? previousParentId = _pathHistory.removeLast();
      if (previousParentId == '') previousParentId = null; // Back to root

      if (_nameHistory.isNotEmpty) {
        String prevName = _nameHistory.removeLast();
        _currentFolderName = prevName == 'Home' ? null : prevName;
      } else {
        _currentFolderName = null;
      }

      await _loadDriveItems(parentId: previousParentId);
    }
  }

  // Updated to take File instead of bytes/name
  Future<void> uploadFile(File localFile, String fileName) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _driveService.uploadFile(fileName, localFile, parentId: _currentParentId);
      await refresh();
    } catch (e) {
      print("Upload failed: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createFolder(String folderName) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _driveService.createFolder(folderName, parentId: _currentParentId);
      await refresh();
    } catch (e) {
       print("Create folder failed: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> renameFile(DriveItem item, String newName) async {
      _isLoading = true;
      notifyListeners();
      try {
          await _driveService.renameFile(item.id, newName);
          await refresh();
      } catch (e) {
          print("Rename failed: $e");
      }
      _isLoading = false;
      notifyListeners();
  }

  Future<void> deleteFile(DriveItem item) async {
      _isLoading = true;
      notifyListeners();
      try {
          await _driveService.deleteFile(item.id);
          await refresh();
      } catch (e) {
          print("Delete failed: $e");
      }
      _isLoading = false;
      notifyListeners();
  }

  Future<void> downloadFile(DriveItem file) async {
    try {
      await _driveService.downloadFile(file);
    } catch (e) {
      print("Download failed: $e");
      rethrow;
    }
  }

  Future<void> toggleOfflineAvailability(DriveItem item) async {
    await _driveService.toggleOfflineAvailability(item);
    await refresh(); // To update icon state
  }

  Future<List<DriveItem>> getOfflineFiles() async {
    return await _driveService.getOfflineFiles();
  }
}
