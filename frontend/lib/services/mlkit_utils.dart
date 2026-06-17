import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class MLKitUtils {
  static final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  static InputImage? inputImageFromCameraImage(
      CameraImage image, CameraController controller) {
    final camera = controller.description;
    final sensorOrientation = camera.sensorOrientation;

    // Convert logic specific to iOS/Android
    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      var rotationCompensation =
          _orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (defaultTargetPlatform == TargetPlatform.android &&
            format != InputImageFormat.nv21 &&
            format != InputImageFormat.yuv_420_888)) {
      return null;
    }

    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: defaultTargetPlatform == TargetPlatform.android
          ? image.planes[0].bytes // Tạm thời dùng mặt phẳng đầu tiên (NV21)
          : image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }
}
