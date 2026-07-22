class AppConstants {
  static const String appName = 'PlanSphere';
  static const String appTagline = 'Smart Bills, Documents & Warranty Tracker';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String billsCollection = 'bills';
  static const String documentsCollection = 'documents';
  static const String notificationsCollection = 'notifications';
  static const String familyGroupsCollection = 'family_groups';
  static const String analyticsCollection = 'analytics';
  static const String settingsCollection = 'settings';

  // Firebase Storage Paths
  static const String billImagesPath = 'bill_images';
  static const String billPdfsPath = 'bill_pdfs';
  static const String documentFilesPath = 'documents';
  static const String profileImagesPath = 'profile_images';

  // SharedPreferences Keys
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyThemeMode = 'theme_mode';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyUserId = 'user_id';
  static const String keyLastBackup = 'last_backup';
  static const String keyLanguage = 'language';

  // Notification Channels
  static const String warrantyChannelId = 'warranty_reminders';
  static const String warrantyChannelName = 'Warranty Reminders';
  static const String documentChannelId = 'document_reminders';
  static const String documentChannelName = 'Document Reminders';
  static const String backupChannelId = 'backup_reminders';
  static const String backupChannelName = 'Backup Reminders';

  // Warranty Reminder Days
  static const List<int> warrantyReminderDays = [90, 30, 7];

  // Bill Categories
  static const List<String> billCategories = [
    'Electronics',
    'Appliances',
    'Food & Grocery',
    'Medical',
    'Travel',
    'Insurance',
    'Education',
    'Utilities',
    'Fuel',
    'Entertainment',
    'Clothing',
    'Home & Garden',
    'Automobile',
    'Others',
  ];

  // Document Categories
  static const List<String> documentCategories = [
    'Medical Records',
    'Financial Documents',
    'Vehicle Documents',
    'Warranties',
    'Others',
  ];

  // Record Types
  static const List<String> recordTypes = [
    'Warranty Bill',
    'Non-Warranty Bill',
    'Utility Bill',
    'Medical Bill',
    'Travel Ticket',
    'Insurance Policy',
    'Certificate',
    'Invoice',
    'Others',
  ];

  // Currency
  static const String currency = '₹';
  static const String currencyCode = 'INR';

  // Pagination
  static const int pageSize = 20;

  // File Size Limits
  static const int maxImageSizeMB = 10;
  static const int maxPdfSizeMB = 20;
  static const int maxStorageFreeGB = 1;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusXXL = 32.0;

  // Padding
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  // Icon Sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXL = 48.0;
}
