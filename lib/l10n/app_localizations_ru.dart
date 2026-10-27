// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Demo Bank';

  @override
  String get brandName => 'UBCI';

  @override
  String get welcome => 'Добро пожаловать!';

  @override
  String get welcomeBack => 'С возвращением!';

  @override
  String get loginSubtitle => 'Введите имя пользователя и пароль для входа';

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
  String get username => 'Имя пользователя';

  @override
  String get password => 'Пароль';

  @override
  String get enterUsername => 'Введите имя пользователя';

  @override
  String get enterPassword => 'Введите пароль';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get forgotUsername => 'Забыли имя пользователя?';

  @override
  String get forgotUsernameOrPassword => 'Забыли имя пользователя или пароль?';

  @override
  String get forgotUsernameTitle => 'Забыли имя пользователя';

  @override
  String get forgotPasswordTitle => 'Забыли пароль';

  @override
  String get forgotUsernameSubtitle =>
      'Чтобы получить имя пользователя, введите адрес электронной почты и дату рождения, зарегистрированные в вашем банковском счёте.';

  @override
  String get forgotPasswordSubtitle =>
      'Ничего страшного. Просто введите данные ниже.';

  @override
  String get forgotEmailLabel => 'Электронная почта';

  @override
  String get forgotEmailHint => 'Enter email';

  @override
  String get forgotEmailRequired => 'Обязательно';

  @override
  String get forgotUserNameLabel => 'Имя пользователя';

  @override
  String get forgotUserNameHint => 'Enter username';

  @override
  String get forgotUserNameRequired => 'Обязательно';

  @override
  String get forgotDateOfBirthLabel => 'Дата рождения';

  @override
  String get forgotDateOfBirthHint => 'Select date of birth';

  @override
  String get forgotDateOfBirthRequired => 'Обязательно';

  @override
  String get forgotSubmit => 'Отправить';

  @override
  String get forgotOtpTitle => 'Одноразовая проверка';

  @override
  String get forgotOtpSubtitle =>
      'Код подтверждения отправлен на зарегистрированный номер телефона. Введите его ниже, чтобы завершить процесс.';

  @override
  String get forgotNoteHeading => 'Примечание';

  @override
  String get forgotNoteQuestion => 'Не можете вспомнить имя пользователя?';

  @override
  String get forgotNoteBody =>
      'Просто введите зарегистрированный email и подтвердите личность, чтобы получить ID пользователя на почту.';

  @override
  String get forgotNoteSupport =>
      'Если вы не можете восстановить ID пользователя, посетите ближайшее отделение или обратитесь в службу поддержки.';

  @override
  String get forgotPasswordNoteQuestion => 'Not able to recall your Password?';

  @override
  String get forgotPasswordNoteBody =>
      'Simply enter your User Name and date of birth registered in your bank account to receive a password reset link on your email.';

  @override
  String get forgotPasswordNoteSupport =>
      'In case you are unable to recover your Password, please visit our nearest branch or contact and speak to our customer care executive.';

  @override
  String get forgotSuccessHeading => 'Успешно';

  @override
  String get forgotUsernameSuccessMessage =>
      'Восстановленное имя пользователя успешно отправлено на зарегистрированный email.';

  @override
  String get forgotPasswordSuccessMessage =>
      'Ссылка для создания нового пароля успешно отправлена на ваш email';

  @override
  String get forgotGoToLogin => 'Войти в банковский счёт';

  @override
  String otpReferenceNumber(String reference) {
    return 'Номер ссылки: $reference';
  }

  @override
  String get login => 'Войти';

  @override
  String get loggingIn => 'Выполняется вход...';

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
  String get help => 'Помощь';

  @override
  String get loginHelpTitle => 'Нужна помощь со входом?';

  @override
  String get loginHelpSubtitle => 'Краткие подсказки для экрана входа';

  @override
  String get loginHelpBody =>
      'Введите имя пользователя и пароль, зарегистрированные в вашем банковском счёте.\n\nЕсли вы забыли имя пользователя или пароль, воспользуйтесь ссылками под формой входа, чтобы восстановить их.\n\nВы можете оставаться в системе на доверенных устройствах. В веб-версии используйте значок виртуальной клавиатуры для безопасного ввода.\n\nЗа дополнительной помощью обратитесь в ближайшее отделение или в службу поддержки клиентов.';

  @override
  String get loginHelpClose => 'Понятно';

  @override
  String get virtualKeyboard => 'Виртуальная клавиатура';

  @override
  String get virtualKeyboardDone => 'Готово';

  @override
  String get virtualKeyboardSpace => 'Пробел';

  @override
  String get virtualKeyboardShuffle => 'Перемешать клавиши';

  @override
  String get virtualKeyboardClear => 'Очистить';

  @override
  String get notRegistered => 'Не зарегистрированы? ';

  @override
  String get registerHere => 'Зарегистрируйтесь здесь';

  @override
  String get pleaseEnterCredentials => 'Введите имя пользователя и пароль';

  @override
  String get overview => 'Обзор';

  @override
  String get accounts => 'Счета';

  @override
  String get cards => 'Карты';

  @override
  String get deposit => 'Депозит';

  @override
  String get home => 'Главная';

  @override
  String get insights => 'Аналитика';

  @override
  String get rewards => 'Награды';

  @override
  String get more => 'Ещё';

  @override
  String get transfer => 'Перевод';

  @override
  String get scan => 'Сканировать';

  @override
  String get scanAndPay => 'Scan & pay';

  @override
  String get payBill => 'Оплатить счёт';

  @override
  String get goodMorning => 'Доброе утро';

  @override
  String get goodMorningComma => 'Good Morning,';

  @override
  String get totalBalance => 'ОБЩИЙ БАЛАНС';

  @override
  String get moreTitle => 'Ещё';

  @override
  String get theme => 'Тема';

  @override
  String get lightTheme => 'Светлая';

  @override
  String get darkTheme => 'Тёмная';

  @override
  String get colorTheme => 'Цветовая тема';

  @override
  String get paletteCyan => 'Бирюзовая';

  @override
  String get paletteOrange => 'Оранжевая';

  @override
  String get paletteIndigo => 'Индиго';

  @override
  String get language => 'Язык';

  @override
  String get english => 'Английский';

  @override
  String get arabic => 'Арабский';

  @override
  String get french => 'Французский';

  @override
  String get italian => 'Итальянский';

  @override
  String get uzbek => 'Узбекский';

  @override
  String get russian => 'Русский';

  @override
  String get security => 'Безопасность';

  @override
  String get logOut => 'Выйти';

  @override
  String get forgetDevice => 'Забыть устройство';

  @override
  String get logOutConfirm => 'Выйти из этой сессии на этом устройстве?';

  @override
  String get logOutConfirmWithBiometric =>
      'Sign out of this session on this device?\n\nYou will lose biometric login and will need to set it up again after you sign in.';

  @override
  String get forgetDeviceConfirm =>
      'Удалить все сохранённые данные сессии с этого устройства? Потребуется повторный вход.';

  @override
  String get cancel => 'Отмена';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get deviceBlockedTitle => 'Устройство не поддерживается';

  @override
  String get deviceBlockedCompromisedMessage =>
      'В целях безопасности это приложение не может работать на изменённых или скомпрометированных устройствах. Используйте стандартное неизменённое устройство.';

  @override
  String get deviceBlockedEmulatorMessage =>
      'В целях безопасности это приложение не может работать на эмуляторах или симуляторах в production-сборках.';

  @override
  String get deviceBlockedSupport =>
      'Если вы считаете, что это ошибка, обратитесь в службу поддержки банка.';

  @override
  String get deviceSecurityWarnCompromised =>
      'Предупреждение безопасности: это устройство может быть изменено. Действуйте с осторожностью.';

  @override
  String get deviceSecurityWarnEmulator =>
      'Предупреждение безопасности: вы используете эмулятор или симулятор.';

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
      'В целях безопасности вы вышли из системы. Войдите снова.';

  @override
  String get sessionExpiredTitle => 'Сессия истекла';

  @override
  String get sessionExpiredSignIn => 'Войти';

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
      'Не удалось загрузить счета. Попробуйте ещё раз.';

  @override
  String get accountsEmpty => 'Счета недоступны.';

  @override
  String get accountsRetry => 'Повторить';

  @override
  String get accountStatusActive => 'Активен';

  @override
  String get accountStatusDormant => 'Неактивен';

  @override
  String get accountsMultipleCurrencies => 'Остатки показаны по валютам';

  @override
  String get availableBalanceLabel => 'Доступный остаток';

  @override
  String get errorLoansLoadFailed =>
      'Не удалось загрузить кредиты. Попробуйте ещё раз.';

  @override
  String get loansEmpty => 'Нет доступных кредитов.';

  @override
  String get loanTrackerTitle => 'Трекер кредитов';

  @override
  String get loanTotalBorrowing => 'Общая сумма займа';

  @override
  String get loanTotalOutstanding => 'Общая задолженность';

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
      'Не удалось загрузить сведения о счёте. Попробуйте ещё раз.';

  @override
  String get errorTransactionsLoadFailed =>
      'Не удалось загрузить операции. Попробуйте ещё раз.';

  @override
  String get casaAccountDetailsTitle =>
      'Сведения о текущем и сберегательном счёте';

  @override
  String get casaAccountDetailsTitleWeb =>
      'СВЕДЕНИЯ О ТЕКУЩЕМ И СБЕРЕГАТЕЛЬНОМ СЧЁТЕ';

  @override
  String get casaAccountNumberLabel => 'Номер счёта';

  @override
  String get casaCurrentBalance => 'Текущий остаток';

  @override
  String get casaProductName => 'Название продукта';

  @override
  String get casaNickName => 'Псевдоним';

  @override
  String get casaNotAssigned => 'Не назначено';

  @override
  String get casaNotRegistered => 'Не зарегистрирован';

  @override
  String get casaBalanceDetails => 'Сведения об остатке';

  @override
  String get casaTodaysOpeningBalance => 'Входящий остаток на сегодня';

  @override
  String get casaAvailableBalance => 'Доступный остаток';

  @override
  String get casaAmountOnHold => 'Сумма в холде';

  @override
  String get casaUnderFunds => 'Средства в обработке';

  @override
  String get casaAdvanceAgainstUnclearFunds =>
      'Лимит аванса по нерассчитанным средствам';

  @override
  String get casaOverdraftLimit => 'Лимит овердрафта';

  @override
  String get casaSweepInAmount => 'Сумма sweep-in';

  @override
  String get casaGeneralDetails => 'Общие сведения';

  @override
  String get casaHoldingPattern => 'Форма владения';

  @override
  String get casaPrimaryAccountHolder => 'Основной владелец счёта';

  @override
  String get casaNominee => 'Номинант';

  @override
  String get casaBranch => 'Отделение';

  @override
  String get casaViewTransactions => 'Смотреть операции';

  @override
  String get casaTransactionsTitle => 'Операции';

  @override
  String get casaTransactionsTitleWeb => 'ОПЕРАЦИИ';

  @override
  String get casaOpeningBalance => 'Входящий остаток';

  @override
  String get casaClosingBalance => 'Исходящий остаток';

  @override
  String get casaTransactionsEmpty => 'Операции не найдены.';

  @override
  String get casaSearchForAmount => 'Search for amount';

  @override
  String get casaRecentTransactions => 'Недавние операции';

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
    return 'Страница $page из $pageCount · Всего операций: $total';
  }

  @override
  String casaTransactionRef(String reference) {
    return 'Реф.: $reference';
  }

  @override
  String get casaDownloadStatement => 'Скачать выписку';

  @override
  String get casaStatementDownloadSuccess => 'Выписка скачана.';

  @override
  String get casaStatementDownloadFailed =>
      'Не удалось скачать выписку. Попробуйте ещё раз.';

  @override
  String get casaFilterViewOptions => 'Параметры просмотра';

  @override
  String get casaFilterTransactions => 'Операции';

  @override
  String get casaFilterAll => 'Все';

  @override
  String get casaFilterCreditsOnly => 'Только зачисления';

  @override
  String get casaFilterDebitsOnly => 'Только списания';

  @override
  String get casaFilterAmount => 'Сумма';

  @override
  String get casaFilterFromAmount => 'Сумма от';

  @override
  String get casaFilterToAmount => 'Сумма до';

  @override
  String get casaFilterDate => 'Дата';

  @override
  String get casaFilterFromDate => 'Дата с';

  @override
  String get casaFilterToDate => 'Дата по';

  @override
  String get casaFilterReferenceNumber => 'Номер ссылки';

  @override
  String get casaFilterApply => 'Применить';

  @override
  String get casaFilterReset => 'Сбросить';

  @override
  String get casaViewCurrentMonth => 'Текущий месяц';

  @override
  String get casaViewCurrentDay => 'Текущий день';

  @override
  String get casaViewPreviousDay => 'Предыдущий день';

  @override
  String get casaViewDateRange => 'Диапазон дат';

  @override
  String get casaViewSpecificDay => 'Определённый день';

  @override
  String get casaViewPreviousMonth => 'Предыдущий месяц';

  @override
  String get casaViewPreviousQuarter => 'Предыдущий квартал';

  @override
  String get casaViewLast10 => 'Последние 10 транзакций';

  @override
  String get casaViewCurrentAndPreviousMonth => 'Текущий и предыдущий месяц';

  @override
  String get casaTxnTypeCredit => 'Зачисление';

  @override
  String get casaTxnTypeDebit => 'Списание';

  @override
  String get casaColTxnDate => 'Дата операции';

  @override
  String get casaColValueDate => 'Дата валютирования';

  @override
  String get casaColDescription => 'Описание';

  @override
  String get casaColReference => 'Номер ссылки';

  @override
  String get casaColType => 'Тип операции';

  @override
  String get casaColAmount => 'Сумма';

  @override
  String get casaColBalance => 'Остаток';

  @override
  String get casaStatementPasswordTitle => 'Комбинация пароля';

  @override
  String get casaStatementPasswordBody =>
      'Скачанная выписка защищена паролем. Пароль — первые 4 буквы вашего имени заглавными и дата рождения в формате ДДММ.';

  @override
  String get casaStatementPasswordExample1 =>
      'Пример: имя Roopa Lal, дата рождения 23-12-1980 → ROOP2312.';

  @override
  String get casaStatementPasswordExample2 =>
      'Если в имени меньше 4 букв, недостающие берутся из фамилии. Пример: Joy Matthew, 01-01-1980 → JOYM0101.';

  @override
  String get casaStatementPasswordContinue => 'Скачать';

  @override
  String get errorInvalidRequest => 'Invalid request. Please check your input.';

  @override
  String get errorOtpInvalid =>
      'The verification code is incorrect. Please try again.';

  @override
  String get errorBiometricAccessPoint =>
      'Быстрый мобильный доступ не включён для вашей учётной записи. Попросите банк включить точку доступа мобильного приложения.';

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
      other: 'Осталось повторных отправок: $count',
      one: 'Осталась 1 повторная отправка',
      zero: 'Повторных отправок не осталось',
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
  String get biometricEnableLogin => 'Включить биометрический вход';

  @override
  String get biometricEnableLoginHelper =>
      'Используйте отпечаток пальца или разблокировку по лицу для быстрого входа.';

  @override
  String get biometricEnableFaceId => 'Включить Face ID';

  @override
  String get biometricEnableTouchId => 'Включить Touch ID';

  @override
  String get biometricNotEnrolledTitle =>
      'Биометрическая разблокировка не настроена';

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
  String get hostReferenceNumber => 'Номер ссылки хоста';

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
  String get lfwEnterAnswer => 'Answer';

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
  String get lfwTermsTitle => 'Terms & Conditions';

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
  String get forgotSecurityQuestionsTitle => 'Контрольные вопросы';

  @override
  String get forgotSecurityQuestionsSubtitle =>
      'Ответьте на контрольные вопросы, чтобы продолжить.';

  @override
  String get forgotSecurityAnswerLabel => 'Ответ';

  @override
  String get forgotSecurityAnswerRequired => 'Введите ответ';

  @override
  String get errorSecurityAnswersInvalid =>
      'Один или несколько ответов неверны. Попробуйте ещё раз.';

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
  String get ccShowDetails => 'Show card details';

  @override
  String get ccHideDetails => 'Hide card details';

  @override
  String get ssTitle => 'Session Summary';

  @override
  String get ssHint => 'Every sign-in and what was done in it';

  @override
  String get ssStartDateTime => 'Start Date & Time';

  @override
  String get ssEndDateTime => 'End Date & Time';

  @override
  String get ssChannel => 'Channel';

  @override
  String get ssIpAddress => 'IP Address';

  @override
  String get ssTransactionName => 'Transaction Name';

  @override
  String get ssStatus => 'Status';

  @override
  String get ssTransactionDateTime => 'Transaction Date & Time';

  @override
  String get ssSuccess => 'Success';

  @override
  String get ssFailure => 'Failure';

  @override
  String get ssEmpty => 'No sessions to show.';

  @override
  String get ssNoActivity => 'Nothing was done in this session.';

  @override
  String get ssToggleDetails => 'Show or hide what was done in this session';

  @override
  String get ssChannelInternet => 'Internet';

  @override
  String get ssChannelMobileResponsive => 'Mobile (Responsive)';

  @override
  String get ssChannelChatbot => 'Siri/Chatbot';

  @override
  String get ssChannelWearables => 'Wearables';

  @override
  String get ssChannelMobileApp => 'Mobile Application';

  @override
  String get ssChannelMobileBrowser => 'Mobile Web Browser';

  @override
  String get ssChannelDesktopBrowser => 'Desktop Web Browser';

  @override
  String get ssChannelSoftToken => 'Soft Token Application';

  @override
  String get ssChannelUnknown => 'Unknown';

  @override
  String get cpTitle => 'Change Password';

  @override
  String get cpHint => 'Set a new sign-in password';

  @override
  String get cpIntro => 'Please change your password for security reasons.';

  @override
  String get cpCurrent => 'Enter Current Password';

  @override
  String get cpCurrentHint => 'Enter current password';

  @override
  String get cpNew => 'Enter New Password';

  @override
  String get cpNewHint => 'Enter new password';

  @override
  String get cpConfirm => 'Confirm New Password';

  @override
  String get cpConfirmHint => 'Confirm new password';

  @override
  String get cpEnterValue => 'Enter a value.';

  @override
  String get cpDifferentPassword => 'Please enter a different Password';

  @override
  String get cpPasswordsMatch => 'The Password must match!';

  @override
  String get cpRequirements => 'Password requirements';

  @override
  String get cpRequirementsNote =>
      'All requirements must be satisfied before Submit.';

  @override
  String get cpRulesIntro => 'Your new password must meet every rule below.';

  @override
  String cpRuleLength(int min, int max) {
    return 'Have $min to $max characters';
  }

  @override
  String get cpRuleUpper => 'Have uppercase';

  @override
  String get cpRuleLower => 'Have lowercase';

  @override
  String get cpRuleNumber => 'Have numbers';

  @override
  String get cpRuleSpecial => 'Have special characters';

  @override
  String cpMinimumMandatory(int count) {
    return '(Minimum $count mandatory)';
  }

  @override
  String get cpNotAllowed => '(Not Allowed)';

  @override
  String cpAllowedChars(String chars) {
    return '(allowed: $chars)';
  }

  @override
  String cpRuleSuccessive(int count) {
    return 'Not contain successive characters more than $count';
  }

  @override
  String cpRuleRepeated(int count) {
    return 'Not contain repetitive characters more than $count';
  }

  @override
  String get cpRuleCommon => 'Not be a common password';

  @override
  String cpRuleHistory(int count) {
    return 'Not be one of your most recent $count password(s).';
  }

  @override
  String get cpSecurityTip => 'Security tip';

  @override
  String get cpSecurityTipText =>
      'Never share your password. Use a unique password and avoid reusing it on other services.';

  @override
  String get cpSuccessTitle => 'Password Changed Successfully!';

  @override
  String get cpSuccessMessage => 'Please click below to Login';

  @override
  String get cpLogin => 'Login';

  @override
  String get asTitle => 'Alerts Subscription';

  @override
  String get asHint => 'Choose how each alert reaches you';

  @override
  String get asPartyId => 'Party Id';

  @override
  String get asPartyName => 'Party Name';

  @override
  String get asUserName => 'User Name';

  @override
  String get asStatus => 'Status';

  @override
  String get asActive => 'Active';

  @override
  String get asInactive => 'Inactive';

  @override
  String get asCopyPartyId => 'Copy Party Id';

  @override
  String get asCopied => 'Copied';

  @override
  String get asSelectModule => 'Select Module';

  @override
  String get asSelectParty => 'Select Party';

  @override
  String get asSearchParty => 'Search Party';

  @override
  String get asApply => 'Apply';

  @override
  String get asSubscribeModes => 'Subscribe Alert Modes';

  @override
  String get asMapAllModes => 'Map All Modes';

  @override
  String get asMapAllModesHint => 'Apply the same channels to every alert';

  @override
  String get asPush => 'Push Notification';

  @override
  String get asSms => 'SMS';

  @override
  String get asOnScreen => 'On Screen';

  @override
  String get asEmail => 'Email';

  @override
  String get asSubscribed => 'Subscribed';

  @override
  String get asSelectPartyFirst => 'Select a party, then Apply.';

  @override
  String get asApplyHint =>
      'Select a party and press Apply to see and change its alerts.';

  @override
  String get asNoParties => 'No accounts to choose from.';

  @override
  String get asNoModules => 'No alerts are available to subscribe to.';

  @override
  String get asNoAlerts => 'This module has no alerts to subscribe to.';

  @override
  String get asSaved => 'Alert subscription saved.';

  @override
  String get srRaiseTicket => 'Raise a New Ticket';

  @override
  String get srSearchRequests => 'Search service requests';

  @override
  String get srNoRequestsMatch =>
      'No request matches the selected search criteria.';

  @override
  String get srChangeFilters => 'Change filters';

  @override
  String get fcTitle => 'Financial Calculator';

  @override
  String get fcTabTd => 'Term Deposit';

  @override
  String get fcTabLoanInstallment => 'Loan Installment';

  @override
  String get fcTabLoanEligibility => 'Loan Eligibility';

  @override
  String get fcTabForex => 'Forex';

  @override
  String get fcTdTitle => 'Term Deposit Calculator';

  @override
  String get fcTdSubtitle =>
      'Calculate maturity value once deposit amount and rate are entered.';

  @override
  String get fcLoanInstallmentTitle => 'Loan Installment Calculator';

  @override
  String get fcLoanInstallmentSubtitle =>
      'Calculate the monthly installment once amount, tenure and rate are entered.';

  @override
  String get fcLoanEligibilityTitle => 'Loan Eligibility Calculator';

  @override
  String get fcLoanEligibilitySubtitle =>
      'Use income and expenses to estimate repayment capacity.';

  @override
  String get fcEnterValue => 'Enter value';

  @override
  String get fcInterest => 'Interest';

  @override
  String get fcMonthlyInstallment => 'Calculated monthly installment';

  @override
  String get fcTotalRepayment => 'Total repayment';

  @override
  String get fcDisposableIncome => 'Calculated monthly disposable income';

  @override
  String get fcEligibilityNote =>
      'Loan eligibility amount requires lender-specific policy.';

  @override
  String get fcFrom => 'From';

  @override
  String get fcTo => 'To';

  @override
  String get fcCurrency => 'Currency';

  @override
  String get fcConvertedAmount => 'Converted amount';

  @override
  String get srTitle => 'Service Requests';

  @override
  String get srTrackRequests => 'Track Requests';

  @override
  String get srTrackRequest => 'Track Request';

  @override
  String get srRaiseNew => 'Raise a New Request';

  @override
  String get srRaiseAnother => 'Raise Another Request';

  @override
  String get srLoadFailed => 'Service requests could not be loaded.';

  @override
  String get srFilter => 'Filter';

  @override
  String get srProductName => 'Product Name';

  @override
  String get srCategoryName => 'Category Name';

  @override
  String get srFromDate => 'From Date';

  @override
  String get srToDate => 'To Date';

  @override
  String get srStatus => 'Status';

  @override
  String get srPleaseSelect => 'Please Select';

  @override
  String get srApply => 'Apply';

  @override
  String get srReset => 'Reset';

  @override
  String get srDateRequired => 'Enter both From Date and To Date.';

  @override
  String get srToBeforeFrom => 'To Date cannot be before From Date.';

  @override
  String get srDateRange90 => 'To Date must be within 90 days of From Date.';

  @override
  String get srAllRequests => 'All requests';

  @override
  String get srNoRequests => 'No Service Request Found';

  @override
  String srShowMore(int count) {
    return 'Show $count more';
  }

  @override
  String get srDate => 'Date';

  @override
  String get srRequestName => 'Request Name';

  @override
  String get srReferenceNumber => 'Reference Number';

  @override
  String get srStatusPending => 'Pending';

  @override
  String get srStatusDelivered => 'Delivered';

  @override
  String get srStatusCompleted => 'Completed';

  @override
  String get srStatusRejected => 'Rejected';

  @override
  String get srStatusInitiated => 'Initiated';

  @override
  String get srStatusInProgress => 'In-progress';

  @override
  String get srStatusRequested => 'Requested';

  @override
  String get srStatusClosed => 'Closed';

  @override
  String get srStatusReturned => 'Returned';

  @override
  String get srStatusDispatched => 'Dispatched';

  @override
  String get srStatusIssued => 'Issued';

  @override
  String get srStatusAccepted => 'Accepted';

  @override
  String get srDetails => 'Details';

  @override
  String get srRequestDetails => 'Request Details';

  @override
  String get srRequestFor => 'Request For';

  @override
  String get srDateRequested => 'Date Requested';

  @override
  String get srClosureComments => 'Closure Comments from Bank';

  @override
  String get srCommentsFromBank => 'Comments from Bank';

  @override
  String get srStatusHistory => 'Status History';

  @override
  String srRemarks(String note) {
    return 'Remarks : $note';
  }

  @override
  String get srAttachment => 'Attachment';

  @override
  String get srDownloadFailed => 'The attachment could not be downloaded.';

  @override
  String get srServiceRequestForm => 'Service Request Form';

  @override
  String get srSearchHint => 'Search...';

  @override
  String get srOr => 'OR';

  @override
  String get srOrganizedByProduct =>
      'Service Request form organized by Product and Category';

  @override
  String get srProducts => 'Products';

  @override
  String get srNoDefinitions => 'No service request found';

  @override
  String get srInformation => 'Information';

  @override
  String get srRequired => 'This field is required.';

  @override
  String get srInvalidValue => 'Enter a valid value.';

  @override
  String get srSelectValue => 'Select Value';

  @override
  String get srSelectAccount => 'Select Account';

  @override
  String get srSelectGender => 'Select Gender';

  @override
  String get srSelectSalutation => 'Select Salutation';

  @override
  String get srAccountNumber => 'Account Number';

  @override
  String get srDebitCard => 'Debit Card';

  @override
  String get srCountry => 'Country';

  @override
  String get srState => 'State';

  @override
  String get srChooseFile => 'Choose File';

  @override
  String get srRemoveFile => 'Remove';

  @override
  String get srFileTypes => '.jpg .jpeg .png .pdf .zip';

  @override
  String get srFileType => 'Allowed file types: .jpg, .jpeg, .png, .pdf, .zip';

  @override
  String get srUploadFailed => 'The file could not be uploaded.';

  @override
  String get srReviewMessage =>
      'You initiated a Service request. Please review details before you confirm!';

  @override
  String get srSubmitted => 'Service Request submitted successfully';

  @override
  String get srPendingApproval => 'Your request has been sent for approval.';

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

  @override
  String get billersColBillType => 'Bill Type';

  @override
  String get billersColStatus => 'Status';

  @override
  String get billersColActions => 'Actions';

  @override
  String get billersSelectAllToPay => 'Select all to Pay';

  @override
  String get billersSelectAtLeastOne =>
      'Select at least one presented bill for payment to proceed.';

  @override
  String get billHistoryAttachment => 'Attachment';

  @override
  String get payRequired => 'Required';

  @override
  String get billsHelpPayTitle => 'Pay bills hassle free';

  @override
  String get billsHelpPayBody1 =>
      'Make your bills payments and recharges hassle free with Demo Bank Bill Payment Service. You can view all your bills in one place and plan their payments.';

  @override
  String get billsHelpPayBody2 =>
      'Pay either one bill or multiple bills in one go and set up auto payments to avoid paying bills late.';

  @override
  String get billsHelpPayBody3 =>
      'And there is more. You can receive alerts whenever a bill is presented or close to due date.';

  @override
  String get billsHelpAddTitle => 'Decided to make online bill payment? Great!';

  @override
  String get billsHelpAddBody1 =>
      'The first step is to add billers who you want to pay. Once billers validate your registration you are all set to pay bills. You can even add billers who give paper bills and pay them online.';

  @override
  String get billsHelpAddBody2 =>
      'Demo Bank\'s Bill Payment Service makes online bill payment & recharges hassle free.';

  @override
  String get addBillerIntro =>
      'Register a biller for faster payments and reminders.';

  @override
  String get addBillerRequiredTitle => 'Required fields';

  @override
  String addBillerRequiredBody(String fields) {
    return 'Complete $fields before submitting.';
  }

  @override
  String get billHistoryPeriodNote =>
      'Payment history is shown for the selected period.';

  @override
  String get payBillTitle => 'Pay Bill';

  @override
  String get payBillSubcategory => 'Subcategory';

  @override
  String get payBillSubCategory => 'Sub Category';

  @override
  String payBillAcceptsVia(String key) {
    return 'Note: This biller accepts payment via $key';
  }

  @override
  String payBillAcceptsJoin(String accountOne, String accountTwo) {
    return '$accountOne and $accountTwo';
  }

  @override
  String get payBillTypeAccount => 'Account';

  @override
  String get payBillTypeCreditCards => 'Credit Cards';

  @override
  String get payBillTypeDebitCards => 'Debit Cards';

  @override
  String get payBillExpiryMonth => 'Expiry Month';

  @override
  String get payBillExpiryYear => 'Expiry Year';

  @override
  String get payBillSelectPlan => 'Select Plan';

  @override
  String get payBillPlan => 'Plan';

  @override
  String get payBillSelect => 'Select';

  @override
  String get payBillPaymentAmount => 'Payment Amount';

  @override
  String get payBillRechargeAmount => 'Recharge Amount';

  @override
  String get payBillScheduledDate => 'Scheduled Date';

  @override
  String get payBillAddAttachmentQuestion =>
      'Do you want to add an attachment ?';

  @override
  String get payBillDropFiles => 'Drop files here or click here to Add Files';

  @override
  String get payBillFileSizeNote => 'File size should not be more than 15MB';

  @override
  String get payBillSupportedFiles =>
      'Supported Files : JPEG, PNG, DOC, PDF, TXT, ZIP.';

  @override
  String get payBillAmountNotPositive => 'Amount should be greater than 0';

  @override
  String get payBillAmountInvalid => 'Amount should be lesser than 1 trillion';

  @override
  String get payBillInvalidFile => 'Invalid File Type';

  @override
  String get payBillFileTooLarge => 'File exceeds the maximum allowed size.';

  @override
  String get payBillInvalidExpiry => 'Invalid card expiry date';

  @override
  String get payBillReviewMessage =>
      'You initiated a request for bill payments. Please review details before you confirm!';

  @override
  String get payBillPaymentMethod => 'Payment Method';

  @override
  String get payBillPayWhen => 'Pay When';

  @override
  String get payBillAddAnAttachment => 'Add an attachment ?';

  @override
  String get payBillDetailedBill => 'Detailed Bill';

  @override
  String get payBillBillerNumber => 'Biller Number';

  @override
  String get payBillBillDate => 'Bill Date';

  @override
  String get payBillEarlyPayDate => 'Early Pay Date';

  @override
  String get payBillEarlyPayDiscount => 'Early Pay Discount';

  @override
  String get payBillEarlyPayBillAmount => 'Early Pay Bill Amount';

  @override
  String get payBillLatePayCharges => 'Late Pay Charges';

  @override
  String get payBillLatePayBillAmount => 'Late Pay Bill Amount';

  @override
  String get payBillDescription => 'Description';

  @override
  String get payBillReferenceNumber => 'Reference Number';

  @override
  String get payBillSuccess => 'Request submitted successfully.';

  @override
  String get payBillPendingApproval => 'Pay Bill submitted for approval.';

  @override
  String get payBillNextAction => 'What would you like to do next?';

  @override
  String get payBillPayAnother => 'Pay Another Bill';

  @override
  String get payBillAddBiller => 'Add Biller';

  @override
  String get payBillAmount => 'Amount';

  @override
  String get payBillAttachments => 'Attachments';

  @override
  String get payBillGateTitle => 'Bill Payment';

  @override
  String get payBillAutopayWarning =>
      'This bill is registered for auto payment. Initiating a bill payment now might lead to duplicate payment of the same bill. Would you still like to continue?';

  @override
  String get payBillScheduledWarning =>
      'A Scheduled payment has been setup for this bill. Initiating a bill payment now might lead to duplicate payment of the same bill. Would you still like to continue?';

  @override
  String get payBillLateBlocked =>
      'Last Date of Bill Payment has Passed. Late Payment not allowed by Biller!';

  @override
  String get payBillContinue => 'Continue';

  @override
  String get payBillOk => 'Ok';

  @override
  String get payBillLoadFailed => 'We couldn\'t load this bill payment.';

  @override
  String get payBillAccountsFailed => 'We couldn\'t load your accounts.';

  @override
  String get payBillNoAccounts => 'Nothing available to pay from.';

  @override
  String get payBillFailed => 'We couldn\'t complete the payment.';

  @override
  String get payBillUploadFailed => 'We couldn\'t upload the attachment.';

  @override
  String get payBillPickFailed => 'We couldn\'t open that file.';

  @override
  String get payBillRemoveAttachment => 'Remove attachment';

  @override
  String get payBillChooseFile => 'Choose File';

  @override
  String get payBillsTitle => 'Pay Bills';

  @override
  String payBillsReviewMessage(int count) {
    return 'You have initiated $count bill payments. Please review the details before you confirm!';
  }

  @override
  String get payBillsEdit => 'Edit Bill Payment';

  @override
  String get payBillsDelete => 'Delete Bill Payment';

  @override
  String get payBillsSave => 'Save';

  @override
  String get payBillsSaveAll => 'Please save all unsaved payments.';

  @override
  String get payBillsSelectAccount => 'Select an account to proceed';

  @override
  String get payBillsCopyAccount =>
      'Default this account for all the bill payments records';

  @override
  String get payBillsCopyDate =>
      'Default this date for all the bill payments records';

  @override
  String get payBillsStatusTitle => 'Multiple Bill Payment Status';

  @override
  String get payBillsFromAccount => 'From Account';

  @override
  String get payBillsHostReference => 'Host Reference No.';

  @override
  String get payBillsReference => 'Reference No.';

  @override
  String get payBillsStatus => 'Status';

  @override
  String get payBillsCompleted => 'Completed';

  @override
  String get payBillsInitiated => 'Initiated';

  @override
  String get payBillsPendingApproval => 'Pending for approval';

  @override
  String get payBillsFailed => 'Failed';

  @override
  String get payBillsNoAnswer => 'No answer was received for this bill.';

  @override
  String get payBillsSendFailed => 'We couldn\'t send the payments.';

  @override
  String get ccBlockCard => 'Block Card';

  @override
  String get ccUnblockCard => 'Unblock Card';

  @override
  String get ccListSubtitle =>
      'View balances, due amounts and manage each card.';

  @override
  String get ccTotalCreditLimit => 'Total Credit Limit';

  @override
  String ccActiveCards(int count) {
    return '$count active cards';
  }

  @override
  String ccShareOfLimit(String percent) {
    return '$percent% of total limit';
  }

  @override
  String ccNextDue(String date) {
    return 'Next due $date';
  }

  @override
  String get ccSearchHint => 'Search Card Number or Holder Name';

  @override
  String get ccOwnership => 'Ownership';

  @override
  String get ccAllCards => 'All cards';

  @override
  String get ccNoMatch => 'No credit cards match your search.';

  @override
  String get ccClearFilters => 'Clear filters';

  @override
  String get ccHideAmounts => 'Hide amounts';

  @override
  String get ccShowAmounts => 'Show amounts';

  @override
  String get ccCopyNumber => 'Copy card number';

  @override
  String get ccNumberCopied => 'Card number copied';

  @override
  String get ccMoreActions => 'More actions';
}
