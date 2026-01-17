import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class BackupService extends ChangeNotifier {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  bool _isSignedIn = false;
  bool get isSignedInValue => _isSignedIn;

  static const String _appFolderName = 'Note_OverTime_Backup';
  static const String _backupFileName = 'overtime_backup.db';

  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;
  String? _appFolderId;

  // Initialize Google Sign In
  Future<void> initializeGoogleSignIn() async {
    _googleSignIn = GoogleSignIn(
      scopes: [
        drive.DriveApi.driveFileScope,
        drive.DriveApi.driveAppdataScope,
      ],
    );
  }

  // Sign in to Google
  Future<bool> signIn() async {
    try {
      if (_googleSignIn == null) {
        await initializeGoogleSignIn();
      }

      final account = await _googleSignIn!.signIn();
      if (account != null) {
        final auth = await account.authentication;
        final client = GoogleAuthClient(auth.accessToken!);
        _driveApi = drive.DriveApi(client);
        _isSignedIn = true;
        notifyListeners();
        return true;
      }
      _isSignedIn = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Google Sign In error: $e');
      return false;
    }
  }

  // Sign out from Google
  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    _driveApi = null;
    _appFolderId = null;
    _isSignedIn = false;
    notifyListeners();
  }

  // Check if user is signed in
  Future<bool> isSignedIn() async {
    _isSignedIn = await _googleSignIn?.isSignedIn() ?? false;
    return _isSignedIn;
  }

  // Silent sign in - restore previous session without UI
  // This is fast and doesn't require user interaction
  Future<bool> signInSilently() async {
    try {
      if (_googleSignIn == null) {
        await initializeGoogleSignIn();
      }
      
      final account = await _googleSignIn!.signInSilently();
      if (account != null) {
        final auth = await account.authentication;
        final client = GoogleAuthClient(auth.accessToken!);
        _driveApi = drive.DriveApi(client);
        _isSignedIn = true;
        notifyListeners();
        return true;
      }
      _isSignedIn = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Silent sign in error: $e');
      return false;
    }
  }

  // Get app folder ID (create if not exists)
  Future<String?> getOrCreateAppFolder() async {
    if (_appFolderId != null) return _appFolderId;

    try {
      if (_driveApi == null) return null;

      // Check if folder already exists
      final query = "name = '$_appFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final existingFolders = await _driveApi!.files.list(q: query);

      if (existingFolders.files != null && existingFolders.files!.isNotEmpty) {
        _appFolderId = existingFolders.files!.first.id;
        return _appFolderId;
      }

      // Create new folder
      final folderMetadata = drive.File()
        ..name = _appFolderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await _driveApi!.files.create(folderMetadata);
      _appFolderId = createdFolder.id;
      return _appFolderId;
    } catch (e) {
      debugPrint('Error creating/getting app folder: $e');
      return null;
    }
  }

  // Backup database to Google Drive
  Future<bool> backupDatabase() async {
    try {
      if (_driveApi == null) {
        final signedIn = await signInSilently();
        if (!signedIn) return false;
      }

      final folderId = await getOrCreateAppFolder();
      if (folderId == null) return false;

      // Get database file path
      final dbPath = await getDatabasesPath();
      final dbFile = File(path.join(dbPath, 'overtime.db'));

      if (!await dbFile.exists()) {
        debugPrint('Database file does not exist');
        return false;
      }

      // Read database file
      final dbBytes = await dbFile.readAsBytes();

      // Create backup file metadata
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final backupFileName = '${_backupFileName.split('.')[0]}_$timestamp.db';

      final fileMetadata = drive.File()
        ..name = backupFileName
        ..parents = [folderId];

      // Upload file
      final media = drive.Media(Stream.value(dbBytes), dbBytes.length);
      final uploadedFile = await _driveApi!.files.create(
        fileMetadata,
        uploadMedia: media,
      );

      debugPrint('Database backup successful: ${uploadedFile.id}');

      // Save backup info locally
      await _saveBackupInfo(backupFileName, uploadedFile.id!, dbBytes.length);

      return true;
    } catch (e) {
      debugPrint('Backup error: $e');
      return false;
    }
  }

  // Auto-backup database and images
  Future<Map<String, bool>> backupAll({Map<String, List<String>>? projectImagePaths}) async {
    final results = <String, bool>{};

    // Backup database
    results['database'] = await backupDatabase();

    // Backup images by project
    if (projectImagePaths != null && projectImagePaths.isNotEmpty) {
      bool allImagesSuccess = true;
      for (final entry in projectImagePaths.entries) {
        final success = await backupImages(entry.value, projectName: entry.key);
        if (!success) allImagesSuccess = false;
      }
      results['images'] = allImagesSuccess;
    }

    return results;
  }

  // Auto-restore database
  Future<Map<String, bool>> restoreAll({String? backupFileId}) async {
    final results = <String, bool>{};

    // Restore database
    results['database'] = await restoreDatabase(backupFileId: backupFileId);

    // Restore images
    final restoredImages = await restoreImages();
    results['images'] = restoredImages.isNotEmpty;

    return results;
  }

  // Restore database from Google Drive
  Future<bool> restoreDatabase({String? backupFileId}) async {
    try {
      if (_driveApi == null) {
        final signedIn = await signInSilently();
        if (!signedIn) return false;
      }

      String? fileId = backupFileId;
      if (fileId == null) {
        // Get latest backup
        fileId = await _getLatestBackupFileId();
        if (fileId == null) return false;
      }

      // Download file
      final file = await _driveApi!.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final dbBytes = <int>[];
      await for (final chunk in file.stream) {
        dbBytes.addAll(chunk);
      }

      // Save to local database
      final dbPath = await getDatabasesPath();
      final dbFile = File(path.join(dbPath, 'overtime.db'));

      // Create backup of current database before restore
      if (await dbFile.exists()) {
        final backupPath = path.join(dbPath, 'overtime_backup_before_restore.db');
        await dbFile.copy(backupPath);
      }

      // Write new database
      await dbFile.writeAsBytes(dbBytes);

      debugPrint('Database restore successful');

      // Save restore info
      await _saveRestoreInfo(fileId, dbBytes.length);

      return true;
    } catch (e) {
      debugPrint('Restore error: $e');
      return false;
    }
  }

  // Get list of backup files
  Future<List<Map<String, dynamic>>> getBackupList() async {
    try {
      if (_driveApi == null) {
        final signedIn = await signInSilently();
        if (!signedIn) return [];
      }

      final folderId = await getOrCreateAppFolder();
      if (folderId == null) return [];

      final query = "'$folderId' in parents and trashed = false";
      final files = await _driveApi!.files.list(
        q: query,
        orderBy: 'createdTime desc',
        pageSize: 20,
        $fields: 'files(id, name, createdTime, size)',
      );

      return files.files?.map((file) {
        return {
          'id': file.id,
          'name': file.name,
          'createdTime': file.createdTime?.toLocal(),
          'size': file.size,
        };
      }).toList() ?? [];
    } catch (e) {
      debugPrint('Error getting backup list: $e');
      return [];
    }
  }

  // Delete backup file
  Future<bool> deleteBackup(String fileId) async {
    try {
      if (_driveApi == null) return false;
      await _driveApi!.files.delete(fileId);
      return true;
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }

  // Backup images to Google Drive
  Future<bool> backupImages(List<String> imagePaths, {String projectName = 'Mặc định'}) async {
    try {
      if (_driveApi == null) {
        final signedIn = await signInSilently();
        if (!signedIn) return false;
      }

      final folderId = await getOrCreateAppFolder();
      if (folderId == null) return false;

      // Create/Get images subfolder
      final imagesFolderId = await _getOrCreateImagesFolder(folderId);
      if (imagesFolderId == null) return false;

      // Create/Get project subfolder within images folder
      final projectFolderId = await _getOrCreateSubfolder(imagesFolderId, projectName);
      if (projectFolderId == null) return false;

      // Get list of existing files in project folder to avoid duplicates
      final existingFilesQuery = "'$projectFolderId' in parents and trashed = false";
      final existingFilesList = await _driveApi!.files.list(q: existingFilesQuery, $fields: 'files(name)');
      final existingFileNames = existingFilesList.files?.map((f) => f.name).toSet() ?? {};

      for (final imagePath in imagePaths) {
        final imageFile = File(imagePath);
        if (!await imageFile.exists()) continue;

        final fileName = path.basename(imagePath);
        
        // Skip if already exists
        if (existingFileNames.contains(fileName)) {
          debugPrint('Image $fileName already exists in project $projectName on Drive, skipping.');
          continue;
        }

        final bytes = await imageFile.readAsBytes();

        final fileMetadata = drive.File()
          ..name = fileName
          ..parents = [projectFolderId];

        final media = drive.Media(Stream.value(bytes), bytes.length);
        await _driveApi!.files.create(
          fileMetadata,
          uploadMedia: media,
        );
        debugPrint('Uploaded image: $fileName to project: $projectName');
      }

      return true;
    } catch (e) {
      debugPrint('Backup images error: $e');
      return false;
    }
  }

  /// Helper to get or create a subfolder by name
  Future<String?> _getOrCreateSubfolder(String parentId, String folderName) async {
    try {
      final query = "name = '$folderName' and '$parentId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final list = await _driveApi!.files.list(q: query);
      
      if (list.files != null && list.files!.isNotEmpty) {
        return list.files!.first.id;
      }

      final folderMetadata = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [parentId];

      final folder = await _driveApi!.files.create(folderMetadata);
      return folder.id;
    } catch (e) {
      debugPrint('Error creating subfolder $folderName: $e');
      return null;
    }
  }

  // Restore images from Google Drive
  Future<List<String>> restoreImages() async {
    try {
      if (_driveApi == null) {
        final signedIn = await signInSilently();
        if (!signedIn) return [];
      }

      final folderId = await getOrCreateAppFolder();
      if (folderId == null) return [];

      final imagesFolderId = await _getOrCreateImagesFolder(folderId);
      if (imagesFolderId == null) return [];

      final query = "'$imagesFolderId' in parents and trashed = false";
      final files = await _driveApi!.files.list(q: query);

      final restoredPaths = <String>[];

      for (final file in files.files ?? []) {
        try {
          final media = await _driveApi!.files.get(file.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
          final bytes = <int>[];
          await for (final chunk in media.stream) {
            bytes.addAll(chunk);
          }

          // Save to local images directory
          final appDir = await getApplicationDocumentsDirectory();
          final imagesDir = Directory(path.join(appDir.path, 'images'));
          if (!await imagesDir.exists()) {
            await imagesDir.create(recursive: true);
          }

          final localPath = path.join(imagesDir.path, file.name!);
          final localFile = File(localPath);
          await localFile.writeAsBytes(bytes);

          restoredPaths.add(localPath);
        } catch (e) {
          debugPrint('Error restoring image ${file.name}: $e');
        }
      }

      return restoredPaths;
    } catch (e) {
      debugPrint('Restore images error: $e');
      return [];
    }
  }

  // Helper methods
  Future<String?> _getOrCreateImagesFolder(String parentFolderId) async {
    try {
      const imagesFolderName = 'images';

      // Check if folder exists
      final query = "name = '$imagesFolderName' and '$parentFolderId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final existingFolders = await _driveApi!.files.list(q: query);

      if (existingFolders.files != null && existingFolders.files!.isNotEmpty) {
        return existingFolders.files!.first.id;
      }

      // Create new folder
      final folderMetadata = drive.File()
        ..name = imagesFolderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [parentFolderId];

      final createdFolder = await _driveApi!.files.create(folderMetadata);
      return createdFolder.id;
    } catch (e) {
      debugPrint('Error creating images folder: $e');
      return null;
    }
  }

  Future<String?> _getLatestBackupFileId() async {
    final backups = await getBackupList();
    return backups.isNotEmpty ? backups.first['id'] as String : null;
  }

  Future<void> _saveBackupInfo(String fileName, String fileId, int size) async {
    final prefs = await SharedPreferences.getInstance();
    final backupInfo = {
      'fileName': fileName,
      'fileId': fileId,
      'size': size,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString('last_backup_info', json.encode(backupInfo));
  }

  Future<void> _saveRestoreInfo(String fileId, int size) async {
    final prefs = await SharedPreferences.getInstance();
    final restoreInfo = {
      'fileId': fileId,
      'size': size,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString('last_restore_info', json.encode(restoreInfo));
  }

  Future<Map<String, dynamic>?> getLastBackupInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final info = prefs.getString('last_backup_info');
    return info != null ? json.decode(info) : null;
  }

  Future<Map<String, dynamic>?> getLastRestoreInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final info = prefs.getString('last_restore_info');
    return info != null ? json.decode(info) : null;
  }


  // Helper methods for getting provider and image paths
  Future<dynamic> _getOvertimeProvider() async {
    // This would need to be injected or accessed differently
    // For now, return null - images backup will be handled separately
    return null;
  }

  Future<List<String>> _getImagePaths(dynamic provider) async {
    // This would get image paths from provider
    // For now, return empty list
    return [];
  }
}

// Google Auth Client for HTTP requests
class GoogleAuthClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _client.send(request);
  }
}



