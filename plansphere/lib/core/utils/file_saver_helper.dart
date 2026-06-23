import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_mobile.dart' as saver;

class FileSaverHelper {
  static Future<void> saveFile({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    await saver.saveFileWebOrMobile(bytes, fileName, mimeType);
  }
}
