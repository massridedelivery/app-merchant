import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// A locally-picked image: the raw bytes plus the content type MediaRepository
/// needs for the signed upload.
class PickedImage {
  final Uint8List bytes;
  final String contentType;
  const PickedImage(this.bytes, this.contentType);
}

/// image_picker doesn't always report a mime type; infer from the extension.
String? _contentTypeFor(XFile file) {
  final name = file.name.toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  return file.mimeType; // may still be null for an unknown type
}

/// Picks an image from [source] and returns its bytes + content type, or null
/// if the user cancelled or the type can't be determined. Downscales so a phone
/// photo isn't uploaded at full resolution.
Future<PickedImage?> pickImage(
  ImageSource source, {
  double maxWidth = 1200,
  int imageQuality = 85,
}) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: maxWidth,
    imageQuality: imageQuality,
  );
  if (file == null) return null;
  final contentType = _contentTypeFor(file);
  if (contentType == null) return null;
  return PickedImage(await file.readAsBytes(), contentType);
}
