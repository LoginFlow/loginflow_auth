import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:loginflow_auth/src/core/error/login_flow_error.dart';
import 'package:result_controller/result_controller.dart';

/// The desktop Secret Service (GNOME Keyring, KWallet) through libsecret,
/// reached over the `flutter_secure_storage_linux` plugin: values are
/// encrypted at rest by the user's keyring and unlocked with their login
/// session. Platform exceptions become [StorageFailure].
final class LinuxKeyring {
  const LinuxKeyring();

  static const Map<String, String> _options = <String, String>{};

  Future<Result<String?, LoginFlowError>> read(String key) => _guard(
    () =>
        FlutterSecureStoragePlatform.instance.read(key: key, options: _options),
  );

  Future<Result<void, LoginFlowError>> write(String key, String value) =>
      _guard(
        () => FlutterSecureStoragePlatform.instance.write(
          key: key,
          value: value,
          options: _options,
        ),
      );

  Future<Result<void, LoginFlowError>> delete(String key) => _guard(
    () => FlutterSecureStoragePlatform.instance.delete(
      key: key,
      options: _options,
    ),
  );

  Future<Result<T, LoginFlowError>> _guard<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return Ok(await operation());
    } on PlatformException catch (error) {
      return Err(
        StorageFailure(description: '${error.code}: ${error.message}'),
      );
    } on MissingPluginException {
      return Err(
        const StorageFailure(
          description: 'No Secret Service plugin on this platform.',
        ),
      );
    }
  }
}
