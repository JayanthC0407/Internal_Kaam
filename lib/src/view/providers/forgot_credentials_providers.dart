import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/viewmodel/forgot_credentials_screen_vm.dart';

final forgotIsLoadingProvider =
    StateProvider.autoDispose<bool>((ref) => false);

final forgotErrorMessageProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final forgotCredentialsScreenVmProvider = Provider.autoDispose(
  (ref) => ForgotCredentialsScreenVm(ref),
);
