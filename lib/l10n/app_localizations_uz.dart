// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'Demo Bank';

  @override
  String get brandName => 'UBCI';

  @override
  String get welcome => 'Xush kelibsiz!';

  @override
  String get welcomeBack => 'Qaytganingizdan xursandmiz!';

  @override
  String get loginSubtitle =>
      'Tizimga kirish uchun foydalanuvchi nomi va parolni kiriting';

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
  String get username => 'Foydalanuvchi nomi';

  @override
  String get password => 'Parol';

  @override
  String get enterUsername => 'Foydalanuvchi nomini kiriting';

  @override
  String get enterPassword => 'Parolni kiriting';

  @override
  String get forgotPassword => 'Parolni unutdingizmi?';

  @override
  String get forgotUsername => 'Foydalanuvchi nomini unutdingizmi?';

  @override
  String get forgotUsernameTitle => 'Foydalanuvchi nomi unutilgan';

  @override
  String get forgotPasswordTitle => 'Parol unutilgan';

  @override
  String get forgotUsernameSubtitle =>
      'Foydalanuvchi nomini olish uchun bank hisobingizda ro‘yxatdan o‘tgan email va tug‘ilgan sanani kiriting.';

  @override
  String get forgotPasswordSubtitle =>
      'Muammo yo‘q. Quyidagi ma’lumotlarni kiriting.';

  @override
  String get forgotEmailLabel => 'Email';

  @override
  String get forgotEmailHint => 'Enter email';

  @override
  String get forgotEmailRequired => 'Majburiy';

  @override
  String get forgotUserNameLabel => 'Foydalanuvchi nomi';

  @override
  String get forgotUserNameHint => 'Enter username';

  @override
  String get forgotUserNameRequired => 'Majburiy';

  @override
  String get forgotDateOfBirthLabel => 'Tug‘ilgan sana';

  @override
  String get forgotDateOfBirthHint => 'Select date of birth';

  @override
  String get forgotDateOfBirthRequired => 'Majburiy';

  @override
  String get forgotSubmit => 'Yuborish';

  @override
  String get forgotOtpTitle => 'Bir martalik tasdiqlash';

  @override
  String get forgotOtpSubtitle =>
      'Tasdiqlash kodi ro‘yxatdan o‘tgan mobil raqamingizga yuborildi. Jarayonni yakunlash uchun kodni kiriting.';

  @override
  String get forgotNoteHeading => 'Eslatma';

  @override
  String get forgotNoteQuestion => 'Foydalanuvchi nomini eslay olmayapsizmi?';

  @override
  String get forgotNoteBody =>
      'Ro‘yxatdan o‘tgan emailingizni kiriting va tasdiqlang — foydalanuvchi IDsi emailingizga yuboriladi.';

  @override
  String get forgotNoteSupport =>
      'Agar ID ni tiklay olmasangiz, eng yaqin filialga boring yoki mijozlarga xizmat markaziga murojaat qiling.';

  @override
  String get forgotPasswordNoteQuestion => 'Not able to recall your Password?';

  @override
  String get forgotPasswordNoteBody =>
      'Simply enter your User Name and date of birth registered in your bank account to receive a password reset link on your email.';

  @override
  String get forgotPasswordNoteSupport =>
      'In case you are unable to recover your Password, please visit our nearest branch or contact and speak to our customer care executive.';

  @override
  String get forgotSuccessHeading => 'Muvaffaqiyatli';

  @override
  String get forgotUsernameSuccessMessage =>
      'Tiklangan foydalanuvchi nomi ro‘yxatdan o‘tgan emailingizga muvaffaqiyatli yuborildi.';

  @override
  String get forgotPasswordSuccessMessage =>
      'Yangi parol yaratish uchun havola emailingizga muvaffaqiyatli yuborildi';

  @override
  String get forgotGoToLogin => 'Bank hisobingizga kirish';

  @override
  String otpReferenceNumber(String reference) {
    return 'Ma’lumotnoma raqami: $reference';
  }

  @override
  String get login => 'Kirish';

  @override
  String get loggingIn => 'Kirish amalga oshirilmoqda...';

  @override
  String get keepMeSignedIn => 'Keep me signed in';

  @override
  String get loginWithBiometrics => 'Login with biometrics';

  @override
  String get featureComingSoon => 'This feature will be available soon.';

  @override
  String get help => 'Yordam';

  @override
  String get loginHelpTitle => 'Kirishda yordam kerakmi?';

  @override
  String get loginHelpSubtitle => 'Kirish ekrani uchun qisqa maslahatlar';

  @override
  String get loginHelpBody =>
      'Bank hisobingizda ro‘yxatdan o‘tgan foydalanuvchi nomi va parolni kiriting.\n\nFoydalanuvchi nomi yoki parolni unutgan bo‘lsangiz, ularni tiklash uchun kirish formasidagi havolalardan foydalaning.\n\nIshonchli qurilmalarda tizimda qolishingiz mumkin. Vebda xavfsiz kiritish uchun virtual klaviatura belgisidan foydalaning.\n\nQo‘shimcha yordam uchun eng yaqin filialga boring yoki mijozlarga xizmat ko‘rsatish markaziga murojaat qiling.';

  @override
  String get loginHelpClose => 'Tushunarli';

  @override
  String get virtualKeyboard => 'Virtual klaviatura';

  @override
  String get virtualKeyboardDone => 'Tayyor';

  @override
  String get virtualKeyboardSpace => 'Bo‘sh joy';

  @override
  String get virtualKeyboardShuffle => 'Tugmalarni aralashtirish';

  @override
  String get virtualKeyboardClear => 'Tozalash';

  @override
  String get notRegistered => 'Ro\'yxatdan o\'tmaganmisiz? ';

  @override
  String get registerHere => 'Bu yerda ro\'yxatdan o\'ting';

  @override
  String get pleaseEnterCredentials => 'Foydalanuvchi nomi va parolni kiriting';

  @override
  String get overview => 'Umumiy ko\'rinish';

  @override
  String get accounts => 'Hisoblar';

  @override
  String get cards => 'Kartalar';

  @override
  String get deposit => 'Depozit';

  @override
  String get home => 'Bosh sahifa';

  @override
  String get insights => 'Tahlillar';

  @override
  String get rewards => 'Mukofotlar';

  @override
  String get more => 'Ko\'proq';

  @override
  String get transfer => 'O\'tkazma';

  @override
  String get scan => 'Skanerlash';

  @override
  String get scanAndPay => 'Scan & pay';

  @override
  String get payBill => 'To\'lov';

  @override
  String get goodMorning => 'Xayrli tong';

  @override
  String get goodMorningComma => 'Good Morning,';

  @override
  String get totalBalance => 'UMUMIY BALANS';

  @override
  String get moreTitle => 'Ko\'proq';

  @override
  String get theme => 'Mavzu';

  @override
  String get lightTheme => 'Yorug\'';

  @override
  String get darkTheme => 'Qorong\'u';

  @override
  String get language => 'Til';

  @override
  String get english => 'Inglizcha';

  @override
  String get arabic => 'Arabcha';

  @override
  String get french => 'Fransuzcha';

  @override
  String get italian => 'Italyancha';

  @override
  String get uzbek => 'O\'zbekcha';

  @override
  String get russian => 'Ruscha';

  @override
  String get security => 'Xavfsizlik';

  @override
  String get logOut => 'Chiqish';

  @override
  String get forgetDevice => 'Qurilmani unutish';

  @override
  String get logOutConfirm => 'Ushbu qurilmadagi joriy seansdan chiqasizmi?';

  @override
  String get logOutConfirmWithBiometric =>
      'Sign out of this session on this device?\n\nYou will lose biometric login and will need to set it up again after you sign in.';

  @override
  String get forgetDeviceConfirm =>
      'Ushbu qurilmadagi barcha saqlangan seans ma\'lumotlari o\'chirilsinmi? Qayta kirishingiz kerak bo\'ladi.';

  @override
  String get cancel => 'Bekor qilish';

  @override
  String get confirm => 'Tasdiqlash';

  @override
  String get deviceBlockedTitle => 'Qurilma qo\'llab-quvvatlanmaydi';

  @override
  String get deviceBlockedCompromisedMessage =>
      'Xavfsizligingiz uchun bu ilova o\'zgartirilgan yoki xavfli qurilmalarda ishlamaydi. Standart, o\'zgartirilmagan qurilmadan foydalaning.';

  @override
  String get deviceBlockedEmulatorMessage =>
      'Xavfsizligingiz uchun bu ilova ishlab chiqarish versiyalarida emulyator yoki simulyatorda ishlamaydi.';

  @override
  String get deviceBlockedSupport =>
      'Agar bu xato deb hisoblasangiz, bank qo\'llab-quvvatlash markaziga murojaat qiling.';

  @override
  String get deviceSecurityWarnCompromised =>
      'Xavfsizlik ogohlantirishi: bu qurilma o\'zgartirilgan bo\'lishi mumkin. Ehtiyotkorlik bilan davom eting.';

  @override
  String get deviceSecurityWarnEmulator =>
      'Xavfsizlik ogohlantirishi: siz emulyator yoki simulyatordan foydalanmoqdasiz.';

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
      'Xavfsizlik uchun siz tizimdan chiqarildingiz. Qayta kiring.';

  @override
  String get sessionExpiredTitle => 'Sessiya muddati tugadi';

  @override
  String get sessionExpiredSignIn => 'Kirish';

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
      'Hisoblarni yuklab bo‘lmadi. Qayta urinib ko‘ring.';

  @override
  String get accountsEmpty => 'Hisoblar mavjud emas.';

  @override
  String get accountsRetry => 'Qayta urinish';

  @override
  String get accountStatusActive => 'Faol';

  @override
  String get accountStatusDormant => 'Nofaol';

  @override
  String get accountsMultipleCurrencies =>
      'Balanslar valyuta bo‘yicha ko‘rsatiladi';

  @override
  String get availableBalanceLabel => 'Mavjud balans';

  @override
  String get errorLoansLoadFailed =>
      'Kreditlarni yuklab bo‘lmadi. Qayta urinib ko‘ring.';

  @override
  String get loansEmpty => 'Kreditlar mavjud emas.';

  @override
  String get loanTrackerTitle => 'Kredit kuzatuvchi';

  @override
  String get loanTotalBorrowing => 'Jami qarz';

  @override
  String get loanTotalOutstanding => 'Jami qarz qoldig‘i';

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
      'Hisob tafsilotlarini yuklab bo‘lmadi. Qayta urinib ko‘ring.';

  @override
  String get errorTransactionsLoadFailed =>
      'Tranzaksiyalarni yuklab bo‘lmadi. Qayta urinib ko‘ring.';

  @override
  String get casaAccountDetailsTitle => 'Joriy va jamg‘arma hisob tafsilotlari';

  @override
  String get casaAccountDetailsTitleWeb =>
      'JORIY VA JAMG‘ARMA HISOB TAFSILOTLARI';

  @override
  String get casaAccountNumberLabel => 'Hisob raqami';

  @override
  String get casaCurrentBalance => 'Joriy balans';

  @override
  String get casaProductName => 'Mahsulot nomi';

  @override
  String get casaNickName => 'Taxallus';

  @override
  String get casaNotAssigned => 'Tayinlanmagan';

  @override
  String get casaNotRegistered => 'Ro‘yxatdan o‘tmagan';

  @override
  String get casaBalanceDetails => 'Balans tafsilotlari';

  @override
  String get casaTodaysOpeningBalance => 'Bugungi ochilish balansi';

  @override
  String get casaAvailableBalance => 'Mavjud balans';

  @override
  String get casaAmountOnHold => 'Ushtab turilgan summa';

  @override
  String get casaUnderFunds => 'Qayta ishlanayotgan mablag‘';

  @override
  String get casaAdvanceAgainstUnclearFunds =>
      'Aniqlanmagan mablag‘larga avans limiti';

  @override
  String get casaOverdraftLimit => 'Overdraft limiti';

  @override
  String get casaSweepInAmount => 'Sweep-in summasi';

  @override
  String get casaGeneralDetails => 'Umumiy tafsilotlar';

  @override
  String get casaHoldingPattern => 'Egalik shakli';

  @override
  String get casaPrimaryAccountHolder => 'Asosiy hisob egasi';

  @override
  String get casaNominee => 'Nomzod';

  @override
  String get casaBranch => 'Filial';

  @override
  String get casaViewTransactions => 'Tranzaksiyalarni ko‘rish';

  @override
  String get casaTransactionsTitle => 'Tranzaksiyalar';

  @override
  String get casaTransactionsTitleWeb => 'TRANZAKSIYALAR';

  @override
  String get casaOpeningBalance => 'Ochilish balansi';

  @override
  String get casaClosingBalance => 'Yopilish balansi';

  @override
  String get casaRecentTransactions => 'So‘nggi tranzaksiyalar';

  @override
  String get casaTransactionsEmpty => 'Tranzaksiyalar topilmadi.';

  @override
  String casaTransactionRef(String reference) {
    return 'Ref: $reference';
  }

  @override
  String get casaDownloadStatement => 'Hisobotni yuklab olish';

  @override
  String get casaStatementDownloadSuccess => 'Hisobot yuklab olindi.';

  @override
  String get casaStatementDownloadFailed =>
      'Hisobotni yuklab bo‘lmadi. Qayta urinib ko‘ring.';

  @override
  String get casaFilterViewOptions => 'Ko‘rish parametrlari';

  @override
  String get casaFilterTransactions => 'Tranzaksiyalar';

  @override
  String get casaFilterAll => 'Barchasi';

  @override
  String get casaFilterCreditsOnly => 'Faqat kirimlar';

  @override
  String get casaFilterDebitsOnly => 'Faqat chiqimlar';

  @override
  String get casaFilterAmount => 'Summa';

  @override
  String get casaFilterReferenceNumber => 'Ma’lumotnoma raqami';

  @override
  String get casaFilterApply => 'Qo‘llash';

  @override
  String get casaFilterReset => 'Tozalash';

  @override
  String get casaViewCurrentMonth => 'Joriy oy';

  @override
  String get casaViewCurrentDay => 'Joriy kun';

  @override
  String get casaViewPreviousDay => 'Oldingi kun';

  @override
  String get casaViewPreviousMonth => 'Oldingi oy';

  @override
  String get casaViewCurrentAndPreviousMonth => 'Joriy va oldingi oy';

  @override
  String get casaTxnTypeCredit => 'Kirim';

  @override
  String get casaTxnTypeDebit => 'Chiqim';

  @override
  String get casaColTxnDate => 'Tranzaksiya sanasi';

  @override
  String get casaColValueDate => 'Qiymat sanasi';

  @override
  String get casaColDescription => 'Tavsif';

  @override
  String get casaColReference => 'Ma’lumotnoma raqami';

  @override
  String get casaColType => 'Tranzaksiya turi';

  @override
  String get casaColAmount => 'Summa';

  @override
  String get casaColBalance => 'Qoldiq';

  @override
  String get casaStatementPasswordTitle => 'Parol kombinatsiyasi';

  @override
  String get casaStatementPasswordBody =>
      'Yuklab olingan hisobot parol bilan himoyalangan. Parol — ismingizning birinchi 4 harfi (bosh harf) va tug‘ilgan sanangiz DDMM formatida.';

  @override
  String get casaStatementPasswordExample1 =>
      'Misol: ism Roopa Lal, tug‘ilgan sana 23-12-1980 → ROOP2312.';

  @override
  String get casaStatementPasswordExample2 =>
      'Agar ism 4 harfdan qisqa bo‘lsa, qolgan harflar familiyadan olinadi. Misol: Joy Matthew, 01-01-1980 → JOYM0101.';

  @override
  String get casaStatementPasswordContinue => 'Yuklab olish';

  @override
  String get errorInvalidRequest => 'Invalid request. Please check your input.';

  @override
  String get errorOtpInvalid =>
      'The verification code is incorrect. Please try again.';

  @override
  String get errorBiometricAccessPoint =>
      'Hisobingiz uchun mobil tezkor kirish yoqilmagan. Bankdan Mobile App kirish nuqtasini yoqishni so‘rang.';

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
      other: '$count qayta yuborish qoldi',
      one: '1 qayta yuborish qoldi',
      zero: 'Qayta yuborish qolmadi',
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
  String get biometricEnableLogin => 'Biometrik kirishni yoqish';

  @override
  String get biometricEnableLoginHelper =>
      'Tez kirish uchun barmoq izi yoki yuzni ochishdan foydalaning.';

  @override
  String get biometricEnableFaceId => 'Face ID-ni yoqish';

  @override
  String get biometricEnableTouchId => 'Touch ID-ni yoqish';

  @override
  String get biometricNotEnrolledTitle => 'Biometrik ochish sozlanmagan';

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
