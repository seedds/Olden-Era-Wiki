// Host-side driver for the screenshot integration test.
//
// Screenshots are saved (raw) as they are captured.  After the test finishes,
// the safe-area insets reported by the test are read from the response data
// and used to crop the status bar / home indicator black bars from every
// saved PNG.
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test_driver_extended.dart'
    as driver;

const _screenshotDir = 'screenshots';

Future<void> main() async {
  await driver.integrationDriver(
    // Save each screenshot as it arrives (uncropped — insets aren't known yet).
    onScreenshot: (String name, List<int> bytes,
        [Map<String, Object?>? args]) async {
      final file = File('$_screenshotDir/$name.png');
      file.createSync(recursive: true);
      file.writeAsBytesSync(Uint8List.fromList(bytes));
      return true;
    },
    // After the test completes, crop the saved PNGs using the reported insets.
    responseDataCallback: (Map<String, dynamic>? data) async {
      final topInset = (data?['topInset'] as num?)?.toInt() ?? 0;
      final bottomInset = (data?['bottomInset'] as num?)?.toInt() ?? 0;
      if (topInset <= 0 && bottomInset <= 0) return;

      final dir = Directory(_screenshotDir);
      if (!dir.existsSync()) return;

      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.png')) continue;
        final decoded = img.decodePng(entity.readAsBytesSync());
        if (decoded == null) continue;
        final cropped = img.copyCrop(
          decoded,
          x: 0,
          y: topInset,
          width: decoded.width,
          height: decoded.height - topInset - bottomInset,
        );
        entity.writeAsBytesSync(Uint8List.fromList(img.encodePng(cropped)));
      }
    },
  );
}
