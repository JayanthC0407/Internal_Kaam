// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Demo Bank';

  @override
  String get brandName => 'UBCI';

  @override
  String get welcome => 'Benvenuto!';

  @override
  String get welcomeBack => 'Bentornato!';

  @override
  String get loginSubtitle => 'Inserisci nome utente e password per accedere';

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
  String get username => 'Nome utente';

  @override
  String get password => 'Password';

  @override
  String get enterUsername => 'Inserisci nome utente';

  @override
  String get enterPassword => 'Inserisci password';

  @override
  String get forgotPassword => 'Password dimenticata?';

  @override
  String get forgotUsername => 'Nome utente dimenticato?';

  @override
  String get forgotUsernameTitle => 'Nome utente dimenticato';

  @override
  String get forgotPasswordTitle => 'Password dimenticata';

  @override
  String get forgotUsernameSubtitle =>
      'Per recuperare il nome utente, inserisci l\'indirizzo email e la data di nascita registrati nel tuo conto bancario.';

  @override
  String get forgotPasswordSubtitle =>
      'Nessun problema. Inserisci semplicemente i dettagli qui sotto.';

  @override
  String get forgotEmailLabel => 'Email';

  @override
  String get forgotEmailHint => 'Enter email';

  @override
  String get forgotEmailRequired => 'Obbligatorio';

  @override
  String get forgotUserNameLabel => 'Nome utente';

  @override
  String get forgotUserNameHint => 'Enter username';

  @override
  String get forgotUserNameRequired => 'Obbligatorio';

  @override
  String get forgotDateOfBirthLabel => 'Data di nascita';

  @override
  String get forgotDateOfBirthHint => 'Select date of birth';

  @override
  String get forgotDateOfBirthRequired => 'Obbligatorio';

  @override
  String get forgotSubmit => 'Invia';

  @override
  String get forgotOtpTitle => 'Verifica monouso';

  @override
  String get forgotOtpSubtitle =>
      'Un codice di verifica è stato inviato al tuo numero di cellulare registrato. Inserisci il codice qui sotto per completare il processo.';

  @override
  String get forgotNoteHeading => 'Nota';

  @override
  String get forgotNoteQuestion => 'Non riesci a ricordare il nome utente?';

  @override
  String get forgotNoteBody =>
      'Inserisci semplicemente la tua email registrata e autenticati per ricevere il tuo ID utente via email.';

  @override
  String get forgotNoteSupport =>
      'Se non riesci a recuperare il tuo ID utente, visita la filiale più vicina o contatta il servizio clienti.';

  @override
  String get forgotPasswordNoteQuestion => 'Not able to recall your Password?';

  @override
  String get forgotPasswordNoteBody =>
      'Simply enter your User Name and date of birth registered in your bank account to receive a password reset link on your email.';

  @override
  String get forgotPasswordNoteSupport =>
      'In case you are unable to recover your Password, please visit our nearest branch or contact and speak to our customer care executive.';

  @override
  String get forgotSuccessHeading => 'Successo';

  @override
  String get forgotUsernameSuccessMessage =>
      'Il nome utente recuperato è stato inviato con successo alla tua email registrata.';

  @override
  String get forgotPasswordSuccessMessage =>
      'Il link per generare una nuova password è stato inviato con successo alla tua email';

  @override
  String get forgotGoToLogin => 'Accedi al tuo conto bancario';

  @override
  String otpReferenceNumber(String reference) {
    return 'Numero di riferimento: $reference';
  }

  @override
  String get login => 'Accedi';

  @override
  String get loggingIn => 'Accesso in corso...';

  @override
  String get keepMeSignedIn => 'Keep me signed in';

  @override
  String get loginWithBiometrics => 'Login with biometrics';

  @override
  String get featureComingSoon => 'This feature will be available soon.';

  @override
  String get help => 'Aiuto';

  @override
  String get loginHelpTitle => 'Serve aiuto per accedere?';

  @override
  String get loginHelpSubtitle =>
      'Suggerimenti rapidi per la schermata di accesso';

  @override
  String get loginHelpBody =>
      'Inserisci il nome utente e la password registrati sul tuo conto bancario.\n\nSe hai dimenticato il nome utente o la password, usa i link sotto il modulo di accesso per recuperarli.\n\nPuoi restare connesso sui dispositivi attendibili. Sul web, usa l\'icona della tastiera virtuale per un inserimento sicuro.\n\nPer ulteriore assistenza, visita la filiale più vicina o contatta il servizio clienti.';

  @override
  String get loginHelpClose => 'Ho capito';

  @override
  String get virtualKeyboard => 'Tastiera virtuale';

  @override
  String get virtualKeyboardDone => 'Fine';

  @override
  String get virtualKeyboardSpace => 'Spazio';

  @override
  String get virtualKeyboardShuffle => 'Mescola tasti';

  @override
  String get virtualKeyboardClear => 'Cancella';

  @override
  String get notRegistered => 'Non registrato? ';

  @override
  String get registerHere => 'Registrati qui';

  @override
  String get pleaseEnterCredentials => 'Inserisci nome utente e password';

  @override
  String get overview => 'Panoramica';

  @override
  String get accounts => 'Conti';

  @override
  String get cards => 'Carte';

  @override
  String get deposit => 'Deposito';

  @override
  String get home => 'Home';

  @override
  String get insights => 'Analisi';

  @override
  String get rewards => 'Premi';

  @override
  String get more => 'Altro';

  @override
  String get transfer => 'Bonifico';

  @override
  String get scan => 'Scansiona';

  @override
  String get scanAndPay => 'Scan & pay';

  @override
  String get payBill => 'Paga bolletta';

  @override
  String get goodMorning => 'Buongiorno';

  @override
  String get goodMorningComma => 'Good Morning,';

  @override
  String get totalBalance => 'SALDO TOTALE';

  @override
  String get moreTitle => 'Altro';

  @override
  String get theme => 'Tema';

  @override
  String get lightTheme => 'Chiaro';

  @override
  String get darkTheme => 'Scuro';

  @override
  String get language => 'Lingua';

  @override
  String get english => 'Inglese';

  @override
  String get arabic => 'Arabo';

  @override
  String get french => 'Francese';

  @override
  String get italian => 'Italiano';

  @override
  String get uzbek => 'Uzbeco';

  @override
  String get russian => 'Russo';

  @override
  String get security => 'Sicurezza';

  @override
  String get logOut => 'Esci';

  @override
  String get forgetDevice => 'Dimentica dispositivo';

  @override
  String get logOutConfirm =>
      'Uscire da questa sessione su questo dispositivo?';

  @override
  String get logOutConfirmWithBiometric =>
      'Sign out of this session on this device?\n\nYou will lose biometric login and will need to set it up again after you sign in.';

  @override
  String get forgetDeviceConfirm =>
      'Rimuovere tutti i dati di sessione salvati da questo dispositivo? Dovrai accedere di nuovo.';

  @override
  String get cancel => 'Annulla';

  @override
  String get confirm => 'Conferma';

  @override
  String get deviceBlockedTitle => 'Dispositivo non supportato';

  @override
  String get deviceBlockedCompromisedMessage =>
      'Per la tua sicurezza, questa app non può essere eseguita su dispositivi modificati o compromessi. Usa un dispositivo standard non modificato.';

  @override
  String get deviceBlockedEmulatorMessage =>
      'Per la tua sicurezza, questa app non può essere eseguita su emulatori o simulatori nelle build di produzione.';

  @override
  String get deviceBlockedSupport =>
      'Se ritieni che si tratti di un errore, contatta il centro assistenza della banca.';

  @override
  String get deviceSecurityWarnCompromised =>
      'Avviso di sicurezza: questo dispositivo potrebbe essere modificato. Procedi con cautela.';

  @override
  String get deviceSecurityWarnEmulator =>
      'Avviso di sicurezza: stai usando un emulatore o un simulatore.';

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
      'Per la tua sicurezza sei stato disconnesso. Accedi di nuovo.';

  @override
  String get sessionExpiredTitle => 'Sessione scaduta';

  @override
  String get sessionExpiredSignIn => 'Accedi';

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
      'Impossibile caricare i conti. Riprova.';

  @override
  String get accountsEmpty => 'Nessun conto disponibile.';

  @override
  String get accountsRetry => 'Riprova';

  @override
  String get accountStatusActive => 'Attivo';

  @override
  String get accountStatusDormant => 'Dormiente';

  @override
  String get accountsMultipleCurrencies => 'Saldi mostrati per valuta';

  @override
  String get availableBalanceLabel => 'Saldo disponibile';

  @override
  String get errorLoansLoadFailed =>
      'Impossibile caricare i prestiti. Riprova.';

  @override
  String get loansEmpty => 'Nessun prestito disponibile.';

  @override
  String get loanTrackerTitle => 'Monitoraggio prestiti';

  @override
  String get loanTotalBorrowing => 'Totale finanziato';

  @override
  String get loanTotalOutstanding => 'Totale residuo';

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
      'Impossibile caricare i dettagli del conto. Riprova.';

  @override
  String get errorTransactionsLoadFailed =>
      'Impossibile caricare le transazioni. Riprova.';

  @override
  String get casaAccountDetailsTitle => 'Dettagli conto corrente e risparmio';

  @override
  String get casaAccountDetailsTitleWeb =>
      'DETTAGLI CONTO CORRENTE E RISPARMIO';

  @override
  String get casaAccountNumberLabel => 'Numero di conto';

  @override
  String get casaCurrentBalance => 'Saldo corrente';

  @override
  String get casaProductName => 'Nome prodotto';

  @override
  String get casaNickName => 'Soprannome';

  @override
  String get casaNotAssigned => 'Non assegnato';

  @override
  String get casaNotRegistered => 'Non registrato';

  @override
  String get casaBalanceDetails => 'Dettagli saldo';

  @override
  String get casaTodaysOpeningBalance => 'Saldo di apertura odierno';

  @override
  String get casaAvailableBalance => 'Saldo disponibile';

  @override
  String get casaAmountOnHold => 'Importo bloccato';

  @override
  String get casaUnderFunds => 'Fondi in elaborazione';

  @override
  String get casaAdvanceAgainstUnclearFunds =>
      'Limite anticipo su fondi non liquidati';

  @override
  String get casaOverdraftLimit => 'Limite di scoperto';

  @override
  String get casaSweepInAmount => 'Importo sweep-in';

  @override
  String get casaGeneralDetails => 'Dettagli generali';

  @override
  String get casaHoldingPattern => 'Regime di detenzione';

  @override
  String get casaPrimaryAccountHolder => 'Intestatario principale';

  @override
  String get casaNominee => 'Beneficiario';

  @override
  String get casaBranch => 'Filiale';

  @override
  String get casaViewTransactions => 'Vedi transazioni';

  @override
  String get casaTransactionsTitle => 'Transazioni';

  @override
  String get casaTransactionsTitleWeb => 'TRANSAZIONI';

  @override
  String get casaOpeningBalance => 'Saldo di apertura';

  @override
  String get casaClosingBalance => 'Saldo di chiusura';

  @override
  String get casaRecentTransactions => 'Transazioni recenti';

  @override
  String get casaTransactionsEmpty => 'Nessuna transazione trovata.';

  @override
  String casaTransactionRef(String reference) {
    return 'Rif: $reference';
  }

  @override
  String get casaDownloadStatement => 'Scarica estratto conto';

  @override
  String get casaStatementDownloadSuccess => 'Estratto conto scaricato.';

  @override
  String get casaStatementDownloadFailed =>
      'Impossibile scaricare l\'estratto conto. Riprova.';

  @override
  String get casaFilterViewOptions => 'Opzioni di visualizzazione';

  @override
  String get casaFilterTransactions => 'Transazioni';

  @override
  String get casaFilterAll => 'Tutte';

  @override
  String get casaFilterCreditsOnly => 'Solo accrediti';

  @override
  String get casaFilterDebitsOnly => 'Solo addebiti';

  @override
  String get casaFilterAmount => 'Importo';

  @override
  String get casaFilterFromAmount => 'Importo da';

  @override
  String get casaFilterToAmount => 'Importo a';

  @override
  String get casaFilterDate => 'Data';

  @override
  String get casaFilterFromDate => 'Data inizio';

  @override
  String get casaFilterToDate => 'Data fine';

  @override
  String get casaFilterReferenceNumber => 'Numero di riferimento';

  @override
  String get casaFilterApply => 'Applica';

  @override
  String get casaFilterReset => 'Reimposta';

  @override
  String get casaViewCurrentMonth => 'Mese corrente';

  @override
  String get casaViewCurrentDay => 'Giorno corrente';

  @override
  String get casaViewPreviousDay => 'Giorno precedente';

  @override
  String get casaViewDateRange => 'Intervallo di date';

  @override
  String get casaViewSpecificDay => 'Giorno specifico';

  @override
  String get casaViewPreviousMonth => 'Mese precedente';

  @override
  String get casaViewPreviousQuarter => 'Trimestre precedente';

  @override
  String get casaViewLast10 => 'Ultime 10 transazioni';

  @override
  String get casaViewCurrentAndPreviousMonth => 'Mese corrente e precedente';

  @override
  String get casaTxnTypeCredit => 'Accredito';

  @override
  String get casaTxnTypeDebit => 'Addebito';

  @override
  String get casaColTxnDate => 'Data transazione';

  @override
  String get casaColValueDate => 'Data valuta';

  @override
  String get casaColDescription => 'Descrizione';

  @override
  String get casaColReference => 'Numero di riferimento';

  @override
  String get casaColType => 'Tipo transazione';

  @override
  String get casaColAmount => 'Importo';

  @override
  String get casaColBalance => 'Saldo';

  @override
  String get casaStatementPasswordTitle => 'Combinazione della password';

  @override
  String get casaStatementPasswordBody =>
      'L\'estratto conto scaricato è protetto da password. La password è composta dalle prime 4 lettere del nome in maiuscolo seguite dalla data di nascita nel formato GGMM.';

  @override
  String get casaStatementPasswordExample1 =>
      'Esempio: nome Roopa Lal, data di nascita 23-12-1980 → ROOP2312.';

  @override
  String get casaStatementPasswordExample2 =>
      'Se il nome ha meno di 4 lettere, le lettere restanti si prendono dal cognome. Esempio: Joy Matthew, 01-01-1980 → JOYM0101.';

  @override
  String get casaStatementPasswordContinue => 'Scarica';

  @override
  String get errorInvalidRequest => 'Invalid request. Please check your input.';

  @override
  String get errorOtpInvalid =>
      'The verification code is incorrect. Please try again.';

  @override
  String get errorBiometricAccessPoint =>
      'L\'accesso rapido mobile non è abilitato per il tuo account. Chiedi alla banca di abilitare il touch point dell\'app mobile.';

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
      other: '$count nuovi invii rimanenti',
      one: '1 nuovo invio rimanente',
      zero: 'Nessun nuovo invio rimanente',
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
  String get biometricEnableLogin => 'Attiva accesso biometrico';

  @override
  String get biometricEnableLoginHelper =>
      'Usa l\'impronta o lo sblocco viso per accedere più velocemente.';

  @override
  String get biometricEnableFaceId => 'Attiva Face ID';

  @override
  String get biometricEnableTouchId => 'Attiva Touch ID';

  @override
  String get biometricNotEnrolledTitle => 'Sblocco biometrico non configurato';

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
