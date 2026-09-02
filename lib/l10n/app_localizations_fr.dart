// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Demo Bank';

  @override
  String get brandName => 'UBCI';

  @override
  String get welcome => 'Bienvenue !';

  @override
  String get welcomeBack => 'Content de vous revoir !';

  @override
  String get loginSubtitle =>
      'Veuillez saisir votre nom d\'utilisateur et votre mot de passe pour vous connecter';

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
  String get username => 'Nom d\'utilisateur';

  @override
  String get password => 'Mot de passe';

  @override
  String get enterUsername => 'Saisir le nom d\'utilisateur';

  @override
  String get enterPassword => 'Saisir le mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get forgotUsername => 'Nom d\'utilisateur oublié ?';

  @override
  String get forgotUsernameTitle => 'Nom d\'utilisateur oublié';

  @override
  String get forgotPasswordTitle => 'Mot de passe oublié';

  @override
  String get forgotUsernameSubtitle =>
      'Pour récupérer votre nom d\'utilisateur, veuillez saisir l\'adresse e-mail et la date de naissance enregistrées sur votre compte bancaire.';

  @override
  String get forgotPasswordSubtitle =>
      'Pas de problème. Saisissez simplement les informations ci-dessous.';

  @override
  String get forgotEmailLabel => 'E-mail';

  @override
  String get forgotEmailHint => 'Enter email';

  @override
  String get forgotEmailRequired => 'Obligatoire';

  @override
  String get forgotUserNameLabel => 'Nom d\'utilisateur';

  @override
  String get forgotUserNameHint => 'Enter username';

  @override
  String get forgotUserNameRequired => 'Obligatoire';

  @override
  String get forgotDateOfBirthLabel => 'Date de naissance';

  @override
  String get forgotDateOfBirthHint => 'Select date of birth';

  @override
  String get forgotDateOfBirthRequired => 'Obligatoire';

  @override
  String get forgotSubmit => 'Soumettre';

  @override
  String get forgotOtpTitle => 'Vérification unique';

  @override
  String get forgotOtpSubtitle =>
      'Un code de vérification a été envoyé à votre numéro de mobile enregistré. Veuillez saisir ce code ci-dessous pour terminer le processus.';

  @override
  String get forgotNoteHeading => 'Remarque';

  @override
  String get forgotNoteQuestion =>
      'Vous ne vous souvenez pas de votre nom d\'utilisateur ?';

  @override
  String get forgotNoteBody =>
      'Saisissez simplement votre e-mail enregistré et authentifiez-vous pour recevoir votre identifiant par e-mail.';

  @override
  String get forgotNoteSupport =>
      'Si vous ne parvenez pas à récupérer votre identifiant, veuillez vous rendre dans l\'agence la plus proche ou contacter le service client.';

  @override
  String get forgotPasswordNoteQuestion => 'Not able to recall your Password?';

  @override
  String get forgotPasswordNoteBody =>
      'Simply enter your User Name and date of birth registered in your bank account to receive a password reset link on your email.';

  @override
  String get forgotPasswordNoteSupport =>
      'In case you are unable to recover your Password, please visit our nearest branch or contact and speak to our customer care executive.';

  @override
  String get forgotSuccessHeading => 'Succès';

  @override
  String get forgotUsernameSuccessMessage =>
      'Le nom d\'utilisateur récupéré a été envoyé avec succès à votre e-mail enregistré.';

  @override
  String get forgotPasswordSuccessMessage =>
      'Le lien pour générer un nouveau mot de passe a été envoyé avec succès sur votre e-mail';

  @override
  String get forgotGoToLogin => 'Se connecter à votre compte bancaire';

  @override
  String otpReferenceNumber(String reference) {
    return 'Numéro de référence : $reference';
  }

  @override
  String get login => 'Connexion';

  @override
  String get loggingIn => 'Connexion en cours...';

  @override
  String get keepMeSignedIn => 'Keep me signed in';

  @override
  String get loginWithBiometrics => 'Login with biometrics';

  @override
  String get featureComingSoon => 'This feature will be available soon.';

  @override
  String get help => 'Aide';

  @override
  String get loginHelpTitle => 'Besoin d\'aide pour vous connecter ?';

  @override
  String get loginHelpSubtitle => 'Conseils rapides pour l\'écran de connexion';

  @override
  String get loginHelpBody =>
      'Saisissez le nom d\'utilisateur et le mot de passe enregistrés sur votre compte bancaire.\n\nSi vous avez oublié votre nom d\'utilisateur ou votre mot de passe, utilisez les liens sous le formulaire de connexion pour les récupérer.\n\nVous pouvez rester connecté sur les appareils de confiance. Sur le web, utilisez l\'icône du clavier virtuel pour une saisie sécurisée.\n\nPour toute assistance supplémentaire, veuillez vous rendre dans l\'agence la plus proche ou contacter le service client.';

  @override
  String get loginHelpClose => 'Compris';

  @override
  String get virtualKeyboard => 'Clavier virtuel';

  @override
  String get virtualKeyboardDone => 'Terminé';

  @override
  String get virtualKeyboardSpace => 'Espace';

  @override
  String get virtualKeyboardShuffle => 'Mélanger les touches';

  @override
  String get virtualKeyboardClear => 'Effacer';

  @override
  String get notRegistered => 'Pas encore inscrit ? ';

  @override
  String get registerHere => 'Inscrivez-vous ici';

  @override
  String get pleaseEnterCredentials =>
      'Veuillez saisir le nom d\'utilisateur et le mot de passe';

  @override
  String get overview => 'Aperçu';

  @override
  String get accounts => 'Comptes';

  @override
  String get cards => 'Cartes';

  @override
  String get deposit => 'Dépôt';

  @override
  String get home => 'Accueil';

  @override
  String get insights => 'Analyses';

  @override
  String get rewards => 'Récompenses';

  @override
  String get more => 'Plus';

  @override
  String get transfer => 'Virement';

  @override
  String get scan => 'Scanner';

  @override
  String get scanAndPay => 'Scan & pay';

  @override
  String get payBill => 'Payer une facture';

  @override
  String get goodMorning => 'Bonjour';

  @override
  String get goodMorningComma => 'Good Morning,';

  @override
  String get totalBalance => 'SOLDE TOTAL';

  @override
  String get moreTitle => 'Plus';

  @override
  String get theme => 'Thème';

  @override
  String get lightTheme => 'Clair';

  @override
  String get darkTheme => 'Sombre';

  @override
  String get language => 'Langue';

  @override
  String get english => 'Anglais';

  @override
  String get arabic => 'Arabe';

  @override
  String get french => 'Français';

  @override
  String get italian => 'Italien';

  @override
  String get uzbek => 'Ouzbek';

  @override
  String get russian => 'Russe';

  @override
  String get security => 'Sécurité';

  @override
  String get logOut => 'Déconnexion';

  @override
  String get forgetDevice => 'Oublier l\'appareil';

  @override
  String get logOutConfirm =>
      'Se déconnecter de cette session sur cet appareil ?';

  @override
  String get logOutConfirmWithBiometric =>
      'Sign out of this session on this device?\n\nYou will lose biometric login and will need to set it up again after you sign in.';

  @override
  String get forgetDeviceConfirm =>
      'Supprimer toutes les données de session enregistrées sur cet appareil ? Vous devrez vous reconnecter.';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get deviceBlockedTitle => 'Appareil non pris en charge';

  @override
  String get deviceBlockedCompromisedMessage =>
      'Pour votre sécurité, cette application ne peut pas fonctionner sur des appareils modifiés ou compromis. Veuillez utiliser un appareil standard non modifié.';

  @override
  String get deviceBlockedEmulatorMessage =>
      'Pour votre sécurité, cette application ne peut pas fonctionner sur des émulateurs ou simulateurs en version de production.';

  @override
  String get deviceBlockedSupport =>
      'Si vous pensez qu\'il s\'agit d\'une erreur, contactez le centre d\'assistance de votre banque.';

  @override
  String get deviceSecurityWarnCompromised =>
      'Avertissement de sécurité : cet appareil peut être modifié. Procédez avec prudence.';

  @override
  String get deviceSecurityWarnEmulator =>
      'Avertissement de sécurité : vous utilisez un émulateur ou un simulateur.';

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
      'Pour votre sécurité, vous avez été déconnecté. Veuillez vous reconnecter.';

  @override
  String get sessionExpiredTitle => 'Session expirée';

  @override
  String get sessionExpiredSignIn => 'Se connecter';

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
      'Impossible de charger les comptes. Veuillez réessayer.';

  @override
  String get accountsEmpty => 'Aucun compte disponible.';

  @override
  String get accountsRetry => 'Réessayer';

  @override
  String get accountStatusActive => 'Actif';

  @override
  String get accountStatusDormant => 'Inactif';

  @override
  String get accountsMultipleCurrencies => 'Soldes affichés par devise';

  @override
  String get availableBalanceLabel => 'Solde disponible';

  @override
  String get errorLoansLoadFailed =>
      'Impossible de charger les prêts. Veuillez réessayer.';

  @override
  String get loansEmpty => 'Aucun prêt disponible.';

  @override
  String get loanTrackerTitle => 'Suivi des prêts';

  @override
  String get loanTotalBorrowing => 'Emprunt total';

  @override
  String get loanTotalOutstanding => 'Encours total';

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
      'Impossible de charger les détails du compte. Veuillez réessayer.';

  @override
  String get errorTransactionsLoadFailed =>
      'Impossible de charger les transactions. Veuillez réessayer.';

  @override
  String get casaAccountDetailsTitle =>
      'Détails du compte courant et d\'épargne';

  @override
  String get casaAccountDetailsTitleWeb =>
      'DÉTAILS DU COMPTE COURANT ET D\'ÉPARGNE';

  @override
  String get casaAccountNumberLabel => 'Numéro de compte';

  @override
  String get casaCurrentBalance => 'Solde actuel';

  @override
  String get casaProductName => 'Nom du produit';

  @override
  String get casaNickName => 'Surnom';

  @override
  String get casaNotAssigned => 'Non attribué';

  @override
  String get casaNotRegistered => 'Non enregistré';

  @override
  String get casaBalanceDetails => 'Détails du solde';

  @override
  String get casaTodaysOpeningBalance => 'Solde d\'ouverture du jour';

  @override
  String get casaAvailableBalance => 'Solde disponible';

  @override
  String get casaAmountOnHold => 'Montant bloqué';

  @override
  String get casaUnderFunds => 'Fonds en cours';

  @override
  String get casaAdvanceAgainstUnclearFunds =>
      'Limite d\'avance sur fonds non compensés';

  @override
  String get casaOverdraftLimit => 'Limite de découvert';

  @override
  String get casaSweepInAmount => 'Montant de transfer automatique';

  @override
  String get casaGeneralDetails => 'Informations générales';

  @override
  String get casaHoldingPattern => 'Mode de détention';

  @override
  String get casaPrimaryAccountHolder => 'Titulaire principal';

  @override
  String get casaNominee => 'Bénéficiaire';

  @override
  String get casaBranch => 'Agence';

  @override
  String get casaViewTransactions => 'Voir les transactions';

  @override
  String get casaTransactionsTitle => 'Transactions';

  @override
  String get casaTransactionsTitleWeb => 'TRANSACTIONS';

  @override
  String get casaOpeningBalance => 'Solde d\'ouverture';

  @override
  String get casaClosingBalance => 'Solde de clôture';

  @override
  String get casaRecentTransactions => 'Transactions récentes';

  @override
  String get casaTransactionsEmpty => 'Aucune transaction trouvée.';

  @override
  String casaTransactionRef(String reference) {
    return 'Réf. : $reference';
  }

  @override
  String get casaDownloadStatement => 'Télécharger le relevé';

  @override
  String get casaStatementDownloadSuccess => 'Relevé téléchargé.';

  @override
  String get casaStatementDownloadFailed =>
      'Impossible de télécharger le relevé. Veuillez réessayer.';

  @override
  String get casaFilterViewOptions => 'Options d\'affichage';

  @override
  String get casaFilterTransactions => 'Transactions';

  @override
  String get casaFilterAll => 'Toutes';

  @override
  String get casaFilterCreditsOnly => 'Crédits uniquement';

  @override
  String get casaFilterDebitsOnly => 'Débits uniquement';

  @override
  String get casaFilterAmount => 'Montant';

  @override
  String get casaFilterReferenceNumber => 'Numéro de référence';

  @override
  String get casaFilterApply => 'Appliquer';

  @override
  String get casaFilterReset => 'Réinitialiser';

  @override
  String get casaViewCurrentMonth => 'Mois en cours';

  @override
  String get casaViewCurrentDay => 'Jour en cours';

  @override
  String get casaViewPreviousDay => 'Jour précédent';

  @override
  String get casaViewPreviousMonth => 'Mois précédent';

  @override
  String get casaViewCurrentAndPreviousMonth => 'Mois en cours et précédent';

  @override
  String get casaTxnTypeCredit => 'Crédit';

  @override
  String get casaTxnTypeDebit => 'Débit';

  @override
  String get casaColTxnDate => 'Date de transaction';

  @override
  String get casaColValueDate => 'Date de valeur';

  @override
  String get casaColDescription => 'Description';

  @override
  String get casaColReference => 'Numéro de référence';

  @override
  String get casaColType => 'Type de transaction';

  @override
  String get casaColAmount => 'Montant';

  @override
  String get casaColBalance => 'Solde';

  @override
  String get casaStatementPasswordTitle => 'Combinaison du mot de passe';

  @override
  String get casaStatementPasswordBody =>
      'Le relevé téléchargé est protégé par un mot de passe. Le mot de passe correspond aux 4 premières lettres de votre nom en majuscules, suivies de votre date de naissance au format JJMM.';

  @override
  String get casaStatementPasswordExample1 =>
      'Exemple : nom Roopa Lal, date de naissance 23-12-1980 → ROOP2312.';

  @override
  String get casaStatementPasswordExample2 =>
      'Si le prénom a moins de 4 lettres, les lettres restantes sont prises du nom de famille. Exemple : Joy Matthew, 01-01-1980 → JOYM0101.';

  @override
  String get casaStatementPasswordContinue => 'Télécharger';

  @override
  String get errorInvalidRequest => 'Invalid request. Please check your input.';

  @override
  String get errorOtpInvalid =>
      'The verification code is incorrect. Please try again.';

  @override
  String get errorBiometricAccessPoint =>
      'L\'accès rapide mobile n\'est pas activé pour votre compte. Demandez à votre banque d\'activer le point d\'accès application mobile.';

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
      other: '$count renvois restants',
      one: '1 renvoi restant',
      zero: 'Aucun renvoi restant',
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
  String get biometricEnableLogin => 'Activer la connexion biométrique';

  @override
  String get biometricEnableLoginHelper =>
      'Utilisez votre empreinte ou la reconnaissance faciale pour vous connecter rapidement.';

  @override
  String get biometricEnableFaceId => 'Activer Face ID';

  @override
  String get biometricEnableTouchId => 'Activer Touch ID';

  @override
  String get biometricNotEnrolledTitle =>
      'Déverrouillage biométrique non configuré';

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
