import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:myapp/features/auth/account_service.dart';
import 'package:myapp/features/drive/file_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DriveService {
  final AccountService _accountService = AccountService();

  Future<List<DriveItem>> getDriveItems({String? parentId}) async {
    final client = await _accountService.getAuthenticatedClient();
    if (client == null) throw Exception("Not logged in");

    try {
      final driveApi = drive.DriveApi(client);
      // 'root' is the alias for the root folder if parentId is null
      final String q = "'${parentId ?? 'root'}' in parents and trashed = false";

      final fileList = await driveApi.files.list(
        q: q,
        $fields: "files(id, name, mimeType, parents, thumbnailLink, iconLink, size, createdTime, modifiedTime)",
        pageSize: 100, // Adjust as needed
      );

      if (fileList.files == null) return [];

      return fileList.files!.map((f) {
        FileType type = FileType.other;
        if (f.mimeType == 'application/vnd.google-apps.folder') {
          type = FileType.folder;
        } else if (f.mimeType?.startsWith('image/') == true) {
          type = FileType.image;
        } else if (f.mimeType?.startsWith('video/') == true) {
          type = FileType.video;
        } else if (f.mimeType?.startsWith('audio/') == true) {
          type = FileType.audio;
        } else {
          type = FileType.document;
        }

        return DriveItem(
          id: f.id!,
          name: f.name ?? 'Untitled',
          type: type,
          parentId: f.parents?.firstOrNull,
          createdAt: f.createdTime ?? DateTime.now(),
          lastModified: f.modifiedTime,
          size: f.size != null ? int.tryParse(f.size!) : null,
          downloadUrl: null, // Not used directly for Drive API downloads
          thumbnailUrl: f.thumbnailLink,
          mimeType: f.mimeType,
        );
      }).toList();
    } catch (e) {
      print("Drive API Error: $e");
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> uploadFile(String fileName, File localFile, {String? parentId}) async {
    final client = await _accountService.getAuthenticatedClient();
    if (client == null) throw Exception("Not logged in");

    try {
      final driveApi = drive.DriveApi(client);
      var media = drive.Media(localFile.openRead(), localFile.lengthSync());
      var driveFile = drive.File();
      driveFile.name = fileName;
      if (parentId != null) {
        driveFile.parents = [parentId];
      }

      await driveApi.files.create(driveFile, uploadMedia: media);
    } catch (e) {
      print("Upload Error: $e");
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> createFolder(String folderName, {String? parentId}) async {
    final client = await _accountService.getAuthenticatedClient();
    if (client == null) throw Exception("Not logged in");

    try {
      final driveApi = drive.DriveApi(client);
      var driveFile = drive.File();
      driveFile.name = folderName;
      driveFile.mimeType = 'application/vnd.google-apps.folder';
      if (parentId != null) {
        driveFile.parents = [parentId];
      }

      await driveApi.files.create(driveFile);
    } finally {
      client.close();
    }
  }

  Future<void> renameFile(String fileId, String newName) async {
    final client = await _accountService.getAuthenticatedClient();
    if (client == null) throw Exception("Not logged in");

    try {
      final driveApi = drive.DriveApi(client);
      var driveFile = drive.File();
      driveFile.name = newName;

      await driveApi.files.update(driveFile, fileId);
    } finally {
      client.close();
    }
  }

  Future<void> deleteFile(String fileId) async {
    final client = await _accountService.getAuthenticatedClient();
    if (client == null) throw Exception("Not logged in");

    try {
      final driveApi = drive.DriveApi(client);
      await driveApi.files.delete(fileId);
    } finally {
      client.close();
    }
  }

  Future<String> _getDownloadPath() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isGranted) {
         // Good
      } else if (await Permission.storage.request().isGranted) {
         // Good
      }

      final directory = Directory('/storage/emulated/0/foss-drive');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory.path;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  Future<String> _getOfflineStoragePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${directory.path}/offline_files');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    return offlineDir.path;
  }

  Future<void> downloadFile(DriveItem item) async {
    final client = await _accountService.getAuthenticatedClient();
    if (client == null) throw Exception("Not logged in");

    try {
      final driveApi = drive.DriveApi(client);
      drive.Media? media = await driveApi.files.get(
        item.id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media?;

      if (media == null) throw Exception("Could not download file");

      final downloadPath = await _getDownloadPath();
      final saveFile = File('$downloadPath/${item.name}');

      final stream = media.stream;
      final sink = saveFile.openWrite();
      await stream.pipe(sink);
      await sink.close();

      // Update offline status locally if needed
      await _markAsOffline(item, saveFile);

    } catch (e) {
      print("Download Error: $e");
      rethrow;
    } finally {
      client.close();
    }
  }

  // Helper to mark offline (internal logic similar to previous)
  Future<void> _markAsOffline(DriveItem item, File savedFile) async {
      // Logic to track offline status.
      // Since we switched to real API, "Offline" status implies we have a local copy
      // linked to the remote ID. We need a local DB for this map.
      // For this prototype, I'll rely on checking if file exists in offline folder.
      // But here we just downloaded to public folder.
  }

  // Real implementation for toggleOffline
  Future<void> toggleOfflineAvailability(DriveItem item) async {
    final client = await _accountService.getAuthenticatedClient();
    if (client == null) throw Exception("Not logged in");

    final offlinePath = await _getOfflineStoragePath();
    final offlineFile = File('$offlinePath/${item.id}_${item.name}');

    if (await offlineFile.exists()) {
      // Remove
      await offlineFile.delete();
      // We need a way to refresh UI state about this item.
      // Returns void, UI needs to assume success or check again.
    } else {
      // Download to offline path
       try {
        final driveApi = drive.DriveApi(client);
        drive.Media? media = await driveApi.files.get(
            item.id,
            downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media?;

        if (media != null) {
            final sink = offlineFile.openWrite();
            await media.stream.pipe(sink);
            await sink.close();
        }
      } finally {
        client.close();
      }
    }
  }

  Future<List<DriveItem>> getOfflineFiles() async {
    final offlinePath = await _getOfflineStoragePath();
    final dir = Directory(offlinePath);
    if (!await dir.exists()) return [];

    List<DriveItem> items = [];
    await for (var entity in dir.list()) {
      if (entity is File) {
        String filename = entity.uri.pathSegments.last;
        // Expected format: ID_NAME
        int underscoreIndex = filename.indexOf('_');
        if (underscoreIndex != -1) {
            String id = filename.substring(0, underscoreIndex);
            String name = filename.substring(underscoreIndex + 1);

            items.add(DriveItem(
                id: id,
                name: name,
                type: FileType.document, // Can't know for sure without metadata storage
                createdAt: await entity.lastModified(),
                size: await entity.length(),
                isOfflineAvailable: true,
            ));
        }
      }
    }
    return items;
  }

  // Helper to check offline status for a list of items
  Future<List<DriveItem>> checkOfflineStatus(List<DriveItem> items) async {
      final offlinePath = await _getOfflineStoragePath();
      List<DriveItem> updated = [];
      for(var item in items) {
          final file = File('$offlinePath/${item.id}_${item.name}');
          if (await file.exists()) {
              updated.add(item.copyWith(isOfflineAvailable: true));
          } else {
              updated.add(item);
          }
      }
      return updated;
  }
}

extension ListOrNull on List<String> {
  String? get firstOrNull => isNotEmpty ? first : null;
}
