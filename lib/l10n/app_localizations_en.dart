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
  String get enterUsername => 'Enter your username';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotUsername => 'Forgot username?';

  @override
  String get forgotUsernameOrPassword => 'Forgot username or password?';

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
  String get loginOr => 'or';

  @override
  String get loginNoAccount => 'Don\'t have an account? ';

  @override
  String get loginSignup => 'Signup';

  @override
  String get loginMobileSubtitle =>
      'Sign in to continue with your banking activities securely.';

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
  String get colorTheme => 'Color theme';

  @override
  String get paletteCyan => 'Cyan';

  @override
  String get paletteOrange => 'Orange';

  @override
  String get paletteIndigo => 'Indigo';

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
  String get quickActions => 'Quick Actions';

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
  String get recentTransactions => 'Recent Transactions';

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
  String get menuPayments => 'Payments';

  @override
  String get ownAccountTransfer => 'Own Account Transfer';

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
  String get casaTransactionsEmpty =>
      'No Activity found for the specified period.';

  @override
  String get casaSearchForAmount => 'Search for amount';

  @override
  String get casaRecentTransactions => 'Recent Transactions';

  @override
  String get casaLoadMore => 'Load More';

  @override
  String get casaStatusLabel => 'Status';

  @override
  String get casaSearchAccounts => 'Search accounts';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get homeAllAccounts => 'All Accounts';

  @override
  String get homeSavingsAccount => 'Savings Account';

  @override
  String get homeCurrentAccount => 'Current Account';

  @override
  String get homeViewAllAccounts => 'View all accounts';

  @override
  String get homeDeposit => 'Deposit';

  @override
  String get homePrimaryAccount => 'Primary Account';

  @override
  String get homeTotalBalance => 'Total Balance';

  @override
  String homeAccountsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Accounts',
      one: '1 Account',
    );
    return '$_temp0';
  }

  @override
  String get qaTitle => 'Quick Actions';

  @override
  String get qaEdit => 'Edit';

  @override
  String get qaEditTitle => 'Edit Quick Actions';

  @override
  String qaEditHint(int count) {
    return 'Choose up to $count shortcuts for your Home screen. Drag to change the order.';
  }

  @override
  String get qaPickOne => 'Choose at least one shortcut.';

  @override
  String get qaAdd => 'Add';

  @override
  String get qaRemove => 'Remove';

  @override
  String get qaReset => 'Reset to default';

  @override
  String get qaSave => 'Save';

  @override
  String get qaScanPay => 'Scan & Pay';

  @override
  String get qaBill => 'Bill';

  @override
  String get qaSaving => 'Saving';

  @override
  String get qaMultipleTransfers => 'Multiple Transfers';

  @override
  String get qaRepeatTransfers => 'Repeat Transfers';

  @override
  String get qaPayee => 'Payee';

  @override
  String get qaMoreServices => 'More Services';

  @override
  String get qaCurrentSavings => 'Current & Savings';

  @override
  String get qaLoans => 'Loans & Finances';

  @override
  String get qaTermDeposits => 'Term Deposits';

  @override
  String get qaGroupPayments => 'Payments';

  @override
  String get qaGroupAccounts => 'Accounts';

  @override
  String get qaGroupOther => 'Other Services';

  @override
  String get homeSecurityNotice => 'Security notice';

  @override
  String get loanTrackerOutstanding => 'Outstanding';

  @override
  String get menuTitle => 'Menu';

  @override
  String get menuWelcome => 'Welcome';

  @override
  String get menuNetworth => 'Networth';

  @override
  String get menuLanguages => 'Languages';

  @override
  String get menuWhatsNew => 'What\'s New';

  @override
  String get menuExploreProducts => 'Explore Products';

  @override
  String get menuNotification => 'Notification';

  @override
  String get menuAppSettings => 'App Settings';

  @override
  String get menuPersonalizeDashboard => 'Personalize Dashboard';

  @override
  String get menuProfile => 'Profile';

  @override
  String get menuNeedHelp => 'Need Help';

  @override
  String casaTransactionsPageIndicator(int page, int pageCount, int total) {
    return 'Page $page of $pageCount · $total transactions';
  }

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
  String get otpTitle => 'OTP Code Verification';

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
  String otpResendIn(String time) {
    return 'Resend code in $time';
  }

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

  @override
  String get amountAndRateTitle => 'Amount & Rate';

  @override
  String get back => 'Back';

  @override
  String get balance => 'Balance';

  @override
  String get calculatedAmount => 'Calculated Amount';

  @override
  String get change => 'Change';

  @override
  String get chargesDebitedFromDebitAccount =>
      'Charges to be debited from Debit Account';

  @override
  String get creditAccountCurrency => 'Credit Account Currency';

  @override
  String get currencyRatesIndicative =>
      'Currency conversion rates are indicative';

  @override
  String get done => 'Done';

  @override
  String get exchangeRate => 'Exchange Rate';

  @override
  String get exchangeRateDetailsCard =>
      'Exchange Rate Details - Card / Preferential Rate';

  @override
  String get exchangeRateDetailsTitle => 'Exchange Rate Details';

  @override
  String get existing => 'Existing';

  @override
  String get existingPayer => 'Existing Payer';

  @override
  String get hostReferenceNumber => 'Host Reference Number';

  @override
  String get immediate => 'Immediate';

  @override
  String get later => 'Later';

  @override
  String get lfwAccept => 'Accept';

  @override
  String get lfwAcceptTerms => 'I accept the Terms & Conditions';

  @override
  String get lfwAnswerLabel => 'Answer';

  @override
  String get lfwDuplicateQuestion =>
      'Please select a different question for each row.';

  @override
  String get lfwEnterAnswer => 'Enter Answer';

  @override
  String get lfwFieldRequired => 'Required';

  @override
  String get lfwGateErrorTitle => 'Unable to open your dashboard';

  @override
  String get lfwLimitsChannel => 'Channel';

  @override
  String get lfwLimitsEmptyAssigned =>
      'Currently no limits are assigned to this transaction. Please contact administrator for further details.';

  @override
  String get lfwLimitsSubtitle =>
      'Review your transaction limits, then continue.';

  @override
  String get lfwLimitsTitle => 'Transaction limits';

  @override
  String get lfwLimitsTransactions => 'Transactions';

  @override
  String get lfwMustAcceptTerms =>
      'Please accept the Terms & Conditions to continue.';

  @override
  String get lfwNoProfileData => 'No profile details are available to display.';

  @override
  String get lfwProfileDateOfBirth => 'Date of Birth';

  @override
  String get lfwProfilePersonalInfo => 'Personal Information';

  @override
  String get lfwProfileSubtitle =>
      'Please review your profile details, then continue.';

  @override
  String get lfwProfileTitle => 'Profile';

  @override
  String get lfwSaveAndContinue => 'Submit';

  @override
  String get lfwSecurityNoteBody =>
      'Security questions works as an added layer of security that helps in protecting your account against fraudulent activities.';

  @override
  String get lfwSecurityNoteBullet1 =>
      'Choose answers that are difficult for others to guess';

  @override
  String get lfwSecurityNoteBullet2 =>
      'Choose questions which you have not answered on public or on social media sites';

  @override
  String get lfwSecurityNoteMust => 'You must:';

  @override
  String get lfwSecurityNoteTitle => 'Note';

  @override
  String get lfwSecurityQuestionLabel => 'Security Question';

  @override
  String get lfwSecurityQuestionsNotSetup =>
      'User Security Questions have not been setup yet.';

  @override
  String get lfwSecurityQuestionsSection => 'User Security Questions';

  @override
  String get lfwSecurityQuestionsSetupNow => 'Set up now';

  @override
  String get lfwSecurityQuestionsSubtitle =>
      'Choose security questions and provide your answers. These may be used for verification later.';

  @override
  String get lfwSecurityQuestionsTitle => 'Set Security Question';

  @override
  String get lfwSelectChannel => 'Select channel';

  @override
  String get lfwSelectQuestion => 'Select Question';

  @override
  String get lfwSelectTransaction => 'Select transaction';

  @override
  String lfwStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get lfwSubtitle =>
      'Complete the following steps to access your dashboard.';

  @override
  String get lfwTermsSubtitle =>
      'Please read and accept the Terms & Conditions to continue.';

  @override
  String get lfwTermsTitle => 'Terms and Conditions';

  @override
  String get lfwTermsReadCarefully =>
      'Please read the following terms carefully before proceeding.';

  @override
  String get lfwRemindLater => 'Remind Later';

  @override
  String get lfwSkip => 'Skip';

  @override
  String get altLoginEnableTitle => 'Enable Alternate Login';

  @override
  String get altLoginEnableBody =>
      'Sign in next time with your fingerprint or face instead of your password.';

  @override
  String get altLoginEnable => 'Enable';

  @override
  String get lfwTitle => 'First-time setup';

  @override
  String get lfwUnknownStep => 'Please complete this setup step to continue.';

  @override
  String get myAccounts => 'My Accounts';

  @override
  String get newPayer => 'New Payer';

  @override
  String get next => 'Next';

  @override
  String get note => 'Note';

  @override
  String get now => 'Now';

  @override
  String get pay => 'Pay';

  @override
  String get rateApplied => 'Rate Applied';

  @override
  String get review => 'Review';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get selectCreditAccount => 'Select credit account';

  @override
  String get selectDebitAccount => 'Select debit account';

  @override
  String get stationaryCharges => 'Stationary Charges';

  @override
  String get submit => 'Submit';

  @override
  String get theyReceive => 'They Receive';

  @override
  String get timing => 'Timing';

  @override
  String get transferAmount => 'Transfer Amount';

  @override
  String get transferAmountRequired => 'Please enter a valid transfer amount.';

  @override
  String get transferCurrencyLabel => 'Currency';

  @override
  String get transferFixedRate => 'Fixed';

  @override
  String get transferFrom => 'Transfer From';

  @override
  String get transferInsufficientBalance => 'Amount exceeds available balance.';

  @override
  String get transferLimitsComingSoon =>
      'Transfer limits will be available soon.';

  @override
  String get transferMoney => 'Transfer Money';

  @override
  String get transferOtpSubtitle =>
      'Enter the verification code to confirm this transfer.';

  @override
  String get transferSameAccountError =>
      'Debit and credit accounts must be different.';

  @override
  String get transferSelectBothAccounts =>
      'Please select debit and credit accounts.';

  @override
  String get transferSelectDate => 'Select date';

  @override
  String get transferSubmitFailed =>
      'Transfer could not be completed. Please try again.';

  @override
  String get transferSuccessMessage =>
      'Your transfer has been submitted successfully.';

  @override
  String get transferSuccessTitle => 'Transfer successful';

  @override
  String get transferSummary => 'Transfer Summary';

  @override
  String get transferSummaryFrom => 'From';

  @override
  String get transferSummaryTo => 'To';

  @override
  String get transferTo => 'Transfer To';

  @override
  String get transferType => 'Transfer Type';

  @override
  String get transferValidateFailed =>
      'Unable to validate transfer. Please check the details and try again.';

  @override
  String get transferWhen => 'Transfer When';

  @override
  String get viewLimits => 'View Limits';

  @override
  String get youSend => 'You Send';

  @override
  String get forgotSecurityQuestionsTitle => 'Security Questions';

  @override
  String get forgotSecurityQuestionsSubtitle =>
      'Answer your security questions to continue.';

  @override
  String get forgotSecurityAnswerLabel => 'Answer';

  @override
  String get forgotSecurityAnswerRequired => 'Please enter an answer';

  @override
  String get errorSecurityAnswersInvalid =>
      'One or more answers are incorrect. Please try again.';

  @override
  String get tdTermDeposit => 'Term Deposit';

  @override
  String get tdLoadFailed =>
      'We couldn\'t load your term deposits. Please try again.';

  @override
  String get tdDetailsLoadFailed =>
      'We couldn\'t load this deposit. Please try again.';

  @override
  String get tdPayoutLoadFailed => 'Payout instructions couldn\'t be loaded.';

  @override
  String get tdTransactionsLoadFailed =>
      'We couldn\'t load the transactions. Please try again.';

  @override
  String get tdProductsLoadFailed =>
      'We couldn\'t load the deposit products. Please try again.';

  @override
  String get tdActionFailed =>
      'We couldn\'t complete this request. Please try again.';

  @override
  String get tdContinue => 'Continue';

  @override
  String get tdDone => 'Done';

  @override
  String get tdEdit => 'Edit';

  @override
  String get tdCurrent => 'Current';

  @override
  String get tdStepDetails => 'Details';

  @override
  String get tdStepReview => 'Review';

  @override
  String get tdStepDone => 'Done';

  @override
  String get tdReviewTitle => 'Review and confirm';

  @override
  String get tdReferenceNumber => 'Reference number';

  @override
  String get tdOpenDeposit => 'Open deposit';

  @override
  String get tdActive => 'Active';

  @override
  String get tdClosed => 'Closed';

  @override
  String get tdTotalInvested => 'Total invested';

  @override
  String get tdMaturityValue => 'Maturity value';

  @override
  String get tdExpectedInterest => 'Expected interest';

  @override
  String get tdDepositCount => 'Deposits';

  @override
  String get tdShowAmounts => 'Show amounts';

  @override
  String get tdHideAmounts => 'Hide amounts';

  @override
  String get tdNoDeposits => 'You don\'t have any active term deposits yet.';

  @override
  String get tdNoClosed => 'You have no closed term deposits.';

  @override
  String tdMaturesInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Matures in $days days',
      one: 'Matures in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get tdMatured => 'Matured';

  @override
  String get tdCurrentBalance => 'Current balance';

  @override
  String get tdMaturityAmount => 'Maturity amount';

  @override
  String get tdMaturityDate => 'Maturity date';

  @override
  String get tdInterestRate => 'Interest rate';

  @override
  String get tdTopUp => 'Top Up';

  @override
  String get tdRedeem => 'Redeem';

  @override
  String get tdEditMaturity => 'Edit Maturity Instructions';

  @override
  String get tdDepositDetails => 'Deposit details';

  @override
  String get tdOriginalPrincipal => 'Original principal';

  @override
  String get tdCurrentPrincipal => 'Current principal';

  @override
  String get tdDepositDate => 'Deposit date';

  @override
  String get tdDepositTerm => 'Deposit term';

  @override
  String get tdHoldAmount => 'Hold amount';

  @override
  String get tdMaturityDetails => 'Maturity';

  @override
  String get tdMaturityInstruction => 'Maturity instruction';

  @override
  String get tdPayoutInstructions => 'Payout instructions';

  @override
  String tdPayoutLine(String percentage, String component, String account) {
    return '$percentage% of $component to $account';
  }

  @override
  String get tdPrincipal => 'principal';

  @override
  String get tdInterest => 'interest';

  @override
  String get tdPrincipalAndInterest => 'principal and interest';

  @override
  String get tdGeneralDetails => 'General details';

  @override
  String get tdAccountNumber => 'Deposit number';

  @override
  String get tdHoldingPattern => 'Holding pattern';

  @override
  String get tdHoldingSingle => 'Single';

  @override
  String get tdHoldingJoint => 'Joint';

  @override
  String get tdPrimaryHolder => 'Primary holder';

  @override
  String get tdBranch => 'Branch';

  @override
  String get tdTransactions => 'Transactions';

  @override
  String get tdPeriodCurrentMonth => 'This month';

  @override
  String get tdPeriodPreviousMonth => 'Last month';

  @override
  String get tdPeriodPreviousQuarter => 'Last quarter';

  @override
  String get tdPeriodLastTen => 'Last 10';

  @override
  String get tdTxnAll => 'All';

  @override
  String get tdTxnCredits => 'Credits';

  @override
  String get tdTxnDebits => 'Debits';

  @override
  String get tdNoTransactions => 'No transactions in this period.';

  @override
  String get tdSelectAccount => 'Select an account';

  @override
  String get tdSelectAccountError => 'Select an account.';

  @override
  String get tdLoadingAccounts => 'Loading accounts…';

  @override
  String get tdNoAccounts => 'No eligible accounts.';

  @override
  String get tdAvailable => 'Available';

  @override
  String get tdEnterAmount => 'Enter an amount.';

  @override
  String get tdInsufficientBalance =>
      'The amount is more than the account\'s available balance.';

  @override
  String get tdPayFrom => 'Pay from';

  @override
  String get tdPayTo => 'Pay to';

  @override
  String get tdPayoutOwnAccount => 'My account';

  @override
  String get tdPayoutInternalAccount => 'Another account';

  @override
  String get tdAccountNumberHint => 'Account number';

  @override
  String get tdPayoutRequired => 'Choose where the money goes.';

  @override
  String get tdDepositAccount => 'Deposit account';

  @override
  String get tdRevisedPrincipal => 'Revised principal';

  @override
  String get tdRevisedMaturityAmount => 'Revised maturity amount';

  @override
  String get tdRevisedInterestRate => 'Revised interest rate';

  @override
  String get tdTopUpTitle => 'Top Up';

  @override
  String get tdTopUpAmount => 'Top-up amount';

  @override
  String get tdConfirmTopUp => 'Confirm top-up';

  @override
  String get tdTopUpDone => 'Deposit topped up';

  @override
  String get tdTopUpDoneMessage => 'Your top-up has been added to the deposit.';

  @override
  String get tdRedeemTitle => 'Redeem Term Deposit';

  @override
  String get tdRedemptionType => 'Redemption type';

  @override
  String get tdRedeemFull => 'Full';

  @override
  String get tdRedeemPartial => 'Partial';

  @override
  String get tdRedeemAmount => 'Redeem amount';

  @override
  String tdRedeemableAmount(String amount) {
    return 'Redeemable: $amount';
  }

  @override
  String get tdPartialTooLarge =>
      'A partial redemption must be less than the full amount.';

  @override
  String get tdRedeemPenaltyNote =>
      'Redeeming before maturity may attract a penalty. You will see the charges and the final amount before you confirm.';

  @override
  String get tdChargesPenalty => 'Charges / penalty';

  @override
  String get tdFinalRedemptionAmount => 'Final redemption amount';

  @override
  String get tdConfirmRedeem => 'Confirm redemption';

  @override
  String get tdRedeemDone => 'Redemption requested';

  @override
  String get tdRedeemDoneMessage =>
      'Your deposit redemption has been submitted.';

  @override
  String get tdEditMaturityTitle => 'Edit Maturity Instructions';

  @override
  String get tdEditMaturityIntro =>
      'Choose what happens to this deposit when it matures.';

  @override
  String get tdSelectMaturityOption => 'Choose a maturity instruction.';

  @override
  String get tdRollOverAmount => 'Roll-over amount';

  @override
  String tdRollOverTooLarge(String amount) {
    return 'The roll-over amount cannot exceed $amount.';
  }

  @override
  String get tdPayPrincipalAndInterestTo => 'Pay principal and interest to';

  @override
  String get tdPayInterestTo => 'Pay interest to';

  @override
  String get tdPayRemainingTo => 'Pay the remaining amount to';

  @override
  String get tdCurrentInstruction => 'Current instruction';

  @override
  String get tdNewInstruction => 'New instruction';

  @override
  String get tdConfirmChanges => 'Confirm changes';

  @override
  String get tdMaturityUpdated => 'Maturity instructions updated';

  @override
  String get tdMaturityUpdatedMessage =>
      'The new instructions will apply when the deposit matures.';

  @override
  String get tdOpenTitle => 'New Term Deposit';

  @override
  String get tdOpenIntro =>
      'Choose a product to see its currencies and tenure.';

  @override
  String get tdProduct => 'Product';

  @override
  String get tdSelectProduct => 'Select a product';

  @override
  String get tdSelectProductError => 'Select a product.';

  @override
  String get tdNoProducts =>
      'No deposit products are available right now. Please try again later or contact the bank.';

  @override
  String get tdDepositAmount => 'Deposit amount';

  @override
  String tdMin(String amount) {
    return 'Min $amount';
  }

  @override
  String tdMax(String amount) {
    return 'Max $amount';
  }

  @override
  String tdAmountBelowMin(String amount) {
    return 'The minimum amount is $amount.';
  }

  @override
  String tdAmountAboveMax(String amount) {
    return 'The maximum amount is $amount.';
  }

  @override
  String get tdYears => 'Years';

  @override
  String get tdMonths => 'Months';

  @override
  String get tdDays => 'Days';

  @override
  String get tdEnterTenure => 'Enter the deposit term.';

  @override
  String tdTenureRange(String min, String max) {
    return 'Term $min to $max';
  }

  @override
  String tdTenureBelowMin(String min) {
    return 'The minimum term is $min.';
  }

  @override
  String tdTenureAboveMax(String max) {
    return 'The maximum term is $max.';
  }

  @override
  String get tdPayAtMaturityTo => 'Pay at maturity to';

  @override
  String get tdConfirmOpen => 'Open deposit';

  @override
  String get tdOpenDone => 'Deposit opened';

  @override
  String get tdOpenDoneMessage => 'Your new term deposit is open.';

  @override
  String get tdOtpTitle => 'Verify it\'s you';

  @override
  String get tdOtpSubtitle =>
      'Enter the one-time password sent to your registered mobile number.';

  @override
  String get tdOtpVerify => 'Verify';

  @override
  String get billPaymentsTitle => 'Bill Payments';

  @override
  String get billersTitle => 'Billers';

  @override
  String get billersSubtitle => 'Billers you have added for paying bills';

  @override
  String get billersSearchHint => 'Search by Biller Nickname, Category';

  @override
  String get billersAdd => 'Add Billers';

  @override
  String get billerGroupPresentment => 'Bills Presented';

  @override
  String get billerGroupRecharge => 'Recharge Bill Payment';

  @override
  String get billerGroupPayment => 'Direct Bill Payment';

  @override
  String get billerEmptyPresentment =>
      'You have not yet added any billers who present bills. To get started click on Add Biller.';

  @override
  String get billerEmptyRecharge =>
      'You have not yet added any billers for recharge. To get started click on Add Biller.';

  @override
  String get billerEmptyPayment =>
      'You have not yet added any billers for making bill payments. To get started click on Add Biller.';

  @override
  String get billerTypeEbill => 'eBill';

  @override
  String get billerTypeEbillManual => 'eBill + Manual';

  @override
  String get billerTypeRecharge => 'Recharge';

  @override
  String get billerTypeManual => 'Manual';

  @override
  String get billerStatusPastDue => 'Past Due';

  @override
  String get billerStatusAutoPay => 'Auto Pay';

  @override
  String get billerStatusScheduledPay => 'Scheduled Pay';

  @override
  String get billerBillsDue => 'Bills Due';

  @override
  String get billerNoBillsDue => 'No Bills Due';

  @override
  String billerDueBy(String date) {
    return 'Due by $date';
  }

  @override
  String get billerApprovalPending => 'Approval Pending';

  @override
  String get billerRejected => 'Rejected by bank';

  @override
  String get billerDetailsTitle => 'Biller Details';

  @override
  String get billerEdit => 'Edit Biller';

  @override
  String get billerDelete => 'Delete Biller';

  @override
  String get billerPay => 'Pay';

  @override
  String get billerYes => 'Yes';

  @override
  String get billerNo => 'No';

  @override
  String get billerDeleteConfirm =>
      'Are you sure you want to delete this biller?';

  @override
  String get billerDeleteBlocked =>
      'Please close the auto pay/scheduled pay currently set up for this biller before deleting.';

  @override
  String get billerEditPending =>
      'Your previous details are yet to be approved by bank. Please contact your bank for further details.';

  @override
  String billerDeleted(String name) {
    return '$name deleted.';
  }

  @override
  String billerDeletePendingApproval(String name) {
    return 'Deleting $name is waiting for approval.';
  }

  @override
  String billerDeleteFailed(String name) {
    return 'We couldn\'t delete $name. Please try again.';
  }

  @override
  String billerDeleteOtpTitle(String name) {
    return 'Verify to delete $name';
  }

  @override
  String get billerOtpInvalid => 'That code is not right. Please try again.';

  @override
  String get billersLoadFailed => 'We couldn\'t load your billers.';

  @override
  String get billerDetailsLoadFailed => 'We couldn\'t load this biller.';

  @override
  String billersNoMatch(String query) {
    return 'Nothing matches \"$query\".';
  }

  @override
  String get billerName => 'Biller Name';

  @override
  String get billerCategory => 'Category and Sub Category';

  @override
  String get billerLocation => 'Location';

  @override
  String get billerType => 'Biller Type';

  @override
  String get billerNickname => 'Biller Nickname';

  @override
  String get billerCustomerName => 'Customer Name';

  @override
  String get billerPaymentType => 'Payment Type';

  @override
  String get billerPayFrom => 'Pay From';

  @override
  String get billerFrequency => 'Frequency';

  @override
  String get billerStartDate => 'Start Date';

  @override
  String get billerEndDate => 'End Date';

  @override
  String get billerBillAmount => 'Bill Amount';

  @override
  String get billerBillDueDate => 'Bill Due Date';

  @override
  String get addBillerReview => 'Review';

  @override
  String get addBillerReviewMessage =>
      'You initiated a request for add biller. Please review details before you confirm!';

  @override
  String get addBillerSuccess => 'Biller added successfully.';

  @override
  String get addBillerSubmit => 'Submit';

  @override
  String get addBillerConfirm => 'Confirm';

  @override
  String get addBillerSelect => 'Please Select';

  @override
  String get addBillerCategory => 'Category';

  @override
  String get addBillerPaymentNote =>
      'Auto Pay and Scheduled Pay will be available soon.';

  @override
  String addBillerFieldRequired(String label) {
    return '$label is required.';
  }

  @override
  String addBillerFieldTooLong(String label, int max) {
    return '$label can be at most $max characters.';
  }

  @override
  String get addBillerFieldAlphanumeric =>
      'Please enter the details in the alphanumeric format';

  @override
  String get addBillerFieldNumeric =>
      'Please enter the details in the numeric format';

  @override
  String get addBillerFieldText =>
      'Please enter the details in the text format';

  @override
  String get addBillerFieldInvalid => 'Please enter valid data';

  @override
  String get addBillerNicknameError =>
      'Nickname can comprise alphanumerics (A-Z any case, 0-9)&,/,-\"space';

  @override
  String get addBillerCustomerNameError =>
      'Customer Name can comprise alphanumerics (A-Z any case, 0-9)&,/,-\"space';

  @override
  String get addBillerFailed =>
      'We couldn\'t add this biller. Please try again.';

  @override
  String get addBillerLoadFailed => 'We couldn\'t load the billers.';

  @override
  String get addBillerNoBillers => 'Currently no billers are available.';

  @override
  String get addBillerBackToBillers => 'Back to Billers';

  @override
  String get addBillerPendingApproval => 'Pending Approval';

  @override
  String addBillerOtpTitle(String name) {
    return 'Verify to add $name';
  }

  @override
  String billerReferenceNumber(String reference) {
    return 'Reference Number: $reference';
  }

  @override
  String get billHistoryTitle => 'Bill Payment History';

  @override
  String get billHistorySubtitle => 'Bills you have paid';

  @override
  String get billHistoryFilter => 'Filter';

  @override
  String get billHistorySelectPeriod => 'Select Period';

  @override
  String get billHistoryCurrentPeriod => 'Current Period';

  @override
  String get billHistoryPreviousMonth => 'Previous Month';

  @override
  String get billHistoryPreviousQuarter => 'Previous Quarter';

  @override
  String get billHistoryDateRange => 'Date Range';

  @override
  String get billHistoryDateFrom => 'Date From';

  @override
  String get billHistoryDateTo => 'Date To';

  @override
  String get billHistoryApply => 'Apply';

  @override
  String get billHistoryDatesRequired => 'Select both dates.';

  @override
  String get billHistoryDate => 'Date';

  @override
  String get billHistoryBiller => 'Biller';

  @override
  String get billHistoryReferenceNo => 'Reference No';

  @override
  String get billHistoryStatus => 'Status';

  @override
  String get billHistoryStatusSent => 'Sent';

  @override
  String get billHistoryStatusCompleted => 'Completed';

  @override
  String get billHistoryStatusPending => 'Pending';

  @override
  String get billHistoryStatusTimeout => 'Timeout';

  @override
  String get billHistoryStatusError => 'Error';

  @override
  String get billHistoryNoData => 'No data found matching the search criteria';

  @override
  String get billHistoryLoadFailed => 'We couldn\'t load your bill payments.';

  @override
  String get billerDetailsSection => 'Details';

  @override
  String get billerDetailsTypeEbills => 'e-Bills';

  @override
  String get billerDetailsTypePayment => 'Payment';

  @override
  String get editBillerNicknameLabel =>
      'Biller Nickname(Nickname should be unique)';

  @override
  String get editBillerReviewMessage =>
      'You initiated a request for update biller. Please review details before you confirm!';

  @override
  String get editBillerSuccess => 'Biller updated successfully.';

  @override
  String editBillerOtpTitle(String name) {
    return 'Verify to update $name';
  }

  @override
  String get editBillerFailed =>
      'We couldn\'t update this biller. Please try again.';

  @override
  String get editBillerPaymentInstructionSoon =>
      'Editing billers with Auto Pay or Scheduled Pay will be available soon.';

  @override
  String get billerEditTypePresentment => 'Presentment';

  @override
  String get billerEditTypePresentmentPayment => 'Presentment and Payment';

  @override
  String get ccTitle => 'Credit Cards';

  @override
  String get ccSubtitle => 'Your credit cards and their dues';

  @override
  String get ccCardNumber => 'Card Number';

  @override
  String get ccOwnerName => 'Owner Name';

  @override
  String get ccExpiryDate => 'Expiry Date';

  @override
  String get ccAvailableCreditLimit => 'Available Credit Limit';

  @override
  String get ccCurrentOutstanding => 'Current Outstanding';

  @override
  String get ccTotalDue => 'Total Due';

  @override
  String get ccMinimumDue => 'Minimum Due';

  @override
  String get ccDueOn => 'Due On';

  @override
  String get ccPay => 'Pay';

  @override
  String get ccNoDues => 'No Dues';

  @override
  String get ccEmpty => 'You do not have any credit cards at present.';

  @override
  String get ccStatusActive => 'ACTIVE';

  @override
  String get ccStatusInactive => 'INACTIVE';

  @override
  String get ccStatusHotlisted => 'HOTLISTED';

  @override
  String get ccStatusCancelled => 'CANCELLED';

  @override
  String get ccStatusBlocked => 'BLOCKED';

  @override
  String get ccPrimary => 'Primary';

  @override
  String get ccAddOn => 'Add-On Card';

  @override
  String get ccTransactions => 'Transactions';

  @override
  String get ccCardPayment => 'Card Payment';

  @override
  String get ccLoadFailed => 'We couldn\'t load your credit cards.';

  @override
  String get ccUnbilled => 'Unbilled Transactions';

  @override
  String get ccBilled => 'Billed Transactions';

  @override
  String get ccMonth => 'Month';

  @override
  String get ccTxLoadFailed => 'We couldn\'t load the card transactions.';

  @override
  String get billHistoryDownload => 'Download';

  @override
  String get billHistoryPasswordTitle => 'Password Combination';

  @override
  String get billHistoryPasswordBody =>
      'On opening the PDF, you will be asked to enter a password. Your password consists of the first 4 letters of your user name in capital case, followed by the date and month of your birth (in DDMM format)';

  @override
  String get billHistoryPasswordExample =>
      'For example, if the user name is Roopa Lal and the date of birth is 23-12-1976, then your password will be ROOP2312.';

  @override
  String get menuAccountSettings => 'Account Settings';

  @override
  String get myLimitsTitle => 'My Limits';

  @override
  String get limitsChannel => 'Channel';

  @override
  String get limitsTransactions => 'Transactions';

  @override
  String limitsTabTransaction(String taskName) {
    return '$taskName Limits';
  }

  @override
  String get limitsTabTransactionGroup => 'Transaction Group Limits';

  @override
  String get limitsTabChannelGroup => 'Channel Group Limits';

  @override
  String get limitsTabChannelTransactionGroup =>
      'Channel & Transaction Group Limits';

  @override
  String get limitsTabConsolidated => 'Consolidated Limits';

  @override
  String get limitsTabConsolidatedTransactionGroup =>
      'Consolidated & Transaction Group Limits';

  @override
  String get limitsMinimumAmount => 'Minimum Amount';

  @override
  String get limitsMaximumAmount => 'Maximum Amount';

  @override
  String get limitsDaily => 'Daily Limits';

  @override
  String get limitsMonthly => 'Monthly Limits';

  @override
  String limitsDailyNotAssigned(String accessPoint) {
    return 'Daily limit package is not assigned for the selected transaction for $accessPoint Touch Point';
  }

  @override
  String limitsMonthlyNotAssigned(String accessPoint) {
    return 'Monthly limit package is not assigned for the selected transaction for $accessPoint Touch Point';
  }

  @override
  String get limitsAmount => 'Amount';

  @override
  String get limitsCount => 'Count';

  @override
  String get limitsUtilized => 'Utilized';

  @override
  String get limitsAvailable => 'Available';

  @override
  String get limitsTotal => 'Total';

  @override
  String get limitsLoadFailed => 'Limits could not be loaded.';

  @override
  String get limitsNoTransactions =>
      'No transactions have limits for this channel.';

  @override
  String get ccModuleSubtitle => 'Your cards and what you can do with them';

  @override
  String get ccListDesc => 'See your cards, limits and dues';

  @override
  String get ccCardDetails => 'Credit Card Details';

  @override
  String get ccTransactionsDesc => 'Unbilled and billed transactions';

  @override
  String get ccRequestPin => 'Request PIN';

  @override
  String get ccBlockUnblock => 'Block/Unblock Card';

  @override
  String get ccCancelCard => 'Cancel Card';

  @override
  String get ccAutoPay => 'Auto Pay';

  @override
  String get ccResetPin => 'Reset PIN';

  @override
  String get billsModuleSubtitle => 'Your billers and bill payments';

  @override
  String get billFavorites => 'Favorites';

  @override
  String get billersDesc => 'Your registered billers';

  @override
  String get billersAddDesc => 'Register a new biller';

  @override
  String get billQuickBillPay => 'Quick Bill Pay';

  @override
  String get billQuickRecharge => 'Quick Recharge';

  @override
  String get billHistoryDesc => 'Bill payments you have made';

  @override
  String get moduleComingSoon => 'Coming soon';

  @override
  String get mailboxTitle => 'Mailbox';

  @override
  String get mailboxMails => 'Mails';

  @override
  String get mailboxAlerts => 'Alerts';

  @override
  String get mailboxNotifications => 'Notifications';

  @override
  String mailboxMailsCount(int count) {
    return 'Mails ($count)';
  }

  @override
  String mailboxAlertsCount(int count) {
    return 'Alerts ($count)';
  }

  @override
  String mailboxNotificationsCount(int count) {
    return 'Notifications ($count)';
  }

  @override
  String get mailboxInbox => 'Inbox';

  @override
  String get mailboxSentMails => 'Sent Mails';

  @override
  String get mailboxDeletedMails => 'Deleted Mails';

  @override
  String get mailboxSubject => 'Subject';

  @override
  String get mailboxReferenceNo => 'Reference No';

  @override
  String get mailboxDate => 'Date';

  @override
  String get mailboxReceived => 'Received';

  @override
  String get mailboxFrom => 'From :';

  @override
  String get mailboxSent => 'Sent :';

  @override
  String get mailboxAttachments => 'Attachments :';

  @override
  String get mailboxRefresh => 'Refresh';

  @override
  String get mailboxDelete => 'Delete';

  @override
  String get mailboxRestore => 'Restore';

  @override
  String get mailboxNoInbox => 'No item in Inbox';

  @override
  String get mailboxNoSent => 'No item in Sent Mail';

  @override
  String get mailboxNoDeleted => 'No item in Deleted Mail';

  @override
  String get mailboxNoAlerts => 'No item in alerts';

  @override
  String get mailboxNoNotifications => 'No item in notifications';

  @override
  String get mailboxDeleteInboxTitle => 'Delete Inbox Mails';

  @override
  String get mailboxDeleteSentTitle => 'Delete Sent Mail';

  @override
  String get mailboxDeleteDeletedTitle => 'Delete Deleted Mail';

  @override
  String get mailboxConfirmation => 'Confirmation';

  @override
  String get mailboxDeleteMail => 'Are you sure you want to delete this mail?';

  @override
  String mailboxDeleteMails(int count) {
    return 'You have selected $count mails. Are you sure you want to delete them?';
  }

  @override
  String get mailboxDeleteMailForever =>
      'This mail will be permanently deleted. Are you sure you want to continue?';

  @override
  String mailboxDeleteMailsForever(int count) {
    return 'You have selected $count mails. All the mails will be permanently deleted. Are you sure you want to continue?';
  }

  @override
  String get mailboxDeleteAlert =>
      'Are you sure you want to delete this Alert?';

  @override
  String mailboxDeleteAlerts(int count) {
    return 'You have selected $count alerts. Are you sure you want to delete them?';
  }

  @override
  String get mailboxDeleteNotification =>
      'Are you sure you want to delete this Notification?';

  @override
  String mailboxDeleteNotifications(int count) {
    return 'You have selected ($count) notifications. Are you sure you want to delete them?';
  }

  @override
  String get mailboxYes => 'Yes';

  @override
  String get mailboxNo => 'No';

  @override
  String get mailboxConfirm => 'Confirm';

  @override
  String get mailboxCancel => 'Cancel';

  @override
  String get mailboxHighPriority => 'High priority';

  @override
  String get mailboxLoadFailed => 'Mailbox could not be loaded.';

  @override
  String get mailboxDone => 'Done.';

  @override
  String get mailboxPendingApproval => 'Sent for approval.';

  @override
  String get mailboxActionFailed =>
      'That could not be completed. Please try again.';

  @override
  String get mailboxOtpTitle => 'Verify to continue';

  @override
  String get mailboxOtpInvalid => 'That code is not right. Please try again.';

  @override
  String get mailboxDownloadFailed => 'The attachment could not be downloaded.';

  @override
  String get mailboxSelectHint => 'Select an item to read it.';

  @override
  String get mailboxComposeMail => 'Compose Mail';

  @override
  String get mailboxReply => 'Reply';

  @override
  String get mailboxParty => 'Party';

  @override
  String get mailboxCategory => 'Category';

  @override
  String get mailboxSelect => 'Select';

  @override
  String get mailboxOtherRemark => 'Other Remark';

  @override
  String get mailboxMessage => 'Message';

  @override
  String get mailboxSend => 'Send';

  @override
  String get mailboxAttachFile => 'Attach File';

  @override
  String mailboxCharactersLeft(int number) {
    return '$number Characters Left';
  }

  @override
  String get mailboxEmptySubject => 'Please select a subject category';

  @override
  String get mailboxEmptyMail => 'Cannot send an empty mail';

  @override
  String get mailboxMessageTooLong => 'Maximum Length of the Message Exceeded!';

  @override
  String get mailboxFileRules =>
      'Maximum allowed file size 5 MB. Allowed file types : JPEG, PNG, DOC, PDF, TXT, ZIP, XLSX.';

  @override
  String get mailboxDuplicateFile => 'This document is already attached!';

  @override
  String get mailboxFileTooLarge =>
      'Attached File Size Exceeded Allowed Size Limit';

  @override
  String get mailboxFileBadType => 'Attached File Type is Invalid.';

  @override
  String get mailboxSentSuccess => 'Your message has been sent successfully.';

  @override
  String get mailboxUploadFailed => 'The file could not be attached.';

  @override
  String get mailboxRemoveFile => 'Remove';

  @override
  String get mailboxPickFailed => 'The file could not be opened.';

  @override
  String get calcTitle => 'Calculators';

  @override
  String get calcTd => 'Term Deposit Calculator';

  @override
  String get calcLoanInstallment => 'Loan Installment Calculator';

  @override
  String get calcLoanEligibility => 'Loan Eligibility Calculator';

  @override
  String get calcForex => 'Forex Calculator';

  @override
  String get calcDepositAmount => 'Deposit Amount';

  @override
  String get calcDepositTenure => 'Deposit Tenure';

  @override
  String get calcYears => 'Years';

  @override
  String get calcMonths => 'Months';

  @override
  String get calcDays => 'Days';

  @override
  String get calcInterestRate => 'Interest Rate';

  @override
  String get calcMaturityAmount => 'Maturity Amount';

  @override
  String get calcEnterValidValue => 'Enter a Valid Value';

  @override
  String get calcEnterValidInterest => 'Please enter valid Interest';

  @override
  String get calcLoanAmount => 'Loan Amount';

  @override
  String get calcLoanTenureYears => 'Loan Tenure (In Years)';

  @override
  String get calcInstallmentAmount => 'Installment Amount';

  @override
  String get calcGrossIncome => 'Gross Income (Monthly)';

  @override
  String get calcTotalExpenses => 'Total Expenses (Monthly)';

  @override
  String get calcInterestRateIn => 'Interest Rate (In %)';

  @override
  String get calcEligibleAmount => 'Eligible Amount';

  @override
  String get calcAverageInstallment => 'Average Installment';

  @override
  String calcPerMonth(String amount) {
    return '$amount / Month';
  }

  @override
  String get calcExpensesHigh =>
      'Your monthly expenses seem to be higher than your monthly income. Please modify the values to recalculate loan eligibility.';

  @override
  String get calcFromCurrency => 'From Currency';

  @override
  String get calcToCurrency => 'To Currency';

  @override
  String get calcForeignCurrency => 'Foreign Currency';

  @override
  String get calcAmount => 'Amount';

  @override
  String calcRate(String from, String rate, String to) {
    return '@1 $from = $rate $to';
  }

  @override
  String get calcSelectCurrency => 'Please Select Currency';

  @override
  String get calcValidAmount => 'Please enter a valid amount';

  @override
  String get calcHubSubtitle => 'Plan deposits, loans and currency exchange';

  @override
  String get calcTdDesc => 'What your deposit will be worth at maturity';

  @override
  String get calcLoanInstallmentDesc =>
      'Your installment for a loan amount and tenure';

  @override
  String get calcLoanEligibilityDesc =>
      'How much you may borrow from your income';

  @override
  String get calcForexDesc => 'Convert an amount between currencies';

  @override
  String get calcLoadFailed => 'The calculator could not be loaded.';

  @override
  String get calcFailed => 'The result could not be calculated.';

  @override
  String calcRangeHint(String min, String max) {
    return 'Between $min and $max';
  }

  @override
  String get calcDecrease => 'Decrease';

  @override
  String get calcIncrease => 'Increase';

  @override
  String get prefTitle => 'My Preferences';

  @override
  String get prefGroupAccount => 'Account';

  @override
  String get prefGroupSecurity => 'Security & Privacy';

  @override
  String get prefGroupApp => 'App';

  @override
  String get prefLimitsControls => 'Limits & Controls';

  @override
  String get prefPrivacyConsents => 'Privacy & Consents';

  @override
  String get prefNotificationsAlerts => 'Notifications & Alerts';

  @override
  String get prefAppearanceLanguage => 'Appearance & Language';

  @override
  String get prefDevices => 'Devices';

  @override
  String get prefProfileHint => 'Personal and contact details';

  @override
  String get prefPrimaryAccountHint => 'The account used by default';

  @override
  String get prefLimitsHint => 'Daily and monthly transaction limits';

  @override
  String get prefSecurityHint =>
      'Biometric login, security questions, soft token, devices';

  @override
  String get prefPrivacyHint => 'Third party apps, feedback and Live Help';

  @override
  String get prefNotificationsHint => 'Push notifications and OTP delivery';

  @override
  String get prefAppearanceHint => 'Theme, colours and language';

  @override
  String get prefPersonalizeHint => 'Choose and arrange your dashboard widgets';

  @override
  String prefUserId(String id) {
    return 'User ID: $id';
  }

  @override
  String prefLastLogin(String when) {
    return 'Last login $when';
  }

  @override
  String get moreGroupServices => 'Services';

  @override
  String get moreGroupDiscover => 'Discover';

  @override
  String get moreGroupHelp => 'Help';

  @override
  String get prefProfile => 'Profile';

  @override
  String get prefPrimaryAccount => 'Primary Account Number';

  @override
  String get prefThirdPartyApps => 'Third Party Applications';

  @override
  String get prefSecurityLogin => 'Security & Login';

  @override
  String get prefLoadFailed => 'Your preferences could not be loaded.';

  @override
  String get prefSaveFailed => 'That could not be saved. Please try again.';

  @override
  String get prefOtpTitle => 'Verify to continue';

  @override
  String get prefOtpInvalid => 'That code is not right. Please try again.';

  @override
  String get prefPendingApproval => 'Sent for approval.';

  @override
  String get prefReview => 'Review';

  @override
  String get prefBack => 'Back';

  @override
  String get prefCancel => 'Cancel';

  @override
  String get prefSubmit => 'Submit';

  @override
  String get prefSave => 'Save';

  @override
  String get prefEdit => 'Edit';

  @override
  String get prefConfirm => 'Confirm';

  @override
  String get prefOk => 'Ok';

  @override
  String get prefApply => 'Apply';

  @override
  String get prefSuccess => 'Success';

  @override
  String get prefStatus => 'Status';

  @override
  String get prefStatusSuccessful => 'Successful';

  @override
  String get prefMessage => 'Message';

  @override
  String get prefPersonalInfo => 'Personal Information';

  @override
  String get prefContactInfo => 'Contact Information';

  @override
  String get prefDateOfBirth => 'Date of Birth';

  @override
  String get prefDownload => 'Download';

  @override
  String get prefDownloadFailed => 'The file could not be downloaded.';

  @override
  String prefEditField(String value) {
    return 'Edit $value';
  }

  @override
  String get prefUpdateProfile => 'Update Profile';

  @override
  String get prefProfileUpdated =>
      'Your details have been updated successfully!!';

  @override
  String get prefEmailUpdated =>
      'Your details have been updated successfully! To ensure that you receive your e-statements on the updated email ID, please unsubscribe and re-subscribe for the required e-statements.';

  @override
  String get prefAreaCode => 'Area Code';

  @override
  String get prefNumber => 'Number';

  @override
  String get prefLine1 => 'Line 1';

  @override
  String get prefLine2 => 'Line 2';

  @override
  String get prefLine3 => 'Line 3';

  @override
  String get prefCity => 'City';

  @override
  String get prefCountry => 'Country';

  @override
  String get prefSelectCountry => 'Select Country';

  @override
  String get prefZipCode => 'Zip Code';

  @override
  String get prefContactAttribute => 'Contact Attribute';

  @override
  String get prefInvalidNumber => 'Enter valid number';

  @override
  String get prefInvalidMobile => 'Enter valid mobile number';

  @override
  String get prefInvalidFax => 'Enter valid fax number';

  @override
  String get prefInvalidAddress => 'Enter valid address';

  @override
  String get prefInvalidCity => 'Enter only alphabets characters';

  @override
  String get prefInvalidZip => 'Invalid Zip Code';

  @override
  String get prefInvalidEmail => 'Invalid Email';

  @override
  String prefInvalidId(String id) {
    return 'Enter valid $id';
  }

  @override
  String prefIdTooLong(String id) {
    return '$id must be less than or equal to 20 characters';
  }

  @override
  String get prefSelectPrimaryAccount => 'Select Primary Account';

  @override
  String get prefSelect => 'Select';

  @override
  String get prefAccountTypeAndNumber => 'Account Type And Number';

  @override
  String get prefPartyName => 'Party Name';

  @override
  String get prefNickName => 'Nick Name';

  @override
  String get prefCurrentAccount => 'Current Account';

  @override
  String get prefSavingAccount => 'Saving Account';

  @override
  String get prefWalletAccount => 'Wallet Account';

  @override
  String get prefNoAccounts => 'No accounts available.';

  @override
  String get prefNoPrimaryWish => 'If you do not wish to set a primary account';

  @override
  String get prefClearSelection => 'Clear Selection';

  @override
  String get prefPrimarySaved => 'Primary account saved successfully !!';

  @override
  String get prefPrimaryCleared =>
      'Primary account selection cleared successfully !!';

  @override
  String get prefNoAccountSelected =>
      'No account selected. Please select an account to be marked as primary.';

  @override
  String get prefApplicationAccess => 'Application Access';

  @override
  String get prefGranted => 'Granted';

  @override
  String get prefRevoked => 'Revoked';

  @override
  String get prefCurrentAndSavings => 'Current & Savings';

  @override
  String get prefTermDeposits => 'Term Deposits';

  @override
  String get prefLoans => 'Loans';

  @override
  String get prefMapAllTransactions => 'Map All Transactions';

  @override
  String get prefTaskObInquiries => 'Open Banking Account Inquiries';

  @override
  String get prefTaskObPayments => 'Open Banking Payments';

  @override
  String get prefNoConsentAccounts => 'No accounts available.';

  @override
  String get prefNoThirdPartyApps =>
      'You don\'t have any active third party applications to manage.';

  @override
  String get prefConsentReview =>
      'You initiated a request for Third Party Consents. Please review details before you confirm!';

  @override
  String get prefConsentSuccess =>
      'Third party consents initiated successfully.';

  @override
  String get prefSetSecurityQuestion => 'Set Security Question';

  @override
  String get prefSoftToken => 'Soft Token Authentication';

  @override
  String get prefSmsMissedCall => 'SMS and Missed Call Banking';

  @override
  String get prefSmsChatbot => 'SMS and Chatbot Banking';

  @override
  String get prefManageBiometric => 'Manage Touch ID / Face ID';

  @override
  String get prefSecurityQuestion => 'Security Question';

  @override
  String get prefUserSecurityQuestions => 'User Security Questions';

  @override
  String get prefQuestionsNotSetUp =>
      'User Security Questions have not been setup yet.';

  @override
  String get prefSetUpNow => 'Set up now';

  @override
  String get prefSelectQuestion => 'Select Question';

  @override
  String get prefAnswer => 'Answer';

  @override
  String get prefQuestion => 'Question';

  @override
  String get prefInvalidAnswer => 'Invalid answer.';

  @override
  String get prefDuplicateQuestions =>
      'Duplicate questions selected. Please select different questions';

  @override
  String get prefSecurityQuestionReview =>
      'You initiated a request for User Security Question. Please review details before you confirm!';

  @override
  String get prefRequestInitiated =>
      'Your request has been initiated successfully.';

  @override
  String prefRequestInitiatedRef(String referenceNo) {
    return 'Your request has been initiated successfully. Reference Number is $referenceNo.';
  }

  @override
  String get prefChooseAuthenticator => 'Choose Authenticator Type';

  @override
  String get prefOracleAuthenticator => 'Oracle Mobile Authenticator';

  @override
  String get prefOtherAuthenticator => 'Other Mobile Authenticator';

  @override
  String get prefCantScan => 'Can\'t scan? Copy the key.';

  @override
  String get prefKeyCopied => 'Key copied';

  @override
  String get prefMissedCallBanking => 'Missed Call Banking';

  @override
  String get prefSmsBanking => 'SMS Banking';

  @override
  String get prefSetResetPin => 'Set/Reset Pin';

  @override
  String get prefSetPin => 'Set Pin';

  @override
  String get prefConfirmPin => 'Confirm Pin';

  @override
  String get prefPinNumeric => 'Pin can only be numeric.';

  @override
  String get prefPinMismatch => 'Pin did not match.';

  @override
  String get prefPinSetUp => 'Pin has been successfully setup.';

  @override
  String get prefThemesIntro =>
      'Select a theme to change the look of the application';

  @override
  String get prefSwitchDefaultTheme => 'Switch to Default Theme';

  @override
  String get prefCurrentTheme => 'Current';

  @override
  String get prefThemeApplied => 'Theme applied.';

  @override
  String get prefPreviewPageTitle => 'Page Title';

  @override
  String get prefPreviewBody => 'Body and information text';

  @override
  String get prefPreviewPrimary => 'Primary';

  @override
  String get prefPreviewSecondary => 'Secondary';

  @override
  String get prefRegisteredDevices => 'Registered Phones/Tablets';

  @override
  String get prefRegisteredDevicesNote =>
      'Note: Unregistering will disable alternate login from all mobile devices.';

  @override
  String get prefRegisteredWearable => 'Registered Wearable';

  @override
  String get prefRegisteredWearableNote =>
      'Note: Unregistering will disable alternate login from all wearable devices.';

  @override
  String get prefAndroidDevices => 'Android Devices';

  @override
  String get prefIosDevices => 'iOS Devices';

  @override
  String get prefWebBrowser => 'Web Browser';

  @override
  String get prefPushNotification => 'Push Notification';

  @override
  String get prefPushNotificationNote =>
      'Note: Disabling the service will unregister the device from receiving alerts via push notifications.';

  @override
  String get prefFeedbackPreferences => 'Feedback Preferences';

  @override
  String get prefFeedbackNote =>
      'Note : Disabling this will disable the feedback window after every transaction.';

  @override
  String get prefLiveHelp => 'Live Help';

  @override
  String get prefLiveHelpNote =>
      'Note : Disabling this will disable the oracle live feature.';

  @override
  String get prefOtpDeliveryMode => 'Preferred Delivery Mode (Only for OTP)';

  @override
  String get prefDispatchMethod => 'Dispatch Method';

  @override
  String get prefSms => 'SMS';

  @override
  String get prefEmail => 'Email';

  @override
  String get prefBoth => 'Both';

  @override
  String get prefOtpDeliveryNote =>
      'Note: The above configured dispatch method is applicable only if OTP is set up as the transaction authentication mode by the bank.';
}
