import 'package:universal_io/io.dart';

String getPlatformName() {
  return Platform.operatingSystem;
}

bool isWebPlatform() {
  return false;
}
