// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Demo Bank';

  @override
  String get brandName => 'Demo';

  @override
  String get welcome => 'Welcome!';

  @override
  String get welcomeBack => 'Welcome Back!';

  @override
  String get loginSubtitle =>
      'Please enter your username and password to login';

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
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get enterUsername => 'Enter username';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotUsername => 'Forgot username?';

  @override
  String get forgotUsernameTitle => 'Forgot Username';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotUsernameSubtitle =>
      'To retrieve your Username, please enter your email address and date of birth registered in your bank account.';

  @override
  String get forgotPasswordSubtitle =>
      'Okay, no problem. Just enter the details below.';

  @override
  String get forgotEmailLabel => 'Email';

  @override
  String get forgotEmailHint => 'Enter email';

  @override
  String get forgotEmailRequired => 'Required';

  @override
  String get forgotUserNameLabel => 'User Name';

  @override
  String get forgotUserNameHint => 'Enter username';

  @override
  String get forgotUserNameRequired => 'Required';

  @override
  String get forgotDateOfBirthLabel => 'Date Of Birth';

  @override
  String get forgotDateOfBirthHint => 'Select date of birth';

  @override
  String get forgotDateOfBirthRequired => 'Required';

  @override
  String get forgotSubmit => 'Submit';

  @override
  String get forgotOtpTitle => 'One Time Verification';

  @override
  String get forgotOtpSubtitle =>
      'A verification code has been sent to your registered mobile number. Please enter that code below to complete the process.';

  @override
  String get forgotNoteHeading => 'Note';

  @override
  String get forgotNoteQuestion => 'Not able to recall your User Name?';

  @override
  String get forgotNoteBody =>
      'Simply enter your registered email ID and authenticate yourself to receive your User ID on your email.';

  @override
  String get forgotNoteSupport =>
      'In case you are unable to recover your User ID, please visit our nearest branch or contact and speak to our customer care executive.';

  @override
  String get forgotPasswordNoteQuestion => 'Not able to recall your Password?';

  @override
  String get forgotPasswordNoteBody =>
      'Simply enter your User Name and date of birth registered in your bank account to receive a password reset link on your email.';

  @override
  String get forgotPasswordNoteSupport =>
      'In case you are unable to recover your Password, please visit our nearest branch or contact and speak to our customer care executive.';

  @override
  String get forgotSuccessHeading => 'Success';

  @override
  String get forgotUsernameSuccessMessage =>
      'The retrieved Username has been successfully sent to your registered email.';

  @override
  String get forgotPasswordSuccessMessage =>
      'Link to generate a new password has been successfully sent on your email';

  @override
  String get forgotGoToLogin => 'Login to your bank account';

  @override
  String otpReferenceNumber(String reference) {
    return 'Reference Number: $reference';
  }

  @override
  String get login => 'Login';

  @override
  String get loggingIn => 'Logging in...';

  @override
  String get keepMeSignedIn => 'Keep me signed in';

  @override
  String get loginWithBiometrics => 'Login with biometrics';

  @override
  String get featureComingSoon => 'This feature will be available soon.';

  @override
  String get help => 'Help';

  @override
  String get loginHelpTitle => 'Need help signing in?';

  @override
  String get loginHelpSubtitle => 'Quick tips for the login screen';

  @override
  String get loginHelpBody =>
      'Enter the username and password registered with your bank account.\n\nIf you forgot your username or password, use the links below the login form to recover them.\n\nYou can keep yourself signed in on trusted devices. On web, use the virtual keyboard icon for secure entry.\n\nFor further assistance, please visit your nearest branch or contact customer care.';

  @override
  String get loginHelpClose => 'Got it';

  @override
  String get virtualKeyboard => 'Virtual keyboard';

  @override
  String get virtualKeyboardDone => 'Done';

  @override
  String get virtualKeyboardSpace => 'Space';

  @override
  String get virtualKeyboardShuffle => 'Shuffle keys';

  @override
  String get virtualKeyboardClear => 'Clear';

  @override
  String get notRegistered => 'Not registered? ';

  @override
  String get registerHere => 'Register here';

  @override
  String get pleaseEnterCredentials => 'Please enter username and password';

  @override
  String get overview => 'Overview';

  @override
  String get accounts => 'Accounts';

  @override
  String get cards => 'Cards';

  @override
  String get deposit => 'Deposit';

  @override
  String get home => 'Home';

  @override
  String get insights => 'Insights';

  @override
  String get rewards => 'Rewards';

  @override
  String get more => 'More';

  @override
  String get transfer => 'Transfer';

  @override
  String get scan => 'Scan';

  @override
  String get scanAndPay => 'Scan & pay';

  @override
  String get payBill => 'Pay bill';

  @override
  String get goodMorning => 'Good Morning';

  @override
  String get goodMorningComma => 'Good Morning,';

  @override
  String get totalBalance => 'TOTAL BALANCE';

  @override
  String get moreTitle => 'More';

  @override
  String get theme => 'Theme';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get french => 'French';

  @override
  String get italian => 'Italian';

  @override
  String get uzbek => 'Uzbek';

  @override
  String get russian => 'Russian';

  @override
  String get security => 'Security';

  @override
  String get logOut => 'Log out';

  @override
  String get forgetDevice => 'Forget device';

  @override
  String get logOutConfirm => 'Sign out of this session on this device?';

  @override
  String get logOutConfirmWithBiometric =>
      'Sign out of this session on this device?\n\nYou will lose biometric login and will need to set it up again after you sign in.';

  @override
  String get forgetDeviceConfirm =>
      'Remove all saved session data from this device? You will need to sign in again.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get deviceBlockedTitle => 'Device not supported';

  @override
  String get deviceBlockedCompromisedMessage =>
      'For your security, this app cannot run on modified or compromised devices. Please use a standard, unmodified device.';

  @override
  String get deviceBlockedEmulatorMessage =>
      'For your security, this app cannot run on emulators or simulators in production builds.';

  @override
  String get deviceBlockedSupport =>
      'If you believe this is an error, contact your bank support centre.';

  @override
  String get deviceSecurityWarnCompromised =>
      'Security warning: this device may be modified. Proceed with caution.';

  @override
  String get deviceSecurityWarnEmulator =>
      'Security warning: you are using an emulator or simulator.';

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
      'For your security, you have been signed out. Please sign in again.';

  @override
  String get sessionExpiredTitle => 'Session expired';

  @override
  String get sessionExpiredSignIn => 'Sign in';

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
      'Unable to load accounts. Please try again.';

  @override
  String get accountsEmpty => 'No accounts available.';

  @override
  String get accountsRetry => 'Retry';

  @override
  String get accountStatusActive => 'Active';

  @override
  String get accountStatusDormant => 'Dormant';

  @override
  String get accountsMultipleCurrencies => 'Balances shown by currency';

  @override
  String get availableBalanceLabel => 'Available balance';

  @override
  String get errorLoansLoadFailed => 'Unable to load loans. Please try again.';

  @override
  String get loansEmpty => 'No loans available.';

  @override
  String get loanTrackerTitle => 'Loan Tracker';

  @override
  String get loanTotalBorrowing => 'Total Borrowing';

  @override
  String get loanTotalOutstanding => 'Total Outstanding';

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
      'Unable to load account details. Please try again.';

  @override
  String get errorTransactionsLoadFailed =>
      'Unable to load transactions. Please try again.';

  @override
  String get casaAccountDetailsTitle => 'Current & Saving Account Details';

  @override
  String get casaAccountDetailsTitleWeb => 'CURRENT & SAVING ACCOUNT DETAILS';

  @override
  String get casaAccountNumberLabel => 'Account Number';

  @override
  String get casaCurrentBalance => 'Current Balance';

  @override
  String get casaProductName => 'Product Name';

  @override
  String get casaNickName => 'Nick Name';

  @override
  String get casaNotAssigned => 'Not Assigned';

  @override
  String get casaNotRegistered => 'Not Registered';

  @override
  String get casaBalanceDetails => 'Balance Details';

  @override
  String get casaTodaysOpeningBalance => 'Today\'s Opening Balance';

  @override
  String get casaAvailableBalance => 'Available Balance';

  @override
  String get casaAmountOnHold => 'Amount on Hold';

  @override
  String get casaUnderFunds => 'Under Funds';

  @override
  String get casaAdvanceAgainstUnclearFunds =>
      'Advance Against Unclear Funds Limit';

  @override
  String get casaOverdraftLimit => 'Overdraft Limit';

  @override
  String get casaSweepInAmount => 'Sweep-in Amount';

  @override
  String get casaGeneralDetails => 'General Details';

  @override
  String get casaHoldingPattern => 'Holding Pattern';

  @override
  String get casaPrimaryAccountHolder => 'Primary Account Holder';

  @override
  String get casaNominee => 'Nominee';

  @override
  String get casaBranch => 'Branch';

  @override
  String get casaViewTransactions => 'View transactions';

  @override
  String get casaTransactionsTitle => 'Transactions';

  @override
  String get casaTransactionsTitleWeb => 'TRANSACTIONS';

  @override
  String get casaOpeningBalance => 'Opening Balance';

  @override
  String get casaClosingBalance => 'Closing Balance';

  @override
  String get casaRecentTransactions => 'Recent transactions';

  @override
  String get casaTransactionsEmpty => 'No transactions found.';

  @override
  String casaTransactionRef(String reference) {
    return 'Ref: $reference';
  }

  @override
  String get casaDownloadStatement => 'Download statement';

  @override
  String get casaStatementDownloadSuccess => 'Statement downloaded.';

  @override
  String get casaStatementDownloadFailed =>
      'Unable to download statement. Please try again.';

  @override
  String get casaFilterViewOptions => 'View Options';

  @override
  String get casaFilterTransactions => 'Transactions';

  @override
  String get casaFilterAll => 'All';

  @override
  String get casaFilterCreditsOnly => 'Credits Only';

  @override
  String get casaFilterDebitsOnly => 'Debits Only';

  @override
  String get casaFilterAmount => 'Amount';

  @override
  String get casaFilterFromAmount => 'From Amount';

  @override
  String get casaFilterToAmount => 'To Amount';

  @override
  String get casaFilterDate => 'Date';

  @override
  String get casaFilterFromDate => 'From Date';

  @override
  String get casaFilterToDate => 'To Date';

  @override
  String get casaFilterReferenceNumber => 'Reference Number';

  @override
  String get casaFilterApply => 'Apply';

  @override
  String get casaFilterReset => 'Reset';

  @override
  String get casaViewCurrentMonth => 'Current Month';

  @override
  String get casaViewCurrentDay => 'Current Day';

  @override
  String get casaViewPreviousDay => 'Previous Day';

  @override
  String get casaViewDateRange => 'Date Range';

  @override
  String get casaViewSpecificDay => 'Specific Day';

  @override
  String get casaViewPreviousMonth => 'Previous Month';

  @override
  String get casaViewPreviousQuarter => 'Previous Quarter';

  @override
  String get casaViewLast10 => 'Last 10 Transactions';

  @override
  String get casaViewCurrentAndPreviousMonth => 'Current & Previous Month';

  @override
  String get casaTxnTypeCredit => 'Credit';

  @override
  String get casaTxnTypeDebit => 'Debit';

  @override
  String get casaColTxnDate => 'Transaction Date';

  @override
  String get casaColValueDate => 'Value Date';

  @override
  String get casaColDescription => 'Description';

  @override
  String get casaColReference => 'Reference Number';

  @override
  String get casaColType => 'Transaction Type';

  @override
  String get casaColAmount => 'Amount';

  @override
  String get casaColBalance => 'Balance';

  @override
  String get casaStatementPasswordTitle => 'Password combination';

  @override
  String get casaStatementPasswordBody =>
      'The downloaded statement is password-protected. The password is the first 4 letters of your name in capitals, followed by your date of birth in DDMM format.';

  @override
  String get casaStatementPasswordExample1 =>
      'Example: Name Roopa Lal, date of birth 23-12-1980 → ROOP2312.';

  @override
  String get casaStatementPasswordExample2 =>
      'If the first name has fewer than 4 letters, remaining letters are taken from the last name. Example: Joy Matthew, 01-01-1980 → JOYM0101.';

  @override
  String get casaStatementPasswordContinue => 'Download';

  @override
  String get errorInvalidRequest => 'Invalid request. Please check your input.';

  @override
  String get errorOtpInvalid =>
      'The verification code is incorrect. Please try again.';

  @override
  String get errorBiometricAccessPoint =>
      'Mobile quick access is not enabled for your account on the server. Ask your bank to enable the Mobile App touch point for your user.';

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
      other: '$count resends remaining',
      one: '1 resend remaining',
      zero: 'No resends remaining',
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
  String get biometricEnableLogin => 'Enable biometric login';

  @override
  String get biometricEnableLoginHelper =>
      'Use your fingerprint or face unlock to log in quickly.';

  @override
  String get biometricEnableFaceId => 'Enable Face ID';

  @override
  String get biometricEnableTouchId => 'Enable Touch ID';

  @override
  String get biometricNotEnrolledTitle => 'Biometric unlock not set up';

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
