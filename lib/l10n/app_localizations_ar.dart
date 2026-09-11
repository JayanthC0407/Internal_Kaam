// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'بنك UBCI';

  @override
  String get brandName => 'UBCI';

  @override
  String get welcome => 'مرحبًا!';

  @override
  String get welcomeBack => 'مرحبًا بعودتك!';

  @override
  String get loginSubtitle =>
      'يرجى إدخال اسم المستخدم وكلمة المرور لتسجيل الدخول';

  @override
  String get loginDesktopHeadline => 'Banking that\nfits your day.';

  @override
  String get loginDesktopSubtitle =>
      'Manage cards, transfers and spending insights from one place - now on desktop.';

  @override
  String get loginCashbackBadge => '2% CASHBACK';

  @override
  String get cashbackPromoTitle => '✨ 2% Cashback';

  @override
  String get loginCashbackDetail =>
      'On all card purchases. Earn up to GBP 52 / month.';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get enterUsername => 'أدخل اسم المستخدم';

  @override
  String get enterPassword => 'أدخل كلمة المرور';

  @override
  String get forgotPassword => 'هل نسيت كلمة المرور؟';

  @override
  String get forgotUsername => 'هل نسيت اسم المستخدم؟';

  @override
  String get forgotUsernameTitle => 'نسيت اسم المستخدم';

  @override
  String get forgotPasswordTitle => 'نسيت كلمة المرور';

  @override
  String get forgotUsernameSubtitle =>
      'لاسترجاع اسم المستخدم، يرجى إدخال عنوان البريد الإلكتروني وتاريخ الميلاد المسجلين في حسابك البنكي.';

  @override
  String get forgotPasswordSubtitle => 'لا مشكلة. فقط أدخل التفاصيل أدناه.';

  @override
  String get forgotEmailLabel => 'البريد الإلكتروني';

  @override
  String get forgotEmailHint => 'Enter email';

  @override
  String get forgotEmailRequired => 'مطلوب';

  @override
  String get forgotUserNameLabel => 'اسم المستخدم';

  @override
  String get forgotUserNameHint => 'Enter username';

  @override
  String get forgotUserNameRequired => 'مطلوب';

  @override
  String get forgotDateOfBirthLabel => 'تاريخ الميلاد';

  @override
  String get forgotDateOfBirthHint => 'Select date of birth';

  @override
  String get forgotDateOfBirthRequired => 'مطلوب';

  @override
  String get forgotSubmit => 'إرسال';

  @override
  String get forgotOtpTitle => 'تحقق لمرة واحدة';

  @override
  String get forgotOtpSubtitle =>
      'تم إرسال رمز التحقق إلى رقم هاتفك المسجل. يرجى إدخال الرمز أدناه لإكمال العملية.';

  @override
  String get forgotNoteHeading => 'ملاحظة';

  @override
  String get forgotNoteQuestion => 'لا تتذكر اسم المستخدم؟';

  @override
  String get forgotNoteBody =>
      'أدخل بريدك الإلكتروني المسجل ووثّق هويتك لاستلام معرّف المستخدم على بريدك.';

  @override
  String get forgotNoteSupport =>
      'إذا تعذر استرجاع معرّف المستخدم، يرجى زيارة أقرب فرع أو التواصل مع خدمة العملاء.';

  @override
  String get forgotPasswordNoteQuestion => 'Not able to recall your Password?';

  @override
  String get forgotPasswordNoteBody =>
      'Simply enter your User Name and date of birth registered in your bank account to receive a password reset link on your email.';

  @override
  String get forgotPasswordNoteSupport =>
      'In case you are unable to recover your Password, please visit our nearest branch or contact and speak to our customer care executive.';

  @override
  String get forgotSuccessHeading => 'نجاح';

  @override
  String get forgotUsernameSuccessMessage =>
      'تم إرسال اسم المستخدم المسترجع بنجاح إلى بريدك الإلكتروني المسجل.';

  @override
  String get forgotPasswordSuccessMessage =>
      'تم إرسال رابط لإنشاء كلمة مرور جديدة إلى بريدك الإلكتروني بنجاح';

  @override
  String get forgotGoToLogin => 'تسجيل الدخول إلى حسابك البنكي';

  @override
  String otpReferenceNumber(String reference) {
    return 'الرقم المرجعي: $reference';
  }

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get loggingIn => 'جارٍ تسجيل الدخول...';

  @override
  String get keepMeSignedIn => 'Keep me signed in';

  @override
  String get loginWithBiometrics => 'Login with biometrics';

  @override
  String get featureComingSoon => 'This feature will be available soon.';

  @override
  String get help => 'مساعدة';

  @override
  String get loginHelpTitle => 'هل تحتاج مساعدة لتسجيل الدخول؟';

  @override
  String get loginHelpSubtitle => 'نصائح سريعة لشاشة تسجيل الدخول';

  @override
  String get loginHelpBody =>
      'أدخل اسم المستخدم وكلمة المرور المسجلين في حسابك المصرفي.\n\nإذا نسيت اسم المستخدم أو كلمة المرور، استخدم الروابط أسفل نموذج تسجيل الدخول لاستعادتهما.\n\nيمكنك البقاء مسجلاً للدخول على الأجهزة الموثوقة. على الويب، استخدم أيقونة لوحة المفاتيح الافتراضية للإدخال الآمن.\n\nلمزيد من المساعدة، يرجى زيارة أقرب فرع أو الاتصال بخدمة العملاء.';

  @override
  String get loginHelpClose => 'حسناً';

  @override
  String get virtualKeyboard => 'لوحة مفاتيح افتراضية';

  @override
  String get virtualKeyboardDone => 'تم';

  @override
  String get virtualKeyboardSpace => 'مسافة';

  @override
  String get virtualKeyboardShuffle => 'خلط المفاتيح';

  @override
  String get virtualKeyboardClear => 'مسح';

  @override
  String get notRegistered => 'غير مسجل؟ ';

  @override
  String get registerHere => 'سجل هنا';

  @override
  String get pleaseEnterCredentials => 'يرجى إدخال اسم المستخدم وكلمة المرور';

  @override
  String get overview => 'نظرة عامة';

  @override
  String get accounts => 'الحسابات';

  @override
  String get cards => 'البطاقات';

  @override
  String get deposit => 'الإيداع';

  @override
  String get home => 'الرئيسية';

  @override
  String get insights => 'التحليلات';

  @override
  String get rewards => 'المكافآت';

  @override
  String get more => 'المزيد';

  @override
  String get transfer => 'تحويل';

  @override
  String get scan => 'مسح';

  @override
  String get scanAndPay => 'Scan & pay';

  @override
  String get payBill => 'دفع فاتورة';

  @override
  String get goodMorning => 'صباح الخير';

  @override
  String get goodMorningComma => 'Good Morning,';

  @override
  String get totalBalance => 'إجمالي الرصيد';

  @override
  String get moreTitle => 'المزيد';

  @override
  String get theme => 'المظهر';

  @override
  String get lightTheme => 'فاتح';

  @override
  String get darkTheme => 'داكن';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'الإنجليزية';

  @override
  String get arabic => 'العربية';

  @override
  String get french => 'الفرنسية';

  @override
  String get italian => 'الإيطالية';

  @override
  String get uzbek => 'الأوزبكية';

  @override
  String get russian => 'الروسية';

  @override
  String get security => 'الأمان';

  @override
  String get logOut => 'تسجيل الخروج';

  @override
  String get forgetDevice => 'نسيان الجهاز';

  @override
  String get logOutConfirm =>
      'هل تريد تسجيل الخروج من هذه الجلسة على هذا الجهاز؟';

  @override
  String get logOutConfirmWithBiometric =>
      'Sign out of this session on this device?\n\nYou will lose biometric login and will need to set it up again after you sign in.';

  @override
  String get forgetDeviceConfirm =>
      'إزالة جميع بيانات الجلسة المحفوظة من هذا الجهاز؟ ستحتاج إلى تسجيل الدخول مرة أخرى.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get confirm => 'تأكيد';

  @override
  String get deviceBlockedTitle => 'الجهاز غير مدعوم';

  @override
  String get deviceBlockedCompromisedMessage =>
      'لحمايتك، لا يمكن تشغيل هذا التطبيق على أجهزة معدّلة أو غير آمنة. يرجى استخدام جهاز قياسي غير معدّل.';

  @override
  String get deviceBlockedEmulatorMessage =>
      'لحمايتك، لا يمكن تشغيل هذا التطبيق على المحاكيات في إصدارات الإنتاج.';

  @override
  String get deviceBlockedSupport =>
      'إذا كنت تعتقد أن هذا خطأ، يرجى التواصل مع مركز دعم البنك.';

  @override
  String get deviceSecurityWarnCompromised =>
      'تحذير أمني: قد يكون هذا الجهاز معدّلاً. تابع بحذر.';

  @override
  String get deviceSecurityWarnEmulator =>
      'تحذير أمني: أنت تستخدم محاكياً أو جهازاً افتراضياً.';

  @override
  String get searchPlaceholder => 'accounts, transactions, beneficiaries...';

  @override
  String get newTransfer => 'New transfer';

  @override
  String get sampleDateLine => 'Friday, April 19';

  @override
  String get incomeThisMonth => 'INCOME THIS MONTH';

  @override
  String get spendingThisMonth => 'SPENDING THIS MONTH';

  @override
  String get availableCredit => 'AVAILABLE CREDIT';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get myCards => 'My Cards';

  @override
  String get viewAll => 'View all';

  @override
  String get cardCredit => 'CREDIT';

  @override
  String get cardDebit => 'DEBIT';

  @override
  String get badgeBillIsLate => 'BILL IS LATE';

  @override
  String get badgeActive => 'ACTIVE';

  @override
  String get payNow => 'Pay now';

  @override
  String get manage => 'Manage';

  @override
  String get mySpendings => 'My Spendings';

  @override
  String get mySpendingsLower => 'My spendings';

  @override
  String get julySpendings => 'July Spendings';

  @override
  String get julySpendingsLower => 'July spendings';

  @override
  String get upcomingActions => 'Upcoming actions';

  @override
  String get actionCompleteProfile => 'Complete your profile';

  @override
  String get actionPayCreditCardBill => 'Pay credit card bill';

  @override
  String get actionVerifyPhone => 'Verify phone number';

  @override
  String get actionEnableBiometrics => 'Enable biometrics';

  @override
  String get subtitleDueMar15 => 'Due Mar 15';

  @override
  String get subtitleForSecureLogin => 'For secure login';

  @override
  String get subtitleSkipPassword => 'Skip the password';

  @override
  String get complete => 'Complete';

  @override
  String get verify => 'Verify';

  @override
  String get enable => 'Enable';

  @override
  String get topSpending => 'Top Spending';

  @override
  String get topSpendingLower => 'Top spending';

  @override
  String get recentTransactions => 'Recent transactions';

  @override
  String get filter => 'Filter';

  @override
  String get export => 'Export';

  @override
  String get offerPromo => 'On all card spends  •  Earned GBP 82 this month ↑';

  @override
  String get activateOffer => 'Activate offer ›';

  @override
  String get visa => 'VISA';

  @override
  String visaMasked(String tail) {
    return 'VISA •••• $tail';
  }

  @override
  String totalAmount(String amount) {
    return 'Total $amount';
  }

  @override
  String cardTailMasked(String tail) {
    return '•••• $tail';
  }

  @override
  String get recharge => 'Recharge';

  @override
  String get wallet => 'Wallet';

  @override
  String get savings => 'Savings';

  @override
  String get send => 'Send';

  @override
  String get request => 'Request';

  @override
  String get credit => 'Credit';

  @override
  String get maskedCardNumber => 'XXXX XXXX 7689';

  @override
  String get primaryAccountHint => '•••••••••• 7889 · Primary account';

  @override
  String get categoryTechnology => 'Technology';

  @override
  String get categoryFoodDining => 'Food & Dining';

  @override
  String get categoryHealthcare => 'Healthcare';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryTransportation => 'Transportation';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categoryUtilities => 'Utilities';

  @override
  String get categorySalary => 'Salary';

  @override
  String get transactionSuccess => 'Success';

  @override
  String get transactionPending => 'Pending';

  @override
  String get incomingTransfer => 'Incoming transfer';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get tableDescription => 'DESCRIPTION';

  @override
  String get tableCategory => 'CATEGORY';

  @override
  String get tableDate => 'DATE';

  @override
  String get tableAmount => 'AMOUNT';

  @override
  String get tableStatus => 'STATUS';

  @override
  String get showApiTrace => 'Show API Trace';

  @override
  String get errorLoginFailed => 'Login failed';

  @override
  String get errorNetwork =>
      'Unable to connect. Please check your internet connection and try again.';

  @override
  String get errorUnexpected =>
      'An unexpected error occurred. Please try again.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorInvalidCredentials => 'Invalid username or password.';

  @override
  String get errorAccountLocked =>
      'Your account is locked. Please contact the bank.';

  @override
  String get errorPasswordExpired =>
      'Your password has expired. Please reset your password.';

  @override
  String get errorTooManyAttempts =>
      'Too many failed attempts. Please try again later.';

  @override
  String get errorSessionExpired =>
      'لأمانك، تم تسجيل خروجك. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get sessionExpiredTitle => 'انتهت الجلسة';

  @override
  String get sessionExpiredSignIn => 'تسجيل الدخول';

  @override
  String get errorTimeout =>
      'The banking service is not responding. Please try again later.';

  @override
  String get errorBadCertificate =>
      'Secure connection could not be verified. Please update the app or try again later.';

  @override
  String get errorCancelled => 'Request was cancelled.';

  @override
  String get errorAuthFailed => 'Authentication failed. Please sign in again.';

  @override
  String get errorForbidden =>
      'You do not have permission to perform this action.';

  @override
  String get errorNotFound => 'The requested resource was not found.';

  @override
  String get errorServerUnavailable =>
      'Service is temporarily unavailable. Please try again later.';

  @override
  String get errorApiNotConfigured =>
      'API host is not configured for this build. Run ./scripts/sync_ide_config.sh, then fully restart the app.';

  @override
  String get errorAccountsLoadFailed =>
      'تعذر تحميل الحسابات. يرجى المحاولة مرة أخرى.';

  @override
  String get accountsEmpty => 'لا توجد حسابات متاحة.';

  @override
  String get accountsRetry => 'إعادة المحاولة';

  @override
  String get accountStatusActive => 'نشط';

  @override
  String get accountStatusDormant => 'خامل';

  @override
  String get accountsMultipleCurrencies => 'تُعرض الأرصدة حسب العملة';

  @override
  String get availableBalanceLabel => 'الرصيد المتاح';

  @override
  String get errorLoansLoadFailed =>
      'تعذر تحميل القروض. يرجى المحاولة مرة أخرى.';

  @override
  String get loansEmpty => 'لا توجد قروض متاحة.';

  @override
  String get loanTrackerTitle => 'متتبع القروض';

  @override
  String get loanTotalBorrowing => 'إجمالي الاقتراض';

  @override
  String get loanTotalOutstanding => 'إجمالي المستحق';

  @override
  String get errorLoanDetailsLoadFailed =>
      'Unable to load loan details. Please try again.';

  @override
  String get errorLoanDisbursementsLoadFailed =>
      'Unable to load disbursement details. Please try again.';

  @override
  String get errorLoanOutstandingLoadFailed =>
      'Unable to load outstanding balance. Please try again.';

  @override
  String get errorLoanRepaymentFailed =>
      'Unable to process repayment. Please try again.';

  @override
  String get errorLoanScheduleLoadFailed =>
      'Unable to load repayment schedule. Please try again.';

  @override
  String get loanApprovedAmount => 'Approved Amount';

  @override
  String get loanBranchLabel => 'Branch';

  @override
  String get loanDetailsTabDisbursements => 'Disbursements';

  @override
  String get loanDetailsTabOverview => 'Overview';

  @override
  String get loanDetailsTabSchedule => 'Schedule';

  @override
  String get loanDisbursedAmount => 'Disbursed Amount';

  @override
  String get loanDisbursementDateLabel => 'Date';

  @override
  String get loanDisbursementsEmpty => 'No disbursement records available.';

  @override
  String get loanInstallmentsDue => 'Installments Due';

  @override
  String get loanInstallmentsPaid => 'Installments Paid';

  @override
  String get loanInterestRateLabel => 'Interest Rate';

  @override
  String get loanMaturityDate => 'Maturity Date';

  @override
  String get loanNextDueDate => 'Next Due Date';

  @override
  String get loanNextInstallmentAmount => 'Next Installment';

  @override
  String get loanNumberOfInstallments => 'No. of Installments';

  @override
  String get loanOpeningDate => 'Opening Date';

  @override
  String get loanOutstandingAmountLabel => 'Outstanding Amount';

  @override
  String get loanRepaymentAmountExceedsOutstanding =>
      'Amount cannot exceed the outstanding balance.';

  @override
  String get loanRepaymentAmountLabel => 'Repayment Amount';

  @override
  String get loanRepaymentAmountRequired => 'Enter a valid amount.';

  @override
  String get loanRepaymentConfirmButton => 'Confirm & Pay';

  @override
  String get loanRepaymentContinueButton => 'Review Repayment';

  @override
  String get loanRepaymentDoneButton => 'Done';

  @override
  String get loanRepaymentFromAccountLabel => 'Pay From';

  @override
  String get loanRepaymentFromLabel => 'From';

  @override
  String get loanRepaymentModeLabel => 'Repayment Mode';

  @override
  String get loanRepaymentNoAccounts =>
      'No eligible accounts found for repayment.';

  @override
  String loanRepaymentOtpAttemptsLeft(int count) {
    return '$count attempts left';
  }

  @override
  String get loanRepaymentOtpEmpty => 'Enter the OTP to continue.';

  @override
  String get loanRepaymentOtpHint => 'Enter OTP';

  @override
  String get loanRepaymentOtpIncorrect => 'Incorrect OTP. Please try again.';

  @override
  String get loanRepaymentOtpSubtitle =>
      'Enter the one-time password sent to you to complete this payment.';

  @override
  String get loanRepaymentOtpTitle => 'Verify Payment';

  @override
  String get loanRepaymentOtpVerifyButton => 'Verify & Pay';

  @override
  String get loanRepaymentReferenceLabel => 'Reference';

  @override
  String get loanRepaymentSelectAccountHint => 'Select settlement account';

  @override
  String get loanRepaymentSelectAccountRequired =>
      'Please select an account to pay from.';

  @override
  String get loanRepaymentSuccessMessage =>
      'Your repayment has been submitted successfully.';

  @override
  String get loanRepaymentSuccessTitle => 'Payment Successful';

  @override
  String get loanRepaymentTitle => 'Repay Loan';

  @override
  String get loanRepaymentToLabel => 'To';

  @override
  String get loanScheduleColumnInterest => 'Interest';

  @override
  String get loanScheduleColumnPrincipal => 'Principal';

  @override
  String get loanScheduleEmpty => 'No repayment schedule available.';

  @override
  String get loanScheduleStatusPaid => 'Paid';

  @override
  String get loanScheduleStatusUnpaid => 'Unpaid';

  @override
  String get loanTenure => 'Tenure';

  @override
  String get menuLoansFinances => 'Loans & Finances';

  @override
  String get menuCurrentSavings => 'Current & Savings';

  @override
  String get menuTermDeposits => 'Term Deposits';

  @override
  String get menuRecurringDeposits => 'Recurring Deposits';

  @override
  String get repayNow => 'Repay Now';

  @override
  String get errorAccountDetailLoadFailed =>
      'تعذر تحميل تفاصيل الحساب. يرجى المحاولة مرة أخرى.';

  @override
  String get errorTransactionsLoadFailed =>
      'تعذر تحميل المعاملات. يرجى المحاولة مرة أخرى.';

  @override
  String get casaAccountDetailsTitle => 'تفاصيل الحساب الجاري والتوفير';

  @override
  String get casaAccountDetailsTitleWeb => 'تفاصيل الحساب الجاري والتوفير';

  @override
  String get casaAccountNumberLabel => 'رقم الحساب';

  @override
  String get casaCurrentBalance => 'الرصيد الحالي';

  @override
  String get casaProductName => 'اسم المنتج';

  @override
  String get casaNickName => 'الاسم المستعار';

  @override
  String get casaNotAssigned => 'غير معيّن';

  @override
  String get casaNotRegistered => 'غير مسجّل';

  @override
  String get casaBalanceDetails => 'تفاصيل الرصيد';

  @override
  String get casaTodaysOpeningBalance => 'رصيد الافتتاح اليوم';

  @override
  String get casaAvailableBalance => 'الرصيد المتاح';

  @override
  String get casaAmountOnHold => 'المبلغ المحتجز';

  @override
  String get casaUnderFunds => 'أموال قيد المعالجة';

  @override
  String get casaAdvanceAgainstUnclearFunds =>
      'حد السلفة مقابل الأموال غير المقاصة';

  @override
  String get casaOverdraftLimit => 'حد السحب على المكشوف';

  @override
  String get casaSweepInAmount => 'مبلغ التحويل التلقائي';

  @override
  String get casaGeneralDetails => 'تفاصيل عامة';

  @override
  String get casaHoldingPattern => 'نمط الملكية';

  @override
  String get casaPrimaryAccountHolder => 'صاحب الحساب الرئيسي';

  @override
  String get casaNominee => 'المرشّح';

  @override
  String get casaBranch => 'الفرع';

  @override
  String get casaViewTransactions => 'عرض المعاملات';

  @override
  String get casaTransactionsTitle => 'المعاملات';

  @override
  String get casaTransactionsTitleWeb => 'المعاملات';

  @override
  String get casaOpeningBalance => 'رصيد الافتتاح';

  @override
  String get casaClosingBalance => 'رصيد الإغلاق';

  @override
  String get casaRecentTransactions => 'المعاملات الأخيرة';

  @override
  String get casaTransactionsEmpty => 'لم يتم العثور على معاملات.';

  @override
  String casaTransactionRef(String reference) {
    return 'المرجع: $reference';
  }

  @override
  String get casaDownloadStatement => 'تنزيل كشف الحساب';

  @override
  String get casaStatementDownloadSuccess => 'تم تنزيل كشف الحساب.';

  @override
  String get casaStatementDownloadFailed =>
      'تعذر تنزيل كشف الحساب. يرجى المحاولة مرة أخرى.';

  @override
  String get casaFilterViewOptions => 'خيارات العرض';

  @override
  String get casaFilterTransactions => 'المعاملات';

  @override
  String get casaFilterAll => 'الكل';

  @override
  String get casaFilterCreditsOnly => 'الدائن فقط';

  @override
  String get casaFilterDebitsOnly => 'المدين فقط';

  @override
  String get casaFilterAmount => 'المبلغ';

  @override
  String get casaFilterFromAmount => 'من مبلغ';

  @override
  String get casaFilterToAmount => 'إلى مبلغ';

  @override
  String get casaFilterDate => 'التاريخ';

  @override
  String get casaFilterFromDate => 'من تاريخ';

  @override
  String get casaFilterToDate => 'إلى تاريخ';

  @override
  String get casaFilterReferenceNumber => 'رقم المرجع';

  @override
  String get casaFilterApply => 'تطبيق';

  @override
  String get casaFilterReset => 'إعادة تعيين';

  @override
  String get casaViewCurrentMonth => 'الشهر الحالي';

  @override
  String get casaViewCurrentDay => 'اليوم الحالي';

  @override
  String get casaViewPreviousDay => 'اليوم السابق';

  @override
  String get casaViewDateRange => 'نطاق تاريخ';

  @override
  String get casaViewSpecificDay => 'يوم محدد';

  @override
  String get casaViewPreviousMonth => 'الشهر السابق';

  @override
  String get casaViewPreviousQuarter => 'الربع السابق';

  @override
  String get casaViewLast10 => 'آخر 10 معاملات';

  @override
  String get casaViewCurrentAndPreviousMonth => 'الشهر الحالي والسابق';

  @override
  String get casaTxnTypeCredit => 'دائن';

  @override
  String get casaTxnTypeDebit => 'مدين';

  @override
  String get casaColTxnDate => 'تاريخ المعاملة';

  @override
  String get casaColValueDate => 'تاريخ القيمة';

  @override
  String get casaColDescription => 'الوصف';

  @override
  String get casaColReference => 'رقم المرجع';

  @override
  String get casaColType => 'نوع المعاملة';

  @override
  String get casaColAmount => 'المبلغ';

  @override
  String get casaColBalance => 'الرصيد';

  @override
  String get casaStatementPasswordTitle => 'تركيبة كلمة المرور';

  @override
  String get casaStatementPasswordBody =>
      'كشف الحساب المحمّل محمي بكلمة مرور. كلمة المرور هي أول 4 أحرف من اسمك بأحرف كبيرة متبوعة بتاريخ ميلادك بصيغة DDMM.';

  @override
  String get casaStatementPasswordExample1 =>
      'مثال: الاسم Roopa Lal وتاريخ الميلاد 23-12-1980 ← ROOP2312.';

  @override
  String get casaStatementPasswordExample2 =>
      'إذا كان الاسم الأول أقل من 4 أحرف، تُؤخذ الأحرف المتبقية من اسم العائلة. مثال: Joy Matthew في 01-01-1980 ← JOYM0101.';

  @override
  String get casaStatementPasswordContinue => 'تنزيل';

  @override
  String get errorInvalidRequest => 'Invalid request. Please check your input.';

  @override
  String get errorOtpInvalid =>
      'The verification code is incorrect. Please try again.';

  @override
  String get errorBiometricAccessPoint =>
      'الوصول السريع عبر الجوال غير مفعّل لحسابك. اطلب من البنك تفعيل نقطة وصول تطبيق الجوال.';

  @override
  String get otpTitle => 'OTP code verification';

  @override
  String get otpSubtitle =>
      'Enter the one-time code sent to your registered mobile number or email.';

  @override
  String otpSubtitleDetailed(String email, String phone) {
    return 'Enter the 4-digit code we texted to you at your registered email address $email or $phone.';
  }

  @override
  String get otpCodeLabel => 'Verification code';

  @override
  String get otpCodeHint => 'Enter code';

  @override
  String get otpEnterCode => 'Please enter the verification code';

  @override
  String get otpVerify => 'Verify';

  @override
  String get otpContinue => 'Continue';

  @override
  String get otpVerifying => 'Verifying...';

  @override
  String get otpDidntReceive => 'Didn\'t receive the OTP?';

  @override
  String get otpResend => 'Resend';

  @override
  String otpAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts remaining',
      one: '1 attempt remaining',
    );
    return '$_temp0';
  }

  @override
  String otpResendsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إعادات إرسال متبقية',
      one: 'إعادة إرسال واحدةحدة متبقية',
      zero: 'لا توجد إعادة إرسال متبقية',
    );
    return '$_temp0';
  }

  @override
  String get otpResendUnavailable =>
      'Resend is not available yet. Please try again later.';

  @override
  String get otpResendSuccess => 'A new verification code has been sent.';

  @override
  String get registrationTitle => 'Registration';

  @override
  String get registrationSubtitle =>
      'Great! Give us some details about your account, so we can look you up!';

  @override
  String get registrationFirstName => 'First Name';

  @override
  String get registrationFirstNameRequired => 'Required';

  @override
  String get registrationLastName => 'Last Name';

  @override
  String get registrationLastNameRequired => 'Required';

  @override
  String get registrationEmail => 'Email Id';

  @override
  String get registrationEmailHint => 'Please enter your email ID';

  @override
  String get registrationEmailRequired => 'Required';

  @override
  String get registrationEmailInvalid => 'Enter a valid Email ID';

  @override
  String get registrationMobile => 'Mobile number';

  @override
  String get registrationMobileHint => 'Enter mobile number';

  @override
  String get registrationMobileRequired => 'Please enter your mobile number';

  @override
  String get registrationConfirmPassword => 'Confirm password';

  @override
  String get registrationConfirmPasswordRequired =>
      'Please confirm your password';

  @override
  String get registrationPasswordRequired => 'Please enter a password';

  @override
  String get registrationPasswordMismatch => 'Passwords do not match';

  @override
  String get registrationPasswordTooShort =>
      'Password must be at least 8 characters';

  @override
  String get registrationUsernameRequired => 'Please enter a username';

  @override
  String get registrationSubmit => 'Continue';

  @override
  String get registrationSubmitting => 'Please wait...';

  @override
  String get registrationBackToLogin => 'Cancel';

  @override
  String get registrationSuccess => 'User Registered Successfully';

  @override
  String get registrationSuccessMessage =>
      'A link to generate your Username and Password has been sent to your registered email ID.';

  @override
  String get registrationGoToLogin => 'Login';

  @override
  String get registrationFailed => 'Registration failed. Please try again.';

  @override
  String get registrationAccountType => 'Account Type';

  @override
  String get registrationAccountTypeHint => 'Select account type';

  @override
  String get registrationAccountTypeRequired => 'Required';

  @override
  String get registrationCustomerId => 'Customer Id';

  @override
  String get registrationCustomerIdHint => 'Enter customer ID';

  @override
  String get registrationCustomerIdRequired => 'Required';

  @override
  String get registrationRequiredHint => 'Required';

  @override
  String get registrationAccountNumber => 'Account Number';

  @override
  String get registrationAccountNumberHint => 'Enter account number';

  @override
  String get registrationAccountNumberRequired => 'Required';

  @override
  String get registrationFirstNameHint => 'Enter first name';

  @override
  String get registrationLastNameHint => 'Enter last name';

  @override
  String get registrationDateOfBirth => 'Date of Birth';

  @override
  String get registrationDateOfBirthHint => 'Select date of birth';

  @override
  String get registrationDateOfBirthRequired => 'Required';

  @override
  String get registrationDebitCardNumber => 'Debit Card Number';

  @override
  String get registrationDebitCardHint => 'Enter debit card number';

  @override
  String get registrationDebitCardRequired => 'Required';

  @override
  String get registrationAgreeTermsPrefix => 'I agree to ';

  @override
  String get registrationTermsAndConditions => 'Terms and Conditions';

  @override
  String get registrationTermsRequired =>
      'Please accept the Terms and Conditions';

  @override
  String get registrationVerificationSubtitle =>
      'A verification code has been sent to your email/mobile. Please enter that code below to complete the process';

  @override
  String get registrationVerificationCode => 'Verification Code';

  @override
  String get registrationVerificationCodeRequired => 'Required';

  @override
  String get registrationAttemptsLeftLabel => 'Attempts Left';

  @override
  String get registrationVerifySubmit => 'Submit';

  @override
  String get registrationDidNotGetCode => 'Did not get the code?';

  @override
  String get registrationResendCode => 'Resend Code';

  @override
  String get registrationVerificationFailed =>
      'Invalid verification code. Please try again.';

  @override
  String get registrationResendFailed =>
      'Could not resend the code. Please try again.';

  @override
  String get registrationResendSuccess =>
      'A new verification code has been sent.';

  @override
  String get registrationCredentialsTitle => 'Create your credentials';

  @override
  String get registrationCredentialsSubtitle =>
      'Choose a username and password to sign in to your account from now on.';

  @override
  String get registrationUsername => 'Username';

  @override
  String get registrationUsernameHint => 'Choose a username';

  @override
  String get registrationUsernameInvalid =>
      'Use 6-50 letters, numbers, or . _ -, starting with a letter or number';

  @override
  String get registrationPassword => 'Password';

  @override
  String get registrationPasswordHint => 'Create a password';

  @override
  String get registrationConfirmPasswordHint => 'Re-enter your password';

  @override
  String get registrationPasswordPolicyTitle => 'Your password must have:';

  @override
  String get registrationPasswordRuleMinLength => '8-20 characters';

  @override
  String get registrationPasswordRuleUppercase => 'An uppercase letter';

  @override
  String get registrationPasswordRuleLowercase => 'A lowercase letter';

  @override
  String get registrationPasswordRuleNumber => 'A number';

  @override
  String get registrationPasswordRuleSpecialChar => 'A special character';

  @override
  String get registrationPasswordRuleNoUsername =>
      'Does not contain your username';

  @override
  String get registrationCredentialsSubmit => 'Create Account';

  @override
  String get registrationCredentialsSubmitting => 'Creating your account...';

  @override
  String get registrationCredentialsFailed =>
      'Could not create your credentials. Please try again.';

  @override
  String get errorUserAlreadyExists =>
      'An account with this username already exists.';

  @override
  String get biometricUnlockTitle => 'Unlock UBCI Bank';

  @override
  String get biometricUnlockSubtitle =>
      'Use your fingerprint or face to continue';

  @override
  String get biometricUsePassword => 'Use password instead';

  @override
  String get biometricTryAgain => 'Try again';

  @override
  String get biometricNotAvailable =>
      'Biometric unlock is not available on this device.';

  @override
  String get biometricEnabledSuccess => 'Biometric unlock enabled.';

  @override
  String get biometricDisabledSuccess => 'Biometric unlock disabled.';

  @override
  String get biometricEnablePromptTitle => 'Enable biometric unlock?';

  @override
  String get biometricEnablePromptMessage =>
      'Sign in faster on this device using your fingerprint or face. You will still need your password periodically.';

  @override
  String get biometricSetupTitle => 'Set up quick access';

  @override
  String get biometricSetupSubtitle =>
      'Set up an alternate authentication method for faster and secure login';

  @override
  String get biometricOptionFaceId => 'Face ID';

  @override
  String get biometricOptionPasscode => 'Passcode';

  @override
  String get biometricOptionFingerprint => 'Fingerprint';

  @override
  String get biometricEnableLogin => 'تفعيل تسجيل الدخول البيومتري';

  @override
  String get biometricEnableLoginHelper =>
      'استخدم بصمة الإصبع أو فتح الوجه لتسجيل الدخول بسرعة.';

  @override
  String get biometricEnableFaceId => 'تفعيل Face ID';

  @override
  String get biometricEnableTouchId => 'تفعيل Touch ID';

  @override
  String get biometricNotEnrolledTitle => 'لم يتم إعداد فتح القفل البيومتري';

  @override
  String get biometricOptionPattern => 'Pattern';

  @override
  String get biometricOptionUnavailable =>
      'This option will be available in a future update.';

  @override
  String get biometricSkipForNow => 'Skip for now';

  @override
  String get biometricEnableNow => 'Enable';

  @override
  String get biometricNotNow => 'Not now';

  @override
  String get biometricDisableConfirm =>
      'Disable biometric unlock on this device?';

  @override
  String get biometricUnlockReason =>
      'Confirm your identity to access your account';

  @override
  String get biometricEnableReason =>
      'Confirm your identity to enable biometric unlock';

  @override
  String get biometricCancelled =>
      'Biometric authentication was cancelled. Please try again.';

  @override
  String get biometricNotEnrolled =>
      'No fingerprint or face is set up on this device. Add one in your phone Settings first.';

  @override
  String get biometricFaceNotEnrolledTitle => 'Face unlock not set up';

  @override
  String get biometricFaceNotEnrolledMessage =>
      'Face unlock is not enrolled on this device. Open Settings to add Face ID or face unlock, then return and try again.';

  @override
  String get biometricFingerprintNotEnrolledTitle => 'Fingerprint not set up';

  @override
  String get biometricFingerprintNotEnrolledMessage =>
      'No fingerprint is enrolled on this device. Open Settings to add a fingerprint, then return and try again.';

  @override
  String get biometricOpenSettings => 'Open Settings';

  @override
  String get biometricAuthFailed =>
      'Biometric verification failed. Please try again.';

  @override
  String get biometricTokenInvalidated =>
      'Biometric login is unavailable right now. Please sign in with your password.';

  @override
  String get biometricUsePasswordAfterLogout =>
      'Please sign in with your password. Biometric verification will be asked after login.';

  @override
  String get biometricTemporarilyLocked =>
      'Biometric unlock is temporarily locked. Wait a moment and try again.';

  @override
  String get passcodeCreateTitle => 'Create passcode';

  @override
  String get passcodeCreateSubtitle =>
      'Choose a 6-digit passcode for quick login';

  @override
  String get passcodeConfirmTitle => 'Confirm passcode';

  @override
  String get passcodeConfirmSubtitle => 'Enter the same passcode again';

  @override
  String get passcodeMismatch => 'Passcodes do not match. Please try again.';

  @override
  String get passcodeInvalid => 'Enter a valid 6-digit passcode.';

  @override
  String get passcodeIncorrect => 'Incorrect passcode. Please try again.';

  @override
  String get passcodeUnlockTitle => 'Enter passcode';

  @override
  String get passcodeUnlockSubtitle => 'Use your passcode to continue';

  @override
  String get patternCreateTitle => 'Create pattern';

  @override
  String get patternCreateSubtitle =>
      'Connect at least 4 dots to create your pattern';

  @override
  String get patternConfirmTitle => 'Confirm pattern';

  @override
  String get patternConfirmSubtitle => 'Draw the same pattern again';

  @override
  String get patternMismatch => 'Patterns do not match. Please try again.';

  @override
  String get patternUnlockTitle => 'Draw pattern';

  @override
  String get patternUnlockSubtitle => 'Use your pattern to continue';

  @override
  String get accountCategoryCurrentSavings => 'Current and Savings';

  @override
  String get accountCategoryLoans => 'Loans';

  @override
  String get accountCategoryTermDeposits => 'Term Deposits';

  @override
  String get accountCategoryRecurringDeposits => 'Recurring Deposits';

  @override
  String get accountCategoryCreditCards => 'Credit Cards';

  @override
  String get accountCategoryComingSoon =>
      'This account type isn\'t available here yet.';

  @override
  String get selectAccountTitle => 'Select account';

  @override
  String get casaStatementFormatTitle => 'Choose a format';
}
