import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/viewmodel/login_screen_vm.dart';

final loginIsLoadingProvider =
    StateProvider.autoDispose<bool>((ref) => false);

final loginErrorMessageProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final otpIsLoadingProvider =
    StateProvider.autoDispose<bool>((ref) => false);

final otpErrorMessageProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final loginScreenVmProvider =
    Provider.autoDispose((ref) => LoginScreenVm(ref));

final otpLoginScreenVmProvider =
    Provider.autoDispose((ref) => OtpLoginScreenVm(ref));
