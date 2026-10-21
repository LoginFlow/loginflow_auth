import 'package:loginflow_auth/src/sign_in/model/passkeys_state.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/passkeys_viewmodel.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

/// The passkey manager's state. Works with the client installed for the
/// sign-in UI (`LoginFlowSignInSetup.install`, `SignInService.environment`).
mixin PasskeysService {
  static final ReactiveNotifierViewModel<PasskeysViewModel, PasskeysState>
  manager = ReactiveNotifierViewModel<PasskeysViewModel, PasskeysState>(
    PasskeysViewModel.new,
  );
}
