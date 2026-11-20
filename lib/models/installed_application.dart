import 'dart:typed_data';

class InstalledApplication {
  const InstalledApplication({
    required this.packageName,
    required this.appName,
    this.iconBytes,
  });

  final String packageName;
  final String appName;
  final Uint8List? iconBytes;

  factory InstalledApplication.fromMap(Map<Object?, Object?> map) =>
      InstalledApplication(
        packageName: map['packageName']! as String,
        appName: map['appName']! as String,
        iconBytes: map['icon'] as Uint8List?,
      );
}
