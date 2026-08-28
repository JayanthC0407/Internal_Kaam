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
  String get casaRecentTransactions => 'Недавние операции';

  @override
  String get casaTransactionsEmpty => 'Операции не найдены.';

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
  String get casaViewPreviousMonth => 'Предыдущий месяц';

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
}
