import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Lets the user choose where a photo comes from instead of forcing camera.
Future<XFile?> pickImageFromCameraOrGallery(
  BuildContext context, {
  int imageQuality = 82,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose photo source',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.photo_library_outlined)),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Use a photo already on this device'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.camera_alt_outlined)),
                title: const Text('Take a photo'),
                subtitle: const Text('Use the camera now'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (source == null) return null;

  return ImagePicker().pickImage(
    source: source,
    imageQuality: imageQuality,
  );
}

/// Same choice for multiple business/property photos.
Future<List<XFile>> pickMultipleImagesFromGallery(
  BuildContext context, {
  int imageQuality = 82,
  int? limit,
}) async {
  final picked = await ImagePicker().pickMultiImage(imageQuality: imageQuality);
  if (limit == null || picked.length <= limit) return picked;
  return picked.take(limit).toList();
}
