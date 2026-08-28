import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/viewmodel/registration_screen_vm.dart';

final registrationIsLoadingProvider =
    StateProvider.autoDispose<bool>((ref) => false);

final registrationErrorMessageProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final registrationAttemptsLeftProvider =
    StateProvider.autoDispose<int?>((ref) => null);

final registrationIdProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final registrationScreenVmProvider =
    Provider.autoDispose((ref) => RegistrationScreenVm(ref));
