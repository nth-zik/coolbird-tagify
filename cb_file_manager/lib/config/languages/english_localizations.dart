import 'app_localizations.dart';

class EnglishLocalizations implements AppLocalizations {
  @override
  String get appTitle => 'CoolBird - File Manager';

  // Common actions
  @override
  String get ok => 'OK';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get delete => 'Delete';
  @override
  String get edit => 'Edit';
  @override
  String get close => 'Close';
  @override
  String get search => 'Search';
  @override
  String get settings => 'Settings';

  // File operations
  @override
  String get copy => 'Copy';
  @override
  String get move => 'Move';
  @override
  String get rename => 'Rename';
  @override
  String get newFolder => 'New Folder';
  @override
  String get properties => 'Properties';
  @override
  String get openWith => 'Open with';

  // Navigation
  @override
  String get home => 'Home';
  @override
  String get back => 'Back';
  @override
  String get forward => 'Forward';
  @override
  String get refresh => 'Refresh';
  @override
  String get parentFolder => 'Parent Folder';
  @override
  String get local => 'Local';
  @override
  String get networks => 'Networks';

  // File types
  @override
  String get image => 'Image';
  @override
  String get video => 'Video';
  @override
  String get audio => 'Audio';
  @override
  String get document => 'Document';
  @override
  String get folder => 'Folder';
  @override
  String get file => 'File';

  // Settings
  @override
  String get language => 'Language';
  @override
  String get theme => 'Theme';
  @override
  String get darkMode => 'Dark Mode';
  @override
  String get lightMode => 'Light Mode';
  @override
  String get systemMode => 'System Mode';

  // Messages
  @override
  String get fileDeleteConfirmation =>
      'Are you sure you want to delete this file?';
  @override
  String get folderDeleteConfirmation =>
      'Are you sure you want to delete this folder and all its contents?';
  @override
  String get fileDeleteSuccess => 'File deleted successfully';
  @override
  String get folderDeleteSuccess => 'Folder deleted successfully';
  @override
  String get operationFailed => 'Operation failed';

  // Tags
  @override
  String get tags => 'Tags';
  @override
  String get addTag => 'Add Tag';
  @override
  String get removeTag => 'Remove Tag';
  @override
  String get tagManagement => 'Tag Management';

  // Gallery
  @override
  String get imageGallery => 'Image Gallery';
  @override
  String get videoGallery => 'Video Gallery';

  // Additional translations for database settings
  @override
  String get databaseSettings => 'Database Settings';
  @override
  String get databaseStorage => 'Database Storage';
  @override
  String get useObjectBox => 'Use ObjectBox Database';
  @override
  String get databaseDescription =>
      'Store tags and preferences in a local database';
  @override
  String get jsonStorage => 'Using JSON file for basic storage';
  @override
  String get objectBoxStorage =>
      'Using ObjectBox for efficient local database storage';

  // Cloud sync
  @override
  String get cloudSync => 'Cloud Sync';
  @override
  String get enableCloudSync => 'Enable Cloud Sync';
  @override
  String get cloudSyncDescription => 'Sync tags and preferences to the cloud';
  @override
  String get syncToCloud => 'Sync to Cloud';
  @override
  String get syncFromCloud => 'Sync from Cloud';
  @override
  String get cloudSyncEnabled =>
      'Tags and preferences will be synced to the cloud';
  @override
  String get cloudSyncDisabled => 'Cloud sync is disabled';
  @override
  String get enableObjectBoxForCloud =>
      'Enable ObjectBox database to use cloud sync';

  // Database statistics
  @override
  String get databaseStatistics => 'Database Statistics';
  @override
  String get totalUniqueTags => 'Total unique tags';
  @override
  String get taggedFiles => 'Tagged files';
  @override
  String get popularTags => 'Most Popular Tags';
  @override
  String get noTagsFound => 'No tags found';
  @override
  String get refreshStatistics => 'Refresh Statistics';

  // Import/Export
  @override
  String get importExportDatabase => 'Import/Export Database';
  @override
  String get backupRestoreDescription =>
      'Backup and restore your tags and file relationships';
  @override
  String get exportDatabase => 'Export Database';
  @override
  String get exportSettings => 'Export Settings';
  @override
  String get importDatabase => 'Import Database';
  @override
  String get importSettings => 'Import Settings';
  @override
  String get exportDescription => 'Save your tags to a file';
  @override
  String get importDescription => 'Restore your tags from a file';
  @override
  String get completeBackup => 'Complete Backup';
  @override
  String get completeRestore => 'Complete Restore';
  @override
  String get exportAllData => 'Export all settings and database data';
  @override
  String get importAllData => 'Import all settings and database data';

  // Export/Import messages
  @override
  String get exportSuccess => 'Successfully exported to: ';
  @override
  String get exportFailed => 'Export failed';
  @override
  String get importSuccess => 'Successfully imported';
  @override
  String get importFailed => 'Import failed or canceled';
  @override
  String get importCancelled => 'Import cancelled';
  @override
  String get errorExporting => 'Error exporting: ';
  @override
  String get errorImporting => 'Error importing: ';

  // Video thumbnails
  @override
  String get videoThumbnails => 'Video Thumbnails';
  @override
  String get thumbnailPosition => 'Thumbnail position:';
  @override
  String get percentOfVideo => 'percent of video';
  @override
  String get thumbnailDescription =>
      'Set the position in the video (as a percentage of total duration) where thumbnails will be extracted';
  @override
  String get thumbnailCache => 'Thumbnail Cache';
  @override
  String get thumbnailCacheDescription =>
      'Video thumbnails are cached to improve performance. If thumbnails appear outdated or you want to free up space, you can clear the cache.';
  @override
  String get clearThumbnailCache => 'Clear Thumbnail Cache';
  @override
  String get clearing => 'Clearing...';
  @override
  String get thumbnailCleared => 'All video thumbnails cleared';
  @override
  String get errorClearingThumbnail => 'Error clearing thumbnails: ';

  // New tab
  @override
  String get newTab => 'New Tab';

  // Admin access
  @override
  String get adminAccess => 'Admin Access';
  @override
  String get adminAccessRequired =>
      'This drive requires administrator privileges to access';

  // File system
  @override
  String get drives => 'Drives';
  @override
  String get system => 'System';

  // Settings data
  @override
  String get settingsData => 'Settings Data';
  @override
  String get viewManageSettings => 'View and manage settings data';

  // About app
  @override
  String get aboutApp => 'About';
  @override
  String get appDescription =>
      'A powerful file manager with tagging capabilities';
  @override
  String get version => 'Version: 1.0.0';
  @override
  String get developer => 'Developed by CoolBird Team';

  // File picker dialogs
  @override
  String get chooseBackupLocation => 'Choose location to save backup';
  @override
  String get chooseRestoreLocation => 'Choose backup to restore';
  @override
  String get saveSettingsExport => 'Save Settings Export';
  @override
  String get saveDatabaseExport => 'Save Database Export';
  @override
  String get selectBackupFolder => 'Select backup folder to import';
}
