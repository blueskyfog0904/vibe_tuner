import 'package:fpdart/fpdart.dart';
import 'package:permission_handler/permission_handler.dart';

import '../errors/failure.dart';
import '../logging/error_reporter.dart';

class PermissionManager {
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  /// 마이크 권한을 요청하고 결과를 반환합니다.
  Future<Either<Failure, bool>> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;

      if (status.isGranted) {
        return const Right(true);
      }

      final result = await Permission.microphone.request();
      if (result.isGranted) {
        return const Right(true);
      }
      if (result.isPermanentlyDenied) {
        return const Left(
          PermissionFailure('마이크 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.'),
        );
      }
      return const Left(PermissionFailure('마이크 권한이 거부되었습니다.'));
    } catch (error, stackTrace) {
      AppErrorReporter.reportNonFatal(
        error,
        stackTrace,
        source: 'permission_manager.request',
      );
      return const Left(PermissionFailure('마이크 권한 상태를 확인하지 못했습니다.'));
    }
  }

  Future<bool> isMicrophonePermissionGranted() async {
    try {
      return await Permission.microphone.isGranted;
    } catch (error, stackTrace) {
      AppErrorReporter.reportNonFatal(
        error,
        stackTrace,
        source: 'permission_manager.is_granted',
      );
      return false;
    }
  }
}
