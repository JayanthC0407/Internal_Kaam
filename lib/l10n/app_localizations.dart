import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
    Locale('it'),
    Locale('ru'),
    Locale('uz')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Demo Bank'**
  String get appTitle;

  /// No description provided for @brandName.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get brandName;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter your username and password to login'**
  String get loginSubtitle;

  /// No description provided for @loginDesktopHeadline.
  ///
  /// In en, this message translates to:
  /// **'Banking that\nfits your day.'**
  String get loginDesktopHeadline;

  /// No description provided for @loginDesktopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage cards, transfers and spending insights from one place - now on desktop.'**
  String get loginDesktopSubtitle;

  /// No description provided for @loginCashbackBadge.
  ///
  /// In en, this message translates to:
  /// **'2% CASHBACK'**
  String get loginCashbackBadge;

  /// No description provided for @cashbackPromoTitle.
  ///
  /// In en, this message translates to:
  /// **'✨ 2% Cashback'**
  String get cashbackPromoTitle;

  /// No description provided for @loginCashbackDetail.
  ///
  /// In en, this message translates to:
  /// **'On all card purchases. Earn up to GBP 52 / month.'**
  String get loginCashbackDetail;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get enterUsername;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enterPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @forgotUsername.
  ///
  /// In en, this message translates to:
  /// **'Forgot username?'**
  String get forgotUsername;

  /// No description provided for @forgotUsernameTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Username'**
  String get forgotUsernameTitle;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotUsernameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'To retrieve your Username, please enter your email address and date of birth registered in your bank account.'**
  String get forgotUsernameSubtitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Okay, no problem. Just enter the details below.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @forgotEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get forgotEmailLabel;

  /// No description provided for @forgotEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter email'**
  String get forgotEmailHint;

  /// No description provided for @forgotEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get forgotEmailRequired;

  /// No description provided for @forgotUserNameLabel.
  ///
  /// In en, this message translates to:
  /// **'User Name'**
  String get forgotUserNameLabel;

  /// No description provided for @forgotUserNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get forgotUserNameHint;

  /// No description provided for @forgotUserNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get forgotUserNameRequired;

  /// No description provided for @forgotDateOfBirthLabel.
  ///
  /// In en, this message translates to:
  /// **'Date Of Birth'**
  String get forgotDateOfBirthLabel;

  /// No description provided for @forgotDateOfBirthHint.
  ///
  /// In en, this message translates to:
  /// **'Select date of birth'**
  String get forgotDateOfBirthHint;

  /// No description provided for @forgotDateOfBirthRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get forgotDateOfBirthRequired;

  /// No description provided for @forgotSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get forgotSubmit;

  /// No description provided for @forgotOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'One Time Verification'**
  String get forgotOtpTitle;

  /// No description provided for @forgotOtpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A verification code has been sent to your registered mobile number. Please enter that code below to complete the process.'**
  String get forgotOtpSubtitle;

  /// No description provided for @forgotNoteHeading.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get forgotNoteHeading;

  /// No description provided for @forgotNoteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Not able to recall your User Name?'**
  String get forgotNoteQuestion;

  /// No description provided for @forgotNoteBody.
  ///
  /// In en, this message translates to:
  /// **'Simply enter your registered email ID and authenticate yourself to receive your User ID on your email.'**
  String get forgotNoteBody;

  /// No description provided for @forgotNoteSupport.
  ///
  /// In en, this message translates to:
  /// **'In case you are unable to recover your User ID, please visit our nearest branch or contact and speak to our customer care executive.'**
  String get forgotNoteSupport;

  /// No description provided for @forgotPasswordNoteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Not able to recall your Password?'**
  String get forgotPasswordNoteQuestion;

  /// No description provided for @forgotPasswordNoteBody.
  ///
  /// In en, this message translates to:
  /// **'Simply enter your User Name and date of birth registered in your bank account to receive a password reset link on your email.'**
  String get forgotPasswordNoteBody;

  /// No description provided for @forgotPasswordNoteSupport.
  ///
  /// In en, this message translates to:
  /// **'In case you are unable to recover your Password, please visit our nearest branch or contact and speak to our customer care executive.'**
  String get forgotPasswordNoteSupport;

  /// No description provided for @forgotSuccessHeading.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get forgotSuccessHeading;

  /// No description provided for @forgotUsernameSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'The retrieved Username has been successfully sent to your registered email.'**
  String get forgotUsernameSuccessMessage;

  /// No description provided for @forgotPasswordSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Link to generate a new password has been successfully sent on your email'**
  String get forgotPasswordSuccessMessage;

  /// No description provided for @forgotGoToLogin.
  ///
  /// In en, this message translates to:
  /// **'Login to your bank account'**
  String get forgotGoToLogin;

  /// No description provided for @otpReferenceNumber.
  ///
  /// In en, this message translates to:
  /// **'Reference Number: {reference}'**
  String otpReferenceNumber(String reference);

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @loggingIn.
  ///
  /// In en, this message translates to:
  /// **'Logging in...'**
  String get loggingIn;

  /// No description provided for @keepMeSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Keep me signed in'**
  String get keepMeSignedIn;

  /// No description provided for @loginWithBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Login with biometrics'**
  String get loginWithBiometrics;

  /// No description provided for @featureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'This feature will be available soon.'**
  String get featureComingSoon;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @loginHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Need help signing in?'**
  String get loginHelpTitle;

  /// No description provided for @loginHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick tips for the login screen'**
  String get loginHelpSubtitle;

  /// No description provided for @loginHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the username and password registered with your bank account.\n\nIf you forgot your username or password, use the links below the login form to recover them.\n\nYou can keep yourself signed in on trusted devices. On web, use the virtual keyboard icon for secure entry.\n\nFor further assistance, please visit your nearest branch or contact customer care.'**
  String get loginHelpBody;

  /// No description provided for @loginHelpClose.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get loginHelpClose;

  /// No description provided for @virtualKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Virtual keyboard'**
  String get virtualKeyboard;

  /// No description provided for @virtualKeyboardDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get virtualKeyboardDone;

  /// No description provided for @virtualKeyboardSpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get virtualKeyboardSpace;

  /// No description provided for @virtualKeyboardShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle keys'**
  String get virtualKeyboardShuffle;

  /// No description provided for @virtualKeyboardClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get virtualKeyboardClear;

  /// No description provided for @notRegistered.
  ///
  /// In en, this message translates to:
  /// **'Not registered? '**
  String get notRegistered;

  /// No description provided for @registerHere.
  ///
  /// In en, this message translates to:
  /// **'Register here'**
  String get registerHere;

  /// No description provided for @pleaseEnterCredentials.
  ///
  /// In en, this message translates to:
  /// **'Please enter username and password'**
  String get pleaseEnterCredentials;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @cards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get cards;

  /// No description provided for @deposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get deposit;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @rewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewards;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @scanAndPay.
  ///
  /// In en, this message translates to:
  /// **'Scan & pay'**
  String get scanAndPay;

  /// No description provided for @payBill.
  ///
  /// In en, this message translates to:
  /// **'Pay bill'**
  String get payBill;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get goodMorning;

  /// No description provided for @goodMorningComma.
  ///
  /// In en, this message translates to:
  /// **'Good Morning,'**
  String get goodMorningComma;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'TOTAL BALANCE'**
  String get totalBalance;

  /// No description provided for @moreTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTitle;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @italian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get italian;

  /// No description provided for @uzbek.
  ///
  /// In en, this message translates to:
  /// **'Uzbek'**
  String get uzbek;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @forgetDevice.
  ///
  /// In en, this message translates to:
  /// **'Forget device'**
  String get forgetDevice;

  /// No description provided for @logOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this session on this device?'**
  String get logOutConfirm;

  /// No description provided for @logOutConfirmWithBiometric.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this session on this device?\n\nYou will lose biometric login and will need to set it up again after you sign in.'**
  String get logOutConfirmWithBiometric;

  /// No description provided for @forgetDeviceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove all saved session data from this device? You will need to sign in again.'**
  String get forgetDeviceConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @deviceBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Device not supported'**
  String get deviceBlockedTitle;

  /// No description provided for @deviceBlockedCompromisedMessage.
  ///
  /// In en, this message translates to:
  /// **'For your security, this app cannot run on modified or compromised devices. Please use a standard, unmodified device.'**
  String get deviceBlockedCompromisedMessage;

  /// No description provided for @deviceBlockedEmulatorMessage.
  ///
  /// In en, this message translates to:
  /// **'For your security, this app cannot run on emulators or simulators in production builds.'**
  String get deviceBlockedEmulatorMessage;

  /// No description provided for @deviceBlockedSupport.
  ///
  /// In en, this message translates to:
  /// **'If you believe this is an error, contact your bank support centre.'**
  String get deviceBlockedSupport;

  /// No description provided for @deviceSecurityWarnCompromised.
  ///
  /// In en, this message translates to:
  /// **'Security warning: this device may be modified. Proceed with caution.'**
  String get deviceSecurityWarnCompromised;

  /// No description provided for @deviceSecurityWarnEmulator.
  ///
  /// In en, this message translates to:
  /// **'Security warning: you are using an emulator or simulator.'**
  String get deviceSecurityWarnEmulator;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'accounts, transactions, beneficiaries...'**
  String get searchPlaceholder;

  /// No description provided for @newTransfer.
  ///
  /// In en, this message translates to:
  /// **'New transfer'**
  String get newTransfer;

  /// No description provided for @sampleDateLine.
  ///
  /// In en, this message translates to:
  /// **'Friday, April 19'**
  String get sampleDateLine;

  /// No description provided for @incomeThisMonth.
  ///
  /// In en, this message translates to:
  /// **'INCOME THIS MONTH'**
  String get incomeThisMonth;

  /// No description provided for @spendingThisMonth.
  ///
  /// In en, this message translates to:
  /// **'SPENDING THIS MONTH'**
  String get spendingThisMonth;

  /// No description provided for @availableCredit.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE CREDIT'**
  String get availableCredit;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @myCards.
  ///
  /// In en, this message translates to:
  /// **'My Cards'**
  String get myCards;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @cardCredit.
  ///
  /// In en, this message translates to:
  /// **'CREDIT'**
  String get cardCredit;

  /// No description provided for @cardDebit.
  ///
  /// In en, this message translates to:
  /// **'DEBIT'**
  String get cardDebit;

  /// No description provided for @badgeBillIsLate.
  ///
  /// In en, this message translates to:
  /// **'BILL IS LATE'**
  String get badgeBillIsLate;

  /// No description provided for @badgeActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get badgeActive;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get payNow;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @mySpendings.
  ///
  /// In en, this message translates to:
  /// **'My Spendings'**
  String get mySpendings;

  /// No description provided for @mySpendingsLower.
  ///
  /// In en, this message translates to:
  /// **'My spendings'**
  String get mySpendingsLower;

  /// No description provided for @julySpendings.
  ///
  /// In en, this message translates to:
  /// **'July Spendings'**
  String get julySpendings;

  /// No description provided for @julySpendingsLower.
  ///
  /// In en, this message translates to:
  /// **'July spendings'**
  String get julySpendingsLower;

  /// No description provided for @upcomingActions.
  ///
  /// In en, this message translates to:
  /// **'Upcoming actions'**
  String get upcomingActions;

  /// No description provided for @actionCompleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get actionCompleteProfile;

  /// No description provided for @actionPayCreditCardBill.
  ///
  /// In en, this message translates to:
  /// **'Pay credit card bill'**
  String get actionPayCreditCardBill;

  /// No description provided for @actionVerifyPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify phone number'**
  String get actionVerifyPhone;

  /// No description provided for @actionEnableBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Enable biometrics'**
  String get actionEnableBiometrics;

  /// No description provided for @subtitleDueMar15.
  ///
  /// In en, this message translates to:
  /// **'Due Mar 15'**
  String get subtitleDueMar15;

  /// No description provided for @subtitleForSecureLogin.
  ///
  /// In en, this message translates to:
  /// **'For secure login'**
  String get subtitleForSecureLogin;

  /// No description provided for @subtitleSkipPassword.
  ///
  /// In en, this message translates to:
  /// **'Skip the password'**
  String get subtitleSkipPassword;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @topSpending.
  ///
  /// In en, this message translates to:
  /// **'Top Spending'**
  String get topSpending;

  /// No description provided for @topSpendingLower.
  ///
  /// In en, this message translates to:
  /// **'Top spending'**
  String get topSpendingLower;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get recentTransactions;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @offerPromo.
  ///
  /// In en, this message translates to:
  /// **'On all card spends  •  Earned GBP 82 this month ↑'**
  String get offerPromo;

  /// No description provided for @activateOffer.
  ///
  /// In en, this message translates to:
  /// **'Activate offer ›'**
  String get activateOffer;

  /// No description provided for @visa.
  ///
  /// In en, this message translates to:
  /// **'VISA'**
  String get visa;

  /// No description provided for @visaMasked.
  ///
  /// In en, this message translates to:
  /// **'VISA •••• {tail}'**
  String visaMasked(String tail);

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total {amount}'**
  String totalAmount(String amount);

  /// No description provided for @cardTailMasked.
  ///
  /// In en, this message translates to:
  /// **'•••• {tail}'**
  String cardTailMasked(String tail);

  /// No description provided for @recharge.
  ///
  /// In en, this message translates to:
  /// **'Recharge'**
  String get recharge;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @savings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get savings;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get request;

  /// No description provided for @credit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get credit;

  /// No description provided for @maskedCardNumber.
  ///
  /// In en, this message translates to:
  /// **'XXXX XXXX 7689'**
  String get maskedCardNumber;

  /// No description provided for @primaryAccountHint.
  ///
  /// In en, this message translates to:
  /// **'•••••••••• 7889 · Primary account'**
  String get primaryAccountHint;

  /// No description provided for @categoryTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get categoryTechnology;

  /// No description provided for @categoryFoodDining.
  ///
  /// In en, this message translates to:
  /// **'Food & Dining'**
  String get categoryFoodDining;

  /// No description provided for @categoryHealthcare.
  ///
  /// In en, this message translates to:
  /// **'Healthcare'**
  String get categoryHealthcare;

  /// No description provided for @categoryEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryEntertainment;

  /// No description provided for @categoryTransportation.
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get categoryTransportation;

  /// No description provided for @categoryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryEducation;

  /// No description provided for @categoryUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get categoryUtilities;

  /// No description provided for @categorySalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get categorySalary;

  /// No description provided for @transactionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get transactionSuccess;

  /// No description provided for @transactionPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get transactionPending;

  /// No description provided for @incomingTransfer.
  ///
  /// In en, this message translates to:
  /// **'Incoming transfer'**
  String get incomingTransfer;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @tableDescription.
  ///
  /// In en, this message translates to:
  /// **'DESCRIPTION'**
  String get tableDescription;

  /// No description provided for @tableCategory.
  ///
  /// In en, this message translates to:
  /// **'CATEGORY'**
  String get tableCategory;

  /// No description provided for @tableDate.
  ///
  /// In en, this message translates to:
  /// **'DATE'**
  String get tableDate;

  /// No description provided for @tableAmount.
  ///
  /// In en, this message translates to:
  /// **'AMOUNT'**
  String get tableAmount;

  /// No description provided for @tableStatus.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get tableStatus;

  /// No description provided for @showApiTrace.
  ///
  /// In en, this message translates to:
  /// **'Show API Trace'**
  String get showApiTrace;

  /// No description provided for @errorLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get errorLoginFailed;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect. Please check your internet connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get errorUnexpected;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorAccountLocked.
  ///
  /// In en, this message translates to:
  /// **'Your account is locked. Please contact the bank.'**
  String get errorAccountLocked;

  /// No description provided for @errorPasswordExpired.
  ///
  /// In en, this message translates to:
  /// **'Your password has expired. Please reset your password.'**
  String get errorPasswordExpired;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Please try again later.'**
  String get errorTooManyAttempts;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'For your security, you have been signed out. Please sign in again.'**
  String get errorSessionExpired;

  /// No description provided for @sessionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get sessionExpiredTitle;

  /// No description provided for @sessionExpiredSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get sessionExpiredSignIn;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The banking service is not responding. Please try again later.'**
  String get errorTimeout;

  /// No description provided for @errorBadCertificate.
  ///
  /// In en, this message translates to:
  /// **'Secure connection could not be verified. Please update the app or try again later.'**
  String get errorBadCertificate;

  /// No description provided for @errorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request was cancelled.'**
  String get errorCancelled;

  /// No description provided for @errorAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please sign in again.'**
  String get errorAuthFailed;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to perform this action.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'The requested resource was not found.'**
  String get errorNotFound;

  /// No description provided for @errorServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service is temporarily unavailable. Please try again later.'**
  String get errorServerUnavailable;

  /// No description provided for @errorApiNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'API host is not configured for this build. Run ./scripts/sync_ide_config.sh, then fully restart the app.'**
  String get errorApiNotConfigured;

  /// No description provided for @errorAccountsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load accounts. Please try again.'**
  String get errorAccountsLoadFailed;

  /// No description provided for @accountsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No accounts available.'**
  String get accountsEmpty;

  /// No description provided for @accountsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get accountsRetry;

  /// No description provided for @accountStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get accountStatusActive;

  /// No description provided for @accountStatusDormant.
  ///
  /// In en, this message translates to:
  /// **'Dormant'**
  String get accountStatusDormant;

  /// No description provided for @accountsMultipleCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Balances shown by currency'**
  String get accountsMultipleCurrencies;

  /// No description provided for @availableBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Available balance'**
  String get availableBalanceLabel;

  /// No description provided for @errorLoansLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load loans. Please try again.'**
  String get errorLoansLoadFailed;

  /// No description provided for @loansEmpty.
  ///
  /// In en, this message translates to:
  /// **'No loans available.'**
  String get loansEmpty;

  /// No description provided for @loanTrackerTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Tracker'**
  String get loanTrackerTitle;

  /// No description provided for @loanTotalBorrowing.
  ///
  /// In en, this message translates to:
  /// **'Total Borrowing'**
  String get loanTotalBorrowing;

  /// No description provided for @loanTotalOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Total Outstanding'**
  String get loanTotalOutstanding;

  /// No description provided for @errorLoanDetailsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load loan details. Please try again.'**
  String get errorLoanDetailsLoadFailed;

  /// No description provided for @errorLoanDisbursementsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load disbursement details. Please try again.'**
  String get errorLoanDisbursementsLoadFailed;

  /// No description provided for @errorLoanOutstandingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load outstanding balance. Please try again.'**
  String get errorLoanOutstandingLoadFailed;

  /// No description provided for @errorLoanRepaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to process repayment. Please try again.'**
  String get errorLoanRepaymentFailed;

  /// No description provided for @errorLoanScheduleLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load repayment schedule. Please try again.'**
  String get errorLoanScheduleLoadFailed;

  /// No description provided for @loanApprovedAmount.
  ///
  /// In en, this message translates to:
  /// **'Approved Amount'**
  String get loanApprovedAmount;

  /// No description provided for @loanBranchLabel.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get loanBranchLabel;

  /// No description provided for @loanDetailsTabDisbursements.
  ///
  /// In en, this message translates to:
  /// **'Disbursements'**
  String get loanDetailsTabDisbursements;

  /// No description provided for @loanDetailsTabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get loanDetailsTabOverview;

  /// No description provided for @loanDetailsTabSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get loanDetailsTabSchedule;

  /// No description provided for @loanDisbursedAmount.
  ///
  /// In en, this message translates to:
  /// **'Disbursed Amount'**
  String get loanDisbursedAmount;

  /// No description provided for @loanDisbursementDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get loanDisbursementDateLabel;

  /// No description provided for @loanDisbursementsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No disbursement records available.'**
  String get loanDisbursementsEmpty;

  /// No description provided for @loanInstallmentsDue.
  ///
  /// In en, this message translates to:
  /// **'Installments Due'**
  String get loanInstallmentsDue;

  /// No description provided for @loanInstallmentsPaid.
  ///
  /// In en, this message translates to:
  /// **'Installments Paid'**
  String get loanInstallmentsPaid;

  /// No description provided for @loanInterestRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Interest Rate'**
  String get loanInterestRateLabel;

  /// No description provided for @loanMaturityDate.
  ///
  /// In en, this message translates to:
  /// **'Maturity Date'**
  String get loanMaturityDate;

  /// No description provided for @loanNextDueDate.
  ///
  /// In en, this message translates to:
  /// **'Next Due Date'**
  String get loanNextDueDate;

  /// No description provided for @loanNextInstallmentAmount.
  ///
  /// In en, this message translates to:
  /// **'Next Installment'**
  String get loanNextInstallmentAmount;

  /// No description provided for @loanNumberOfInstallments.
  ///
  /// In en, this message translates to:
  /// **'No. of Installments'**
  String get loanNumberOfInstallments;

  /// No description provided for @loanOpeningDate.
  ///
  /// In en, this message translates to:
  /// **'Opening Date'**
  String get loanOpeningDate;

  /// No description provided for @loanOutstandingAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Outstanding Amount'**
  String get loanOutstandingAmountLabel;

  /// No description provided for @loanRepaymentAmountExceedsOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Amount cannot exceed the outstanding balance.'**
  String get loanRepaymentAmountExceedsOutstanding;

  /// No description provided for @loanRepaymentAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Repayment Amount'**
  String get loanRepaymentAmountLabel;

  /// No description provided for @loanRepaymentAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get loanRepaymentAmountRequired;

  /// No description provided for @loanRepaymentConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Pay'**
  String get loanRepaymentConfirmButton;

  /// No description provided for @loanRepaymentContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Review Repayment'**
  String get loanRepaymentContinueButton;

  /// No description provided for @loanRepaymentDoneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get loanRepaymentDoneButton;

  /// No description provided for @loanRepaymentFromAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Pay From'**
  String get loanRepaymentFromAccountLabel;

  /// No description provided for @loanRepaymentFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get loanRepaymentFromLabel;

  /// No description provided for @loanRepaymentModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Repayment Mode'**
  String get loanRepaymentModeLabel;

  /// No description provided for @loanRepaymentNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'No eligible accounts found for repayment.'**
  String get loanRepaymentNoAccounts;

  /// No description provided for @loanRepaymentOtpAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} attempts left'**
  String loanRepaymentOtpAttemptsLeft(int count);

  /// No description provided for @loanRepaymentOtpEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter the OTP to continue.'**
  String get loanRepaymentOtpEmpty;

  /// No description provided for @loanRepaymentOtpHint.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get loanRepaymentOtpHint;

  /// No description provided for @loanRepaymentOtpIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect OTP. Please try again.'**
  String get loanRepaymentOtpIncorrect;

  /// No description provided for @loanRepaymentOtpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the one-time password sent to you to complete this payment.'**
  String get loanRepaymentOtpSubtitle;

  /// No description provided for @loanRepaymentOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Payment'**
  String get loanRepaymentOtpTitle;

  /// No description provided for @loanRepaymentOtpVerifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify & Pay'**
  String get loanRepaymentOtpVerifyButton;

  /// No description provided for @loanRepaymentReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get loanRepaymentReferenceLabel;

  /// No description provided for @loanRepaymentSelectAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Select settlement account'**
  String get loanRepaymentSelectAccountHint;

  /// No description provided for @loanRepaymentSelectAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select an account to pay from.'**
  String get loanRepaymentSelectAccountRequired;

  /// No description provided for @loanRepaymentSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your repayment has been submitted successfully.'**
  String get loanRepaymentSuccessMessage;

  /// No description provided for @loanRepaymentSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful'**
  String get loanRepaymentSuccessTitle;

  /// No description provided for @loanRepaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Repay Loan'**
  String get loanRepaymentTitle;

  /// No description provided for @loanRepaymentToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get loanRepaymentToLabel;

  /// No description provided for @loanScheduleColumnInterest.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get loanScheduleColumnInterest;

  /// No description provided for @loanScheduleColumnPrincipal.
  ///
  /// In en, this message translates to:
  /// **'Principal'**
  String get loanScheduleColumnPrincipal;

  /// No description provided for @loanScheduleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No repayment schedule available.'**
  String get loanScheduleEmpty;

  /// No description provided for @loanScheduleStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get loanScheduleStatusPaid;

  /// No description provided for @loanScheduleStatusUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get loanScheduleStatusUnpaid;

  /// No description provided for @loanTenure.
  ///
  /// In en, this message translates to:
  /// **'Tenure'**
  String get loanTenure;

  /// No description provided for @menuLoansFinances.
  ///
  /// In en, this message translates to:
  /// **'Loans & Finances'**
  String get menuLoansFinances;

  /// No description provided for @menuCurrentSavings.
  ///
  /// In en, this message translates to:
  /// **'Current & Savings'**
  String get menuCurrentSavings;

  /// No description provided for @menuTermDeposits.
  ///
  /// In en, this message translates to:
  /// **'Term Deposits'**
  String get menuTermDeposits;

  /// No description provided for @menuRecurringDeposits.
  ///
  /// In en, this message translates to:
  /// **'Recurring Deposits'**
  String get menuRecurringDeposits;

  /// No description provided for @repayNow.
  ///
  /// In en, this message translates to:
  /// **'Repay Now'**
  String get repayNow;

  /// No description provided for @errorAccountDetailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load account details. Please try again.'**
  String get errorAccountDetailLoadFailed;

  /// No description provided for @errorTransactionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load transactions. Please try again.'**
  String get errorTransactionsLoadFailed;

  /// No description provided for @casaAccountDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Current & Saving Account Details'**
  String get casaAccountDetailsTitle;

  /// No description provided for @casaAccountDetailsTitleWeb.
  ///
  /// In en, this message translates to:
  /// **'CURRENT & SAVING ACCOUNT DETAILS'**
  String get casaAccountDetailsTitleWeb;

  /// No description provided for @casaAccountNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Account Number'**
  String get casaAccountNumberLabel;

  /// No description provided for @casaCurrentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current Balance'**
  String get casaCurrentBalance;

  /// No description provided for @casaProductName.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get casaProductName;

  /// No description provided for @casaNickName.
  ///
  /// In en, this message translates to:
  /// **'Nick Name'**
  String get casaNickName;

  /// No description provided for @casaNotAssigned.
  ///
  /// In en, this message translates to:
  /// **'Not Assigned'**
  String get casaNotAssigned;

  /// No description provided for @casaNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'Not Registered'**
  String get casaNotRegistered;

  /// No description provided for @casaBalanceDetails.
  ///
  /// In en, this message translates to:
  /// **'Balance Details'**
  String get casaBalanceDetails;

  /// No description provided for @casaTodaysOpeningBalance.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Opening Balance'**
  String get casaTodaysOpeningBalance;

  /// No description provided for @casaAvailableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available Balance'**
  String get casaAvailableBalance;

  /// No description provided for @casaAmountOnHold.
  ///
  /// In en, this message translates to:
  /// **'Amount on Hold'**
  String get casaAmountOnHold;

  /// No description provided for @casaUnderFunds.
  ///
  /// In en, this message translates to:
  /// **'Under Funds'**
  String get casaUnderFunds;

  /// No description provided for @casaAdvanceAgainstUnclearFunds.
  ///
  /// In en, this message translates to:
  /// **'Advance Against Unclear Funds Limit'**
  String get casaAdvanceAgainstUnclearFunds;

  /// No description provided for @casaOverdraftLimit.
  ///
  /// In en, this message translates to:
  /// **'Overdraft Limit'**
  String get casaOverdraftLimit;

  /// No description provided for @casaSweepInAmount.
  ///
  /// In en, this message translates to:
  /// **'Sweep-in Amount'**
  String get casaSweepInAmount;

  /// No description provided for @casaGeneralDetails.
  ///
  /// In en, this message translates to:
  /// **'General Details'**
  String get casaGeneralDetails;

  /// No description provided for @casaHoldingPattern.
  ///
  /// In en, this message translates to:
  /// **'Holding Pattern'**
  String get casaHoldingPattern;

  /// No description provided for @casaPrimaryAccountHolder.
  ///
  /// In en, this message translates to:
  /// **'Primary Account Holder'**
  String get casaPrimaryAccountHolder;

  /// No description provided for @casaNominee.
  ///
  /// In en, this message translates to:
  /// **'Nominee'**
  String get casaNominee;

  /// No description provided for @casaBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get casaBranch;

  /// No description provided for @casaViewTransactions.
  ///
  /// In en, this message translates to:
  /// **'View transactions'**
  String get casaViewTransactions;

  /// No description provided for @casaTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get casaTransactionsTitle;

  /// No description provided for @casaTransactionsTitleWeb.
  ///
  /// In en, this message translates to:
  /// **'TRANSACTIONS'**
  String get casaTransactionsTitleWeb;

  /// No description provided for @casaOpeningBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening Balance'**
  String get casaOpeningBalance;

  /// No description provided for @casaClosingBalance.
  ///
  /// In en, this message translates to:
  /// **'Closing Balance'**
  String get casaClosingBalance;

  /// No description provided for @casaRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get casaRecentTransactions;

  /// No description provided for @casaTransactionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions found.'**
  String get casaTransactionsEmpty;

  /// No description provided for @casaTransactionRef.
  ///
  /// In en, this message translates to:
  /// **'Ref: {reference}'**
  String casaTransactionRef(String reference);

  /// No description provided for @casaDownloadStatement.
  ///
  /// In en, this message translates to:
  /// **'Download statement'**
  String get casaDownloadStatement;

  /// No description provided for @casaStatementDownloadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Statement downloaded.'**
  String get casaStatementDownloadSuccess;

  /// No description provided for @casaStatementDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to download statement. Please try again.'**
  String get casaStatementDownloadFailed;

  /// No description provided for @casaFilterViewOptions.
  ///
  /// In en, this message translates to:
  /// **'View Options'**
  String get casaFilterViewOptions;

  /// No description provided for @casaFilterTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get casaFilterTransactions;

  /// No description provided for @casaFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get casaFilterAll;

  /// No description provided for @casaFilterCreditsOnly.
  ///
  /// In en, this message translates to:
  /// **'Credits Only'**
  String get casaFilterCreditsOnly;

  /// No description provided for @casaFilterDebitsOnly.
  ///
  /// In en, this message translates to:
  /// **'Debits Only'**
  String get casaFilterDebitsOnly;

  /// No description provided for @casaFilterAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get casaFilterAmount;

  /// No description provided for @casaFilterReferenceNumber.
  ///
  /// In en, this message translates to:
  /// **'Reference Number'**
  String get casaFilterReferenceNumber;

  /// No description provided for @casaFilterApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get casaFilterApply;

  /// No description provided for @casaFilterReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get casaFilterReset;

  /// No description provided for @casaViewCurrentMonth.
  ///
  /// In en, this message translates to:
  /// **'Current Month'**
  String get casaViewCurrentMonth;

  /// No description provided for @casaViewCurrentDay.
  ///
  /// In en, this message translates to:
  /// **'Current Day'**
  String get casaViewCurrentDay;

  /// No description provided for @casaViewPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous Day'**
  String get casaViewPreviousDay;

  /// No description provided for @casaViewPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous Month'**
  String get casaViewPreviousMonth;

  /// No description provided for @casaViewCurrentAndPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Current & Previous Month'**
  String get casaViewCurrentAndPreviousMonth;

  /// No description provided for @casaTxnTypeCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get casaTxnTypeCredit;

  /// No description provided for @casaTxnTypeDebit.
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get casaTxnTypeDebit;

  /// No description provided for @casaColTxnDate.
  ///
  /// In en, this message translates to:
  /// **'Transaction Date'**
  String get casaColTxnDate;

  /// No description provided for @casaColValueDate.
  ///
  /// In en, this message translates to:
  /// **'Value Date'**
  String get casaColValueDate;

  /// No description provided for @casaColDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get casaColDescription;

  /// No description provided for @casaColReference.
  ///
  /// In en, this message translates to:
  /// **'Reference Number'**
  String get casaColReference;

  /// No description provided for @casaColType.
  ///
  /// In en, this message translates to:
  /// **'Transaction Type'**
  String get casaColType;

  /// No description provided for @casaColAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get casaColAmount;

  /// No description provided for @casaColBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get casaColBalance;

  /// No description provided for @casaStatementPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Password combination'**
  String get casaStatementPasswordTitle;

  /// No description provided for @casaStatementPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'The downloaded statement is password-protected. The password is the first 4 letters of your name in capitals, followed by your date of birth in DDMM format.'**
  String get casaStatementPasswordBody;

  /// No description provided for @casaStatementPasswordExample1.
  ///
  /// In en, this message translates to:
  /// **'Example: Name Roopa Lal, date of birth 23-12-1980 → ROOP2312.'**
  String get casaStatementPasswordExample1;

  /// No description provided for @casaStatementPasswordExample2.
  ///
  /// In en, this message translates to:
  /// **'If the first name has fewer than 4 letters, remaining letters are taken from the last name. Example: Joy Matthew, 01-01-1980 → JOYM0101.'**
  String get casaStatementPasswordExample2;

  /// No description provided for @casaStatementPasswordContinue.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get casaStatementPasswordContinue;

  /// No description provided for @errorInvalidRequest.
  ///
  /// In en, this message translates to:
  /// **'Invalid request. Please check your input.'**
  String get errorInvalidRequest;

  /// No description provided for @errorOtpInvalid.
  ///
  /// In en, this message translates to:
  /// **'The verification code is incorrect. Please try again.'**
  String get errorOtpInvalid;

  /// No description provided for @errorBiometricAccessPoint.
  ///
  /// In en, this message translates to:
  /// **'Mobile quick access is not enabled for your account on the server. Ask your bank to enable the Mobile App touch point for your user.'**
  String get errorBiometricAccessPoint;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'OTP code verification'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the one-time code sent to your registered mobile number or email.'**
  String get otpSubtitle;

  /// No description provided for @otpSubtitleDetailed.
  ///
  /// In en, this message translates to:
  /// **'Enter the 4-digit code we texted to you at your registered email address {email} or {phone}.'**
  String otpSubtitleDetailed(String email, String phone);

  /// No description provided for @otpCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get otpCodeLabel;

  /// No description provided for @otpCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get otpCodeHint;

  /// No description provided for @otpEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter the verification code'**
  String get otpEnterCode;

  /// No description provided for @otpVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// No description provided for @otpContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get otpContinue;

  /// No description provided for @otpVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get otpVerifying;

  /// No description provided for @otpDidntReceive.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the OTP?'**
  String get otpDidntReceive;

  /// No description provided for @otpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get otpResend;

  /// No description provided for @otpAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attempt remaining} other{{count} attempts remaining}}'**
  String otpAttemptsLeft(int count);

  /// No description provided for @otpResendsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No resends remaining} =1{1 resend remaining} other{{count} resends remaining}}'**
  String otpResendsLeft(int count);

  /// No description provided for @otpResendUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Resend is not available yet. Please try again later.'**
  String get otpResendUnavailable;

  /// No description provided for @otpResendSuccess.
  ///
  /// In en, this message translates to:
  /// **'A new verification code has been sent.'**
  String get otpResendSuccess;

  /// No description provided for @registrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get registrationTitle;

  /// No description provided for @registrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Great! Give us some details about your account, so we can look you up!'**
  String get registrationSubtitle;

  /// No description provided for @registrationFirstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get registrationFirstName;

  /// No description provided for @registrationFirstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get registrationFirstNameRequired;

  /// No description provided for @registrationLastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get registrationLastName;

  /// No description provided for @registrationLastNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get registrationLastNameRequired;

  /// No description provided for @registrationEmail.
  ///
  /// In en, this message translates to:
  /// **'Email Id'**
  String get registrationEmail;

  /// No description provided for @registrationEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email ID'**
  String get registrationEmailHint;

  /// No description provided for @registrationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get registrationEmailRequired;

  /// No description provided for @registrationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Email ID'**
  String get registrationEmailInvalid;

  /// No description provided for @registrationMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get registrationMobile;

  /// No description provided for @registrationMobileHint.
  ///
  /// In en, this message translates to:
  /// **'Enter mobile number'**
  String get registrationMobileHint;

  /// No description provided for @registrationMobileRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your mobile number'**
  String get registrationMobileRequired;

  /// No description provided for @registrationConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get registrationConfirmPassword;

  /// No description provided for @registrationConfirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get registrationConfirmPasswordRequired;

  /// No description provided for @registrationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get registrationPasswordRequired;

  /// No description provided for @registrationPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get registrationPasswordMismatch;

  /// No description provided for @registrationPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get registrationPasswordTooShort;

  /// No description provided for @registrationUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a username'**
  String get registrationUsernameRequired;

  /// No description provided for @registrationSubmit.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get registrationSubmit;

  /// No description provided for @registrationSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Please wait...'**
  String get registrationSubmitting;

  /// No description provided for @registrationBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get registrationBackToLogin;

  /// No description provided for @registrationSuccess.
  ///
  /// In en, this message translates to:
  /// **'User Registered Successfully'**
  String get registrationSuccess;

  /// No description provided for @registrationSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'A link to generate your Username and Password has been sent to your registered email ID.'**
  String get registrationSuccessMessage;

  /// No description provided for @registrationGoToLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get registrationGoToLogin;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get registrationFailed;

  /// No description provided for @registrationAccountType.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get registrationAccountType;

  /// No description provided for @registrationAccountTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Select account type'**
  String get registrationAccountTypeHint;

  /// No description provided for @registrationAccountTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get registrationAccountTypeRequired;

  /// No description provided for @registrationCustomerId.
  ///
  /// In en, this message translates to:
  /// **'Customer Id'**
  String get registrationCustomerId;

  /// No description provided for @registrationCustomerIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter customer ID'**
  String get registrationCustomerIdHint;

  /// No description provided for @registrationCustomerIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get registrationCustomerIdRequired;

  /// No description provided for @registrationRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get registrationRequiredHint;

  /// No description provided for @registrationAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account Number'**
  String get registrationAccountNumber;

  /// No description provided for @registrationAccountNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter account number'**
  String get registrationAccountNumberHint;

  /// No description provided for @registrationAccountNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get registrationAccountNumberRequired;

  /// No description provided for @registrationFirstNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter first name'**
  String get registrationFirstNameHint;

  /// No description provided for @registrationLastNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter last name'**
  String get registrationLastNameHint;

  /// No description provided for @registrationDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get registrationDateOfBirth;

  /// No description provided for @registrationDateOfBirthHint.
  ///
  /// In en, this message translates to:
  /// **'Select date of birth'**
  String get registrationDateOfBirthHint;

  /// No description provided for @registrationDateOfBirthRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get registrationDateOfBirthRequired;

  /// No description provided for @registrationDebitCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Debit Card Number'**
  String get registrationDebitCardNumber;

  /// No description provided for @registrationDebitCardHint.
  ///
  /// In en, this message translates to:
  /// **'Enter debit card number'**
  String get registrationDebitCardHint;

  /// No description provided for @registrationDebitCardRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get registrationDebitCardRequired;

  /// No description provided for @registrationAgreeTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'I agree to '**
  String get registrationAgreeTermsPrefix;

  /// No description provided for @registrationTermsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get registrationTermsAndConditions;

  /// No description provided for @registrationTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'Please accept the Terms and Conditions'**
  String get registrationTermsRequired;

  /// No description provided for @registrationVerificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A verification code has been sent to your email/mobile. Please enter that code below to complete the process'**
  String get registrationVerificationSubtitle;

  /// No description provided for @registrationVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get registrationVerificationCode;

  /// No description provided for @registrationVerificationCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get registrationVerificationCodeRequired;

  /// No description provided for @registrationAttemptsLeftLabel.
  ///
  /// In en, this message translates to:
  /// **'Attempts Left'**
  String get registrationAttemptsLeftLabel;

  /// No description provided for @registrationVerifySubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get registrationVerifySubmit;

  /// No description provided for @registrationDidNotGetCode.
  ///
  /// In en, this message translates to:
  /// **'Did not get the code?'**
  String get registrationDidNotGetCode;

  /// No description provided for @registrationResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get registrationResendCode;

  /// No description provided for @registrationVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Invalid verification code. Please try again.'**
  String get registrationVerificationFailed;

  /// No description provided for @registrationResendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not resend the code. Please try again.'**
  String get registrationResendFailed;

  /// No description provided for @registrationResendSuccess.
  ///
  /// In en, this message translates to:
  /// **'A new verification code has been sent.'**
  String get registrationResendSuccess;

  /// No description provided for @errorUserAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'An account with this username already exists.'**
  String get errorUserAlreadyExists;

  /// No description provided for @biometricUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock UBCI Bank'**
  String get biometricUnlockTitle;

  /// No description provided for @biometricUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint or face to continue'**
  String get biometricUnlockSubtitle;

  /// No description provided for @biometricUsePassword.
  ///
  /// In en, this message translates to:
  /// **'Use password instead'**
  String get biometricUsePassword;

  /// No description provided for @biometricTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get biometricTryAgain;

  /// No description provided for @biometricNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock is not available on this device.'**
  String get biometricNotAvailable;

  /// No description provided for @biometricEnabledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock enabled.'**
  String get biometricEnabledSuccess;

  /// No description provided for @biometricDisabledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock disabled.'**
  String get biometricDisabledSuccess;

  /// No description provided for @biometricEnablePromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable biometric unlock?'**
  String get biometricEnablePromptTitle;

  /// No description provided for @biometricEnablePromptMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in faster on this device using your fingerprint or face. You will still need your password periodically.'**
  String get biometricEnablePromptMessage;

  /// No description provided for @biometricSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up quick access'**
  String get biometricSetupTitle;

  /// No description provided for @biometricSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up an alternate authentication method for faster and secure login'**
  String get biometricSetupSubtitle;

  /// No description provided for @biometricOptionFaceId.
  ///
  /// In en, this message translates to:
  /// **'Face ID'**
  String get biometricOptionFaceId;

  /// No description provided for @biometricOptionPasscode.
  ///
  /// In en, this message translates to:
  /// **'Passcode'**
  String get biometricOptionPasscode;

  /// No description provided for @biometricOptionFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get biometricOptionFingerprint;

  /// No description provided for @biometricEnableLogin.
  ///
  /// In en, this message translates to:
  /// **'Enable biometric login'**
  String get biometricEnableLogin;

  /// No description provided for @biometricEnableLoginHelper.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint or face unlock to log in quickly.'**
  String get biometricEnableLoginHelper;

  /// No description provided for @biometricEnableFaceId.
  ///
  /// In en, this message translates to:
  /// **'Enable Face ID'**
  String get biometricEnableFaceId;

  /// No description provided for @biometricEnableTouchId.
  ///
  /// In en, this message translates to:
  /// **'Enable Touch ID'**
  String get biometricEnableTouchId;

  /// No description provided for @biometricNotEnrolledTitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock not set up'**
  String get biometricNotEnrolledTitle;

  /// No description provided for @biometricOptionPattern.
  ///
  /// In en, this message translates to:
  /// **'Pattern'**
  String get biometricOptionPattern;

  /// No description provided for @biometricOptionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This option will be available in a future update.'**
  String get biometricOptionUnavailable;

  /// No description provided for @biometricSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get biometricSkipForNow;

  /// No description provided for @biometricEnableNow.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get biometricEnableNow;

  /// No description provided for @biometricNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get biometricNotNow;

  /// No description provided for @biometricDisableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Disable biometric unlock on this device?'**
  String get biometricDisableConfirm;

  /// No description provided for @biometricUnlockReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm your identity to access your account'**
  String get biometricUnlockReason;

  /// No description provided for @biometricEnableReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm your identity to enable biometric unlock'**
  String get biometricEnableReason;

  /// No description provided for @biometricCancelled.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication was cancelled. Please try again.'**
  String get biometricCancelled;

  /// No description provided for @biometricNotEnrolled.
  ///
  /// In en, this message translates to:
  /// **'No fingerprint or face is set up on this device. Add one in your phone Settings first.'**
  String get biometricNotEnrolled;

  /// No description provided for @biometricFaceNotEnrolledTitle.
  ///
  /// In en, this message translates to:
  /// **'Face unlock not set up'**
  String get biometricFaceNotEnrolledTitle;

  /// No description provided for @biometricFaceNotEnrolledMessage.
  ///
  /// In en, this message translates to:
  /// **'Face unlock is not enrolled on this device. Open Settings to add Face ID or face unlock, then return and try again.'**
  String get biometricFaceNotEnrolledMessage;

  /// No description provided for @biometricFingerprintNotEnrolledTitle.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint not set up'**
  String get biometricFingerprintNotEnrolledTitle;

  /// No description provided for @biometricFingerprintNotEnrolledMessage.
  ///
  /// In en, this message translates to:
  /// **'No fingerprint is enrolled on this device. Open Settings to add a fingerprint, then return and try again.'**
  String get biometricFingerprintNotEnrolledMessage;

  /// No description provided for @biometricOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get biometricOpenSettings;

  /// No description provided for @biometricAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric verification failed. Please try again.'**
  String get biometricAuthFailed;

  /// No description provided for @biometricTokenInvalidated.
  ///
  /// In en, this message translates to:
  /// **'Biometric login is unavailable right now. Please sign in with your password.'**
  String get biometricTokenInvalidated;

  /// No description provided for @biometricUsePasswordAfterLogout.
  ///
  /// In en, this message translates to:
  /// **'Please sign in with your password. Biometric verification will be asked after login.'**
  String get biometricUsePasswordAfterLogout;

  /// No description provided for @biometricTemporarilyLocked.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock is temporarily locked. Wait a moment and try again.'**
  String get biometricTemporarilyLocked;

  /// No description provided for @passcodeCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create passcode'**
  String get passcodeCreateTitle;

  /// No description provided for @passcodeCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a 6-digit passcode for quick login'**
  String get passcodeCreateSubtitle;

  /// No description provided for @passcodeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm passcode'**
  String get passcodeConfirmTitle;

  /// No description provided for @passcodeConfirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the same passcode again'**
  String get passcodeConfirmSubtitle;

  /// No description provided for @passcodeMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passcodes do not match. Please try again.'**
  String get passcodeMismatch;

  /// No description provided for @passcodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 6-digit passcode.'**
  String get passcodeInvalid;

  /// No description provided for @passcodeIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect passcode. Please try again.'**
  String get passcodeIncorrect;

  /// No description provided for @passcodeUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter passcode'**
  String get passcodeUnlockTitle;

  /// No description provided for @passcodeUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your passcode to continue'**
  String get passcodeUnlockSubtitle;

  /// No description provided for @patternCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create pattern'**
  String get patternCreateTitle;

  /// No description provided for @patternCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect at least 4 dots to create your pattern'**
  String get patternCreateSubtitle;

  /// No description provided for @patternConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm pattern'**
  String get patternConfirmTitle;

  /// No description provided for @patternConfirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Draw the same pattern again'**
  String get patternConfirmSubtitle;

  /// No description provided for @patternMismatch.
  ///
  /// In en, this message translates to:
  /// **'Patterns do not match. Please try again.'**
  String get patternMismatch;

  /// No description provided for @patternUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Draw pattern'**
  String get patternUnlockTitle;

  /// No description provided for @patternUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your pattern to continue'**
  String get patternUnlockSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'en',
        'fr',
        'it',
        'ru',
        'uz'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
