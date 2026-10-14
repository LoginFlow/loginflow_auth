import 'package:loginflow_auth/src/sign_in/model/sign_in_environment.dart';
import 'package:loginflow_auth/src/sign_in/model/sign_in_state.dart';
import 'package:loginflow_auth/src/sign_in/viewmodel/sign_in_viewmodel.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

/// The sign-in UI's state: the installed environment and the flow ViewModel.
mixin SignInService {
  static final ReactiveNotifier<SignInEnvironment> environment =
      ReactiveNotifier<SignInEnvironment>(
        () => const SignInEnvironment.notInstalled(),
      );

  static final ReactiveNotifierViewModel<SignInViewModel, SignInState> flow =
      ReactiveNotifierViewModel<SignInViewModel, SignInState>(
        SignInViewModel.new,
      );
}
