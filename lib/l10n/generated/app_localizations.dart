import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('en'),
    Locale('th'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Off Grid SOS'**
  String get appTitle;

  /// No description provided for @authStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to check authentication status.'**
  String get authStatusUnavailable;

  /// No description provided for @navNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get navNearby;

  /// No description provided for @navHelping.
  ///
  /// In en, this message translates to:
  /// **'Helping'**
  String get navHelping;

  /// No description provided for @navHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help'**
  String get navHelp;

  /// No description provided for @navHelpCompact.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get navHelpCompact;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get preferences;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the app display language'**
  String get languageDescription;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageThai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get languageThai;

  /// No description provided for @languageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Language could not be saved. The previous language remains active.'**
  String get languageSaveFailed;

  /// No description provided for @usageMode.
  ///
  /// In en, this message translates to:
  /// **'Usage mode'**
  String get usageMode;

  /// No description provided for @modeRescueDescription.
  ///
  /// In en, this message translates to:
  /// **'Rescue · tap to change mode'**
  String get modeRescueDescription;

  /// No description provided for @modeNeedHelpDescription.
  ///
  /// In en, this message translates to:
  /// **'Need help · tap to change mode'**
  String get modeNeedHelpDescription;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'SOS updates and in-app alerts'**
  String get notificationsDescription;

  /// No description provided for @notificationsReady.
  ///
  /// In en, this message translates to:
  /// **'Notifications are ready'**
  String get notificationsReady;

  /// No description provided for @notificationsReadyDetail.
  ///
  /// In en, this message translates to:
  /// **'SOS updates will appear here.'**
  String get notificationsReadyDetail;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get noNotifications;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Permission and location services'**
  String get locationSettingsDescription;

  /// No description provided for @automaticPublicRelay.
  ///
  /// In en, this message translates to:
  /// **'Automatic public relay for my SOS'**
  String get automaticPublicRelay;

  /// No description provided for @automaticPublicRelayOn.
  ///
  /// In en, this message translates to:
  /// **'On. During an emergency, signed SOS data may be stored and forwarded by opted-in nearby devices for up to 30 minutes.'**
  String get automaticPublicRelayOn;

  /// No description provided for @automaticPublicRelayOff.
  ///
  /// In en, this message translates to:
  /// **'Off. Configure this before an emergency. Bluetooth permission alone never enables public relay.'**
  String get automaticPublicRelayOff;

  /// No description provided for @includeLocationRelay.
  ///
  /// In en, this message translates to:
  /// **'Include location in public relay'**
  String get includeLocationRelay;

  /// No description provided for @includeLocationRelayDescription.
  ///
  /// In en, this message translates to:
  /// **'Separate consent. When off, relay messages contain no coordinates.'**
  String get includeLocationRelayDescription;

  /// No description provided for @nearbyRelay.
  ///
  /// In en, this message translates to:
  /// **'Nearby SOS relay'**
  String get nearbyRelay;

  /// No description provided for @nearbyRelayOn.
  ///
  /// In en, this message translates to:
  /// **'On while the app is open. This device may store and forward public emergency SOS messages; it does not become a responder.'**
  String get nearbyRelayOn;

  /// No description provided for @nearbyRelayOff.
  ///
  /// In en, this message translates to:
  /// **'Off by default. Turn this on only to store and forward other people\'s public emergency SOS messages. Your own Public Relay SOS uses the consent selected for that incident.'**
  String get nearbyRelayOff;

  /// No description provided for @relayDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Relay Diagnostics'**
  String get relayDiagnostics;

  /// No description provided for @relayDiagnosticsDescription.
  ///
  /// In en, this message translates to:
  /// **'Read-only local Relay v2 evidence (developer builds)'**
  String get relayDiagnosticsDescription;

  /// No description provided for @bleTest.
  ///
  /// In en, this message translates to:
  /// **'BLE Test (Debug)'**
  String get bleTest;

  /// No description provided for @bleTestDescription.
  ///
  /// In en, this message translates to:
  /// **'Test nearby Bluetooth between phones'**
  String get bleTestDescription;

  /// No description provided for @emergencyCommunication.
  ///
  /// In en, this message translates to:
  /// **'Emergency communication'**
  String get emergencyCommunication;

  /// No description provided for @myAccount.
  ///
  /// In en, this message translates to:
  /// **'My account'**
  String get myAccount;

  /// No description provided for @savedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device'**
  String get savedOnDevice;

  /// No description provided for @noEmailAvailable.
  ///
  /// In en, this message translates to:
  /// **'No email available'**
  String get noEmailAvailable;

  /// No description provided for @signInForCloud.
  ///
  /// In en, this message translates to:
  /// **'Sign in for new cloud SOS'**
  String get signInForCloud;

  /// No description provided for @emailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get emailVerified;

  /// No description provided for @emailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Email not verified'**
  String get emailNotVerified;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @resetPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'We will send a password reset link to your email.'**
  String get resetPasswordDescription;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get pleaseWait;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get alreadyHaveAccount;

  /// No description provided for @createNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Create a new account'**
  String get createNewAccount;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @sendingResetLink.
  ///
  /// In en, this message translates to:
  /// **'Sending reset link…'**
  String get sendingResetLink;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get enterValidEmail;

  /// No description provided for @authFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in. Check your connection and try again.'**
  String get authFailed;

  /// No description provided for @checkEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkEmail;

  /// No description provided for @resetEmailPrivacy.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, you may receive a reset link.\nCheck your Inbox and Spam/Junk folder.'**
  String resetEmailPrivacy(String email);

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend Email'**
  String get resendEmail;

  /// No description provided for @manageAccount.
  ///
  /// In en, this message translates to:
  /// **'Manage your account and security settings.'**
  String get manageAccount;

  /// No description provided for @accountDetails.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT DETAILS'**
  String get accountDetails;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get account;

  /// No description provided for @verification.
  ///
  /// In en, this message translates to:
  /// **'VERIFICATION'**
  String get verification;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'SECURITY'**
  String get security;

  /// No description provided for @userId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userId;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @resetPasswordByEmail.
  ///
  /// In en, this message translates to:
  /// **'Send a password reset link by email'**
  String get resetPasswordByEmail;

  /// No description provided for @verifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify email address'**
  String get verifyEmail;

  /// No description provided for @verifyEmailDescription.
  ///
  /// In en, this message translates to:
  /// **'Send a verification link to your email'**
  String get verifyEmailDescription;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign out from this device'**
  String get signOutDescription;

  /// No description provided for @signOutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutQuestion;

  /// No description provided for @signOutWarning.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to use this account.'**
  String get signOutWarning;

  /// No description provided for @verificationSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent. Check your inbox.'**
  String get verificationSent;

  /// No description provided for @verificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to send verification email. Try again later.'**
  String get verificationFailed;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get genericError;

  /// No description provided for @noAccountEmail.
  ///
  /// In en, this message translates to:
  /// **'No email address is associated with this account.'**
  String get noAccountEmail;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Check your inbox.'**
  String get passwordResetSent;

  /// No description provided for @passwordResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to send password reset email. Please try again later.'**
  String get passwordResetFailed;

  /// No description provided for @passwordRecoveryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Secure password recovery is not configured yet. Contact support instead of using an email-only reset.'**
  String get passwordRecoveryUnavailable;

  /// No description provided for @signOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign out. Please try again.'**
  String get signOutFailed;

  /// No description provided for @roleQuestion.
  ///
  /// In en, this message translates to:
  /// **'What do you need today?'**
  String get roleQuestion;

  /// No description provided for @roleInstruction.
  ///
  /// In en, this message translates to:
  /// **'Choose a mode for this situation. You can switch modes later without deleting your data.'**
  String get roleInstruction;

  /// No description provided for @needHelpEyebrow.
  ///
  /// In en, this message translates to:
  /// **'NEED HELP'**
  String get needHelpEyebrow;

  /// No description provided for @needHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'I need help'**
  String get needHelpTitle;

  /// No description provided for @needHelpDescription.
  ///
  /// In en, this message translates to:
  /// **'Send an SOS, track nearby delivery, and return to an active incident.'**
  String get needHelpDescription;

  /// No description provided for @rescueEyebrow.
  ///
  /// In en, this message translates to:
  /// **'RESCUE'**
  String get rescueEyebrow;

  /// No description provided for @rescueTitle.
  ///
  /// In en, this message translates to:
  /// **'I want to help'**
  String get rescueTitle;

  /// No description provided for @rescueDescription.
  ///
  /// In en, this message translates to:
  /// **'Listen for nearby incidents, review details, and track incidents you are helping.'**
  String get rescueDescription;

  /// No description provided for @chooseMode.
  ///
  /// In en, this message translates to:
  /// **'Choose this mode'**
  String get chooseMode;

  /// No description provided for @roleTrustNotice.
  ///
  /// In en, this message translates to:
  /// **'A mode only changes the app layout. It does not verify identity, responder authority, or access to another person\'s incident.'**
  String get roleTrustNotice;

  /// No description provided for @emergencyChat.
  ///
  /// In en, this message translates to:
  /// **'Emergency chat'**
  String get emergencyChat;

  /// No description provided for @chatIncidentSemantics.
  ///
  /// In en, this message translates to:
  /// **'Chat for incident {incidentId}'**
  String chatIncidentSemantics(String incidentId);

  /// No description provided for @savedLocallyFirst.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device first'**
  String get savedLocallyFirst;

  /// No description provided for @chatNeedsRecipient.
  ///
  /// In en, this message translates to:
  /// **'Queued messages need a BLE recipient. Choose the intended peer; the app will not guess one.'**
  String get chatNeedsRecipient;

  /// No description provided for @assigning.
  ///
  /// In en, this message translates to:
  /// **'Assigning…'**
  String get assigning;

  /// No description provided for @chooseRecipient.
  ///
  /// In en, this message translates to:
  /// **'Choose recipient'**
  String get chooseRecipient;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @chooseIncidentBeforeChat.
  ///
  /// In en, this message translates to:
  /// **'Choose an incident before starting chat'**
  String get chooseIncidentBeforeChat;

  /// No description provided for @noChatMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet\nSend a short update that the other person needs to know.'**
  String get noChatMessages;

  /// No description provided for @emergencyMessage.
  ///
  /// In en, this message translates to:
  /// **'Emergency message'**
  String get emergencyMessage;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get typeMessage;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @statusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get statusQueued;

  /// No description provided for @statusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get statusSending;

  /// No description provided for @statusAwaitingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Relayed — delivery not confirmed'**
  String get statusAwaitingConfirmation;

  /// No description provided for @statusConfirmedStored.
  ///
  /// In en, this message translates to:
  /// **'Confirmed stored on the selected nearby device'**
  String get statusConfirmedStored;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusFailedRetryable.
  ///
  /// In en, this message translates to:
  /// **'Failed; retryable'**
  String get statusFailedRetryable;

  /// No description provided for @statusFailedNoRetry.
  ///
  /// In en, this message translates to:
  /// **'Delivery failed; retry not scheduled'**
  String get statusFailedNoRetry;

  /// No description provided for @statusFailedRetryScheduled.
  ///
  /// In en, this message translates to:
  /// **'Failed; retry scheduled'**
  String get statusFailedRetryScheduled;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @deliveryStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Delivery status is temporarily unavailable. The SOS remains saved locally.'**
  String get deliveryStatusUnavailable;

  /// No description provided for @savedNearbyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Saved locally. Nearby delivery is unavailable in this session.'**
  String get savedNearbyUnavailable;

  /// No description provided for @directStoredConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed stored on the selected nearby device.'**
  String get directStoredConfirmed;

  /// No description provided for @sentAwaitingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Sent to a nearby device; awaiting application confirmation.'**
  String get sentAwaitingConfirmation;

  /// No description provided for @storedOnRelay.
  ///
  /// In en, this message translates to:
  /// **'Stored on {count, plural, =1{1 relay device} other{{count} relay devices}}; final delivery is unconfirmed.'**
  String storedOnRelay(int count);

  /// No description provided for @forwardingAuthenticatedRelay.
  ///
  /// In en, this message translates to:
  /// **'Forwarding to an authenticated nearby relay.'**
  String get forwardingAuthenticatedRelay;

  /// No description provided for @nearbyFailedNoRetry.
  ///
  /// In en, this message translates to:
  /// **'Nearby delivery failed; no retry is currently scheduled.'**
  String get nearbyFailedNoRetry;

  /// No description provided for @nearbyFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Nearby delivery failed; retry is scheduled.'**
  String get nearbyFailedRetry;

  /// No description provided for @nearbyExpired.
  ///
  /// In en, this message translates to:
  /// **'Nearby delivery expired without confirmation.'**
  String get nearbyExpired;

  /// No description provided for @preparingNearbyRoute.
  ///
  /// In en, this message translates to:
  /// **'Preparing the trusted nearby route.'**
  String get preparingNearbyRoute;

  /// No description provided for @noRelayAccepted.
  ///
  /// In en, this message translates to:
  /// **'No relay accepted yet. The saved SOS will retry while eligible.'**
  String get noRelayAccepted;

  /// No description provided for @searchingEligibleDevice.
  ///
  /// In en, this message translates to:
  /// **'Searching for an eligible nearby device. Final delivery is unconfirmed.'**
  String get searchingEligibleDevice;

  /// No description provided for @foregroundLocationSharing.
  ///
  /// In en, this message translates to:
  /// **'Foreground location sharing'**
  String get foregroundLocationSharing;

  /// No description provided for @locationDeliverySemantics.
  ///
  /// In en, this message translates to:
  /// **'Location delivery: {status}'**
  String locationDeliverySemantics(String status);

  /// No description provided for @locationOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get locationOff;

  /// No description provided for @readyToSend.
  ///
  /// In en, this message translates to:
  /// **'Ready to send'**
  String get readyToSend;

  /// No description provided for @gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting location…'**
  String get gettingLocation;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @recipientLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient: {recipient}'**
  String recipientLabel(String recipient);

  /// No description provided for @recipientNotSelected.
  ///
  /// In en, this message translates to:
  /// **'not selected'**
  String get recipientNotSelected;

  /// No description provided for @locationOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Off. Choose a recipient before sharing.'**
  String get locationOffDescription;

  /// No description provided for @lastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last update: {time}'**
  String lastUpdate(String time);

  /// No description provided for @previousDelivery.
  ///
  /// In en, this message translates to:
  /// **'Previous delivery: {status}'**
  String previousDelivery(String status);

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get starting;

  /// No description provided for @startSharing.
  ///
  /// In en, this message translates to:
  /// **'Start sharing'**
  String get startSharing;

  /// No description provided for @sendLocation.
  ///
  /// In en, this message translates to:
  /// **'Send location'**
  String get sendLocation;

  /// No description provided for @stopSharing.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get stopSharing;

  /// No description provided for @selectRecipientToShare.
  ///
  /// In en, this message translates to:
  /// **'Select a connected recipient to start sharing.'**
  String get selectRecipientToShare;

  /// No description provided for @currentLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Current location is unavailable or invalid.'**
  String get currentLocationUnavailable;

  /// No description provided for @locationUnavailableSaved.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable — SOS was saved without coordinates'**
  String get locationUnavailableSaved;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location Services are disabled.'**
  String get locationServicesDisabled;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied.'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission is permanently denied. Open Settings.'**
  String get locationPermissionDeniedForever;

  /// No description provided for @locationTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Location request timed out.'**
  String get locationTimedOut;

  /// No description provided for @locationShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to share the current location. Try again.'**
  String get locationShareFailed;

  /// No description provided for @chooseBleRecipient.
  ///
  /// In en, this message translates to:
  /// **'Choose BLE recipient'**
  String get chooseBleRecipient;

  /// No description provided for @bleRecipientTrustNotice.
  ///
  /// In en, this message translates to:
  /// **'Select the intended nearby device. The identifier is a transport identifier and is not verified as a person identity.'**
  String get bleRecipientTrustNotice;

  /// No description provided for @bleNotReady.
  ///
  /// In en, this message translates to:
  /// **'BLE is not ready'**
  String get bleNotReady;

  /// No description provided for @scanningNearby.
  ///
  /// In en, this message translates to:
  /// **'Scanning for nearby devices…'**
  String get scanningNearby;

  /// No description provided for @unnamedDevice.
  ///
  /// In en, this message translates to:
  /// **'Unnamed device'**
  String get unnamedDevice;

  /// No description provided for @deviceStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String deviceStatus(String status);

  /// No description provided for @useDevice.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get useDevice;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @continueWithoutRecipient.
  ///
  /// In en, this message translates to:
  /// **'Continue without recipient'**
  String get continueWithoutRecipient;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @sosHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to send SOS'**
  String get sosHold;

  /// No description provided for @sendSos.
  ///
  /// In en, this message translates to:
  /// **'Send SOS'**
  String get sendSos;

  /// No description provided for @creatingSos.
  ///
  /// In en, this message translates to:
  /// **'Creating SOS…'**
  String get creatingSos;

  /// No description provided for @keepHolding.
  ///
  /// In en, this message translates to:
  /// **'Keep holding'**
  String get keepHolding;

  /// No description provided for @checkingLocation.
  ///
  /// In en, this message translates to:
  /// **'Checking location'**
  String get checkingLocation;

  /// No description provided for @holdToStart.
  ///
  /// In en, this message translates to:
  /// **'Hold to start'**
  String get holdToStart;

  /// No description provided for @openActiveChat.
  ///
  /// In en, this message translates to:
  /// **'Open active SOS chat'**
  String get openActiveChat;

  /// No description provided for @activeSos.
  ///
  /// In en, this message translates to:
  /// **'SOS in progress'**
  String get activeSos;

  /// No description provided for @tapToOpenIncidentChat.
  ///
  /// In en, this message translates to:
  /// **'Tap to open chat · Incident {incidentId}'**
  String tapToOpenIncidentChat(String incidentId);

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'SOS History'**
  String get historyTitle;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search history'**
  String get searchHistory;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @newestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first · tap for oldest first'**
  String get newestFirst;

  /// No description provided for @oldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first · tap for newest first'**
  String get oldestFirst;

  /// No description provided for @deviceData.
  ///
  /// In en, this message translates to:
  /// **'Data on this device'**
  String get deviceData;

  /// No description provided for @accountHistoryPendingSync.
  ///
  /// In en, this message translates to:
  /// **'Current account history (including pending sync)'**
  String get accountHistoryPendingSync;

  /// No description provided for @historySearch.
  ///
  /// In en, this message translates to:
  /// **'Search SOS or message'**
  String get historySearch;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get filterActive;

  /// No description provided for @filterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get filterCompleted;

  /// No description provided for @filterCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get filterCancelled;

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String itemCount(int count);

  /// No description provided for @waitingForRecipient.
  ///
  /// In en, this message translates to:
  /// **'Waiting for recipient'**
  String get waitingForRecipient;

  /// No description provided for @waitingReceiverConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Awaiting receiver confirmation'**
  String get waitingReceiverConfirmation;

  /// No description provided for @nearbyRescueCenter.
  ///
  /// In en, this message translates to:
  /// **'Nearby rescue center'**
  String get nearbyRescueCenter;

  /// No description provided for @receivedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Incidents received over BLE on this device'**
  String get receivedOnDevice;

  /// No description provided for @switchToNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Switch to Need Help mode'**
  String get switchToNeedHelp;

  /// No description provided for @readyForNearbyIncidents.
  ///
  /// In en, this message translates to:
  /// **'Ready for nearby incidents'**
  String get readyForNearbyIncidents;

  /// No description provided for @listenWhenReady.
  ///
  /// In en, this message translates to:
  /// **'Start listening when you are ready'**
  String get listenWhenReady;

  /// No description provided for @rescueListeningDescription.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is accepting connections. Keep the app in the foreground for the most reliable operation.'**
  String get rescueListeningDescription;

  /// No description provided for @rescueOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permission is requested only after you start listening. A connection is not treated as human acceptance.'**
  String get rescueOffDescription;

  /// No description provided for @incidentMap.
  ///
  /// In en, this message translates to:
  /// **'Incident Map'**
  String get incidentMap;

  /// No description provided for @mapTilesRequireInternet.
  ///
  /// In en, this message translates to:
  /// **'Map tiles require internet. Coordinates remain available offline.'**
  String get mapTilesRequireInternet;

  /// No description provided for @finalDeliveryUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Final delivery unconfirmed'**
  String get finalDeliveryUnconfirmed;

  /// No description provided for @activeIncidentExists.
  ///
  /// In en, this message translates to:
  /// **'An incident is still active'**
  String get activeIncidentExists;

  /// No description provided for @roleSwitchPreservesData.
  ///
  /// In en, this message translates to:
  /// **'Switching modes does not cancel the incident, delete data, or stop the BLE queue. You can return to it at any time.'**
  String get roleSwitchPreservesData;

  /// No description provided for @stayInMode.
  ///
  /// In en, this message translates to:
  /// **'Stay in this mode'**
  String get stayInMode;

  /// No description provided for @switchMode.
  ///
  /// In en, this message translates to:
  /// **'Switch mode'**
  String get switchMode;

  /// No description provided for @rescuePreparingBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Preparing Bluetooth…'**
  String get rescuePreparingBluetooth;

  /// No description provided for @rescueListening.
  ///
  /// In en, this message translates to:
  /// **'Listening for incidents'**
  String get rescueListening;

  /// No description provided for @startRescueListening.
  ///
  /// In en, this message translates to:
  /// **'Start listening'**
  String get startRescueListening;

  /// No description provided for @receivedIncidents.
  ///
  /// In en, this message translates to:
  /// **'Received incidents'**
  String get receivedIncidents;

  /// No description provided for @incidentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 incident} other{{count} incidents}}'**
  String incidentCount(int count);

  /// No description provided for @helpingIncidents.
  ///
  /// In en, this message translates to:
  /// **'Incidents being helped'**
  String get helpingIncidents;

  /// No description provided for @switchModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch mode'**
  String get switchModeTooltip;

  /// No description provided for @storedOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Stored on this device'**
  String get storedOnThisDevice;

  /// No description provided for @helpingStateNotice.
  ///
  /// In en, this message translates to:
  /// **'This state helps you reopen an incident quickly. It is not an exclusive assignment and does not send a human acceptance to the person requesting help.'**
  String get helpingStateNotice;

  /// No description provided for @noTrackedIncidents.
  ///
  /// In en, this message translates to:
  /// **'No tracked incidents'**
  String get noTrackedIncidents;

  /// No description provided for @trackIncidentHint.
  ///
  /// In en, this message translates to:
  /// **'Choose “Track on this device” from a received incident to pin it here.'**
  String get trackIncidentHint;

  /// No description provided for @viewReceivedIncidents.
  ///
  /// In en, this message translates to:
  /// **'View received incidents'**
  String get viewReceivedIncidents;

  /// No description provided for @noReceivedIncidents.
  ///
  /// In en, this message translates to:
  /// **'No incidents received'**
  String get noReceivedIncidents;

  /// No description provided for @receivedIncidentHint.
  ///
  /// In en, this message translates to:
  /// **'Start listening and have the sender choose this device. The incident appears after it is stored successfully.'**
  String get receivedIncidentHint;

  /// No description provided for @openTrackedIncident.
  ///
  /// In en, this message translates to:
  /// **'Open tracked incident'**
  String get openTrackedIncident;

  /// No description provided for @rescueStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to start listening: {error}'**
  String rescueStartFailed(String error);

  /// No description provided for @switchToRescue.
  ///
  /// In en, this message translates to:
  /// **'Switch to Rescue mode'**
  String get switchToRescue;

  /// No description provided for @locationServices.
  ///
  /// In en, this message translates to:
  /// **'Location Services'**
  String get locationServices;

  /// No description provided for @permission.
  ///
  /// In en, this message translates to:
  /// **'Permission'**
  String get permission;

  /// No description provided for @openLocationSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Location Settings'**
  String get openLocationSettings;

  /// No description provided for @openAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open App Settings'**
  String get openAppSettings;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @incidentChats.
  ///
  /// In en, this message translates to:
  /// **'Incident chats'**
  String get incidentChats;

  /// No description provided for @noChatIncidents.
  ///
  /// In en, this message translates to:
  /// **'No incidents available for chat'**
  String get noChatIncidents;

  /// No description provided for @openIncidentChatSemantics.
  ///
  /// In en, this message translates to:
  /// **'Open chat for {type} incident {incidentId}'**
  String openIncidentChatSemantics(String type, String incidentId);

  /// No description provided for @enableLocationServices.
  ///
  /// In en, this message translates to:
  /// **'Please enable Location Services and try again.'**
  String get enableLocationServices;

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to send SOS.'**
  String get locationPermissionRequired;

  /// No description provided for @unableGetLocation.
  ///
  /// In en, this message translates to:
  /// **'Unable to get your current location.'**
  String get unableGetLocation;

  /// No description provided for @sosSavedRelaySearching.
  ///
  /// In en, this message translates to:
  /// **'SOS saved. Searching for opted-in relay devices; final delivery is unconfirmed.'**
  String get sosSavedRelaySearching;

  /// No description provided for @sosSavedWithLocation.
  ///
  /// In en, this message translates to:
  /// **'SOS saved with location. Waiting for a trusted nearby route.'**
  String get sosSavedWithLocation;

  /// No description provided for @sosSavedLocally.
  ///
  /// In en, this message translates to:
  /// **'SOS saved locally. Waiting for a trusted nearby route.'**
  String get sosSavedLocally;

  /// No description provided for @sosSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send SOS: {error}'**
  String sosSendFailed(String error);

  /// No description provided for @deviceHistory.
  ///
  /// In en, this message translates to:
  /// **'Data on this device'**
  String get deviceHistory;

  /// No description provided for @guestHistoryNotice.
  ///
  /// In en, this message translates to:
  /// **'Guest SOS stays on this device, is not linked to an account, and is not uploaded to the cloud.'**
  String get guestHistoryNotice;

  /// No description provided for @noGuestHistory.
  ///
  /// In en, this message translates to:
  /// **'No Guest data on this device'**
  String get noGuestHistory;

  /// No description provided for @sosDetails.
  ///
  /// In en, this message translates to:
  /// **'SOS Details'**
  String get sosDetails;

  /// No description provided for @manageSos.
  ///
  /// In en, this message translates to:
  /// **'Manage SOS'**
  String get manageSos;

  /// No description provided for @editMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get editMessage;

  /// No description provided for @deleteSos.
  ///
  /// In en, this message translates to:
  /// **'Delete SOS'**
  String get deleteSos;

  /// No description provided for @closeSosDetails.
  ///
  /// In en, this message translates to:
  /// **'Close SOS details'**
  String get closeSosDetails;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @humanResponse.
  ///
  /// In en, this message translates to:
  /// **'Human response'**
  String get humanResponse;

  /// No description provided for @noHumanConfirmation.
  ///
  /// In en, this message translates to:
  /// **'The current protocol has no verified human acceptance. BLE status only confirms storage on the receiving device.'**
  String get noHumanConfirmation;

  /// No description provided for @responderStatus.
  ///
  /// In en, this message translates to:
  /// **'Helper status'**
  String get responderStatus;

  /// No description provided for @sharedLocation.
  ///
  /// In en, this message translates to:
  /// **'Shared location'**
  String get sharedLocation;

  /// No description provided for @noVerifiedSharedLocation.
  ///
  /// In en, this message translates to:
  /// **'No verified shared location is available for this incident.'**
  String get noVerifiedSharedLocation;

  /// No description provided for @viewSharedLocation.
  ///
  /// In en, this message translates to:
  /// **'View shared location'**
  String get viewSharedLocation;

  /// No description provided for @created.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// No description provided for @updated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updated;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @deviceOnly.
  ///
  /// In en, this message translates to:
  /// **'On this device only'**
  String get deviceOnly;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get pendingSync;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @openIncidentChat.
  ///
  /// In en, this message translates to:
  /// **'Open incident chat'**
  String get openIncidentChat;

  /// No description provided for @viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get viewOnMap;

  /// No description provided for @markResolved.
  ///
  /// In en, this message translates to:
  /// **'Mark as Resolved'**
  String get markResolved;

  /// No description provided for @cancelSos.
  ///
  /// In en, this message translates to:
  /// **'Cancel SOS'**
  String get cancelSos;

  /// No description provided for @bleDelivery.
  ///
  /// In en, this message translates to:
  /// **'BLE delivery'**
  String get bleDelivery;

  /// No description provided for @recipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipient;

  /// No description provided for @unableSetRecipient.
  ///
  /// In en, this message translates to:
  /// **'Unable to set recipient: {error}'**
  String unableSetRecipient(String error);

  /// No description provided for @publicSosRelay.
  ///
  /// In en, this message translates to:
  /// **'Public SOS relay'**
  String get publicSosRelay;

  /// No description provided for @relayExpiredUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Relay expired before final delivery could be confirmed'**
  String get relayExpiredUnconfirmed;

  /// No description provided for @relayForwardingUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Forwarding through nearby devices; final delivery unconfirmed'**
  String get relayForwardingUnconfirmed;

  /// No description provided for @relayRetryUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Waiting to retry relay forwarding; final delivery unconfirmed'**
  String get relayRetryUnconfirmed;

  /// No description provided for @relayWaitingUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Waiting to forward; final delivery unconfirmed'**
  String get relayWaitingUnconfirmed;

  /// No description provided for @deleteSosQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete SOS?'**
  String get deleteSosQuestion;

  /// No description provided for @deleteCannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteCannotUndo;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @editSos.
  ///
  /// In en, this message translates to:
  /// **'Edit SOS'**
  String get editSos;

  /// No description provided for @describeEmergency.
  ///
  /// In en, this message translates to:
  /// **'Describe the emergency'**
  String get describeEmergency;

  /// No description provided for @downloadVisibleArea.
  ///
  /// In en, this message translates to:
  /// **'Download visible area'**
  String get downloadVisibleArea;

  /// No description provided for @offlineDownloadRequiresProvider.
  ///
  /// In en, this message translates to:
  /// **'Offline downloads require the production Geoapify provider'**
  String get offlineDownloadRequiresProvider;

  /// No description provided for @manageOfflineMaps.
  ///
  /// In en, this message translates to:
  /// **'Manage offline maps'**
  String get manageOfflineMaps;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @centerCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Center map on current location'**
  String get centerCurrentLocation;

  /// No description provided for @refreshCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Refresh current location'**
  String get refreshCurrentLocation;

  /// No description provided for @sharedLocationAvailable.
  ///
  /// In en, this message translates to:
  /// **'Shared location available from the matched peer.'**
  String get sharedLocationAvailable;

  /// No description provided for @sharedLocationExpired.
  ///
  /// In en, this message translates to:
  /// **'Shared location is expired and is not shown as current.'**
  String get sharedLocationExpired;

  /// No description provided for @sharedLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Shared location is unavailable.'**
  String get sharedLocationUnavailable;

  /// No description provided for @currentLocationIncidentAvailable.
  ///
  /// In en, this message translates to:
  /// **'Current location unavailable. Incident location remains available.'**
  String get currentLocationIncidentAvailable;

  /// No description provided for @currentLocationStale.
  ///
  /// In en, this message translates to:
  /// **'Current location is stale. Refresh before relying on it.'**
  String get currentLocationStale;

  /// No description provided for @currentLocationAvailable.
  ///
  /// In en, this message translates to:
  /// **'Current location available.'**
  String get currentLocationAvailable;

  /// No description provided for @incidentCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Incident: {latitude}, {longitude}'**
  String incidentCoordinates(String latitude, String longitude);

  /// No description provided for @incidentCoordinatesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Incident coordinates are not available.'**
  String get incidentCoordinatesUnavailable;

  /// No description provided for @downloadedTilesAvailable.
  ///
  /// In en, this message translates to:
  /// **'Downloaded map tiles are available offline. Missing tiles still require internet.'**
  String get downloadedTilesAvailable;

  /// No description provided for @preparingMapStorage.
  ///
  /// In en, this message translates to:
  /// **'Preparing map storage…'**
  String get preparingMapStorage;

  /// No description provided for @downloadingTiles.
  ///
  /// In en, this message translates to:
  /// **'Downloading {completed}/{total} tiles'**
  String downloadingTiles(int completed, int total);

  /// No description provided for @retryMapTiles.
  ///
  /// In en, this message translates to:
  /// **'Retry map tiles'**
  String get retryMapTiles;

  /// No description provided for @mapProviderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Map provider is unavailable for this build.'**
  String get mapProviderUnavailable;

  /// No description provided for @developmentTileProvider.
  ///
  /// In en, this message translates to:
  /// **'Development tile provider; configure MAP_TILE_URL for production.'**
  String get developmentTileProvider;

  /// No description provided for @noIncidentLocation.
  ///
  /// In en, this message translates to:
  /// **'No location is available for this incident.'**
  String get noIncidentLocation;

  /// No description provided for @mapName.
  ///
  /// In en, this message translates to:
  /// **'Map name'**
  String get mapName;

  /// No description provided for @minimumZoom.
  ///
  /// In en, this message translates to:
  /// **'Minimum zoom: {zoom}'**
  String minimumZoom(int zoom);

  /// No description provided for @maximumZoom.
  ///
  /// In en, this message translates to:
  /// **'Maximum zoom: {zoom}'**
  String maximumZoom(int zoom);

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @offlineMaps.
  ///
  /// In en, this message translates to:
  /// **'Offline maps'**
  String get offlineMaps;

  /// No description provided for @noDownloadedRegions.
  ///
  /// In en, this message translates to:
  /// **'No downloaded map regions.'**
  String get noDownloadedRegions;

  /// No description provided for @offlineDownloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Offline map download cancelled.'**
  String get offlineDownloadCancelled;

  /// No description provided for @chatSavedPending.
  ///
  /// In en, this message translates to:
  /// **'Saved locally; BLE delivery is pending.'**
  String get chatSavedPending;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Message could not be sent. Try again.'**
  String get chatSendFailed;

  /// No description provided for @noQueuedMessagesNeedRecipient.
  ///
  /// In en, this message translates to:
  /// **'No queued messages needed a recipient.'**
  String get noQueuedMessagesNeedRecipient;

  /// No description provided for @recipientAssigned.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Recipient assigned to 1 queued message.} other{Recipient assigned to {count} queued messages.}}'**
  String recipientAssigned(int count);

  /// No description provided for @assignRecipientFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to assign recipient: {error}'**
  String assignRecipientFailed(String error);

  /// No description provided for @developerToolUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Developer tool unavailable'**
  String get developerToolUnavailable;

  /// No description provided for @relayDiagnosticsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Relay diagnostics unavailable'**
  String get relayDiagnosticsUnavailable;

  /// No description provided for @relayDiagnosticsReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The local relay state could not be read. No data changed.'**
  String get relayDiagnosticsReadFailed;

  /// No description provided for @noRelayRecords.
  ///
  /// In en, this message translates to:
  /// **'No relay records'**
  String get noRelayRecords;

  /// No description provided for @noRelayRecordsDescription.
  ///
  /// In en, this message translates to:
  /// **'This device has no retained Relay v2 messages. Relay-only records never appear in SOS History.'**
  String get noRelayRecordsDescription;

  /// No description provided for @relayEvidenceNotice.
  ///
  /// In en, this message translates to:
  /// **'Developer evidence only. A hop receipt proves storage by the next relay; it does not prove that a responder received the SOS.'**
  String get relayEvidenceNotice;

  /// No description provided for @relayMessagesStored.
  ///
  /// In en, this message translates to:
  /// **'Relay messages stored: {count}'**
  String relayMessagesStored(int count);

  /// No description provided for @locallyOriginatedSos.
  ///
  /// In en, this message translates to:
  /// **'Locally originated SOS'**
  String get locallyOriginatedSos;

  /// No description provided for @relayOnlyEnvelope.
  ///
  /// In en, this message translates to:
  /// **'Relay-only envelope'**
  String get relayOnlyEnvelope;

  /// No description provided for @messageId.
  ///
  /// In en, this message translates to:
  /// **'Message ID'**
  String get messageId;

  /// No description provided for @payloadDigest.
  ///
  /// In en, this message translates to:
  /// **'Payload digest'**
  String get payloadDigest;

  /// No description provided for @incomingHopCount.
  ///
  /// In en, this message translates to:
  /// **'Incoming hop count'**
  String get incomingHopCount;

  /// No description provided for @latestPersisted.
  ///
  /// In en, this message translates to:
  /// **'Latest persisted'**
  String get latestPersisted;

  /// No description provided for @latestRelayJobStatus.
  ///
  /// In en, this message translates to:
  /// **'Latest relay job status'**
  String get latestRelayJobStatus;

  /// No description provided for @relayAttemptCount.
  ///
  /// In en, this message translates to:
  /// **'Relay attempt count'**
  String get relayAttemptCount;

  /// No description provided for @hopReceipt.
  ///
  /// In en, this message translates to:
  /// **'Hop receipt'**
  String get hopReceipt;

  /// No description provided for @hopReceiptsStored.
  ///
  /// In en, this message translates to:
  /// **'Hop receipts stored'**
  String get hopReceiptsStored;

  /// No description provided for @finalResponderReceipt.
  ///
  /// In en, this message translates to:
  /// **'Final responder receipt'**
  String get finalResponderReceipt;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @notConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed'**
  String get notConfirmed;

  /// No description provided for @finalReceiptsStored.
  ///
  /// In en, this message translates to:
  /// **'Final receipts stored'**
  String get finalReceiptsStored;

  /// No description provided for @lastRelayErrorCategory.
  ///
  /// In en, this message translates to:
  /// **'Last relay error category'**
  String get lastRelayErrorCategory;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @storedOnRelayStatus.
  ///
  /// In en, this message translates to:
  /// **'Stored on relay'**
  String get storedOnRelayStatus;

  /// No description provided for @storedByNextRelay.
  ///
  /// In en, this message translates to:
  /// **'Stored by next relay'**
  String get storedByNextRelay;

  /// No description provided for @awaitingHopReceipt.
  ///
  /// In en, this message translates to:
  /// **'Awaiting hop receipt'**
  String get awaitingHopReceipt;

  /// No description provided for @finalReceiptRecorded.
  ///
  /// In en, this message translates to:
  /// **'Final receipt recorded'**
  String get finalReceiptRecorded;

  /// No description provided for @receivedFromNextRelay.
  ///
  /// In en, this message translates to:
  /// **'Received from next relay'**
  String get receivedFromNextRelay;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @failedOrExpired.
  ///
  /// In en, this message translates to:
  /// **'Failed or expired'**
  String get failedOrExpired;

  /// No description provided for @notRecordedLocally.
  ///
  /// In en, this message translates to:
  /// **'Not recorded locally'**
  String get notRecordedLocally;

  /// No description provided for @resolveSosQuestion.
  ///
  /// In en, this message translates to:
  /// **'Resolve SOS?'**
  String get resolveSosQuestion;

  /// No description provided for @cancelSosQuestion.
  ///
  /// In en, this message translates to:
  /// **'Cancel SOS?'**
  String get cancelSosQuestion;

  /// No description provided for @resolveSosConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to mark this SOS as resolved?'**
  String get resolveSosConfirmation;

  /// No description provided for @cancelSosConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this SOS?'**
  String get cancelSosConfirmation;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @resolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get resolve;

  /// No description provided for @sosMarkedResolved.
  ///
  /// In en, this message translates to:
  /// **'SOS marked as resolved.'**
  String get sosMarkedResolved;

  /// No description provided for @sosCancelled.
  ///
  /// In en, this message translates to:
  /// **'SOS cancelled.'**
  String get sosCancelled;

  /// No description provided for @failedUpdateSos.
  ///
  /// In en, this message translates to:
  /// **'Failed to update SOS: {error}'**
  String failedUpdateSos(String error);

  /// No description provided for @sosUpdated.
  ///
  /// In en, this message translates to:
  /// **'SOS updated.'**
  String get sosUpdated;

  /// No description provided for @sosDeleted.
  ///
  /// In en, this message translates to:
  /// **'SOS deleted.'**
  String get sosDeleted;

  /// No description provided for @failedDeleteSos.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete SOS: {error}'**
  String failedDeleteSos(String error);

  /// No description provided for @syncCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sync completed.'**
  String get syncCompleted;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String syncFailed(String error);

  /// No description provided for @localDataOnly.
  ///
  /// In en, this message translates to:
  /// **'Local data only'**
  String get localDataOnly;

  /// No description provided for @tapToOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Tap to open chat'**
  String get tapToOpenChat;

  /// No description provided for @tapToViewDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap to view details'**
  String get tapToViewDetails;

  /// No description provided for @unableOpenAttribution.
  ///
  /// In en, this message translates to:
  /// **'Unable to open attribution link.'**
  String get unableOpenAttribution;

  /// No description provided for @offlineRegionAvailable.
  ///
  /// In en, this message translates to:
  /// **'{name} is available offline.'**
  String offlineRegionAvailable(String name);

  /// No description provided for @deleteNamedItem.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}'**
  String deleteNamedItem(String name);

  /// No description provided for @offlineRegionSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} tiles · {size} · zoom {minZoom}–{maxZoom}'**
  String offlineRegionSummary(int count, String size, int minZoom, int maxZoom);

  /// No description provided for @bleTestDebug.
  ///
  /// In en, this message translates to:
  /// **'BLE Test (Debug)'**
  String get bleTestDebug;

  /// No description provided for @debugToolOnly.
  ///
  /// In en, this message translates to:
  /// **'Debug tool only'**
  String get debugToolOnly;

  /// No description provided for @debugToolSafety.
  ///
  /// In en, this message translates to:
  /// **'This screen does not create or send production SOS alerts.'**
  String get debugToolSafety;

  /// No description provided for @bluetoothStatus.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth status'**
  String get bluetoothStatus;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @blePlatformCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Android and iOS support scan, advertise, connect, write and receive BLE data. Foreground testing is required. Range diagnostics use an application ACK; ordinary test messages report native write acceptance only.'**
  String get blePlatformCapabilities;

  /// No description provided for @startScan.
  ///
  /// In en, this message translates to:
  /// **'Start Scan'**
  String get startScan;

  /// No description provided for @stopScan.
  ///
  /// In en, this message translates to:
  /// **'Stop Scan'**
  String get stopScan;

  /// No description provided for @startAdvertising.
  ///
  /// In en, this message translates to:
  /// **'Start Advertising'**
  String get startAdvertising;

  /// No description provided for @stopAdvertising.
  ///
  /// In en, this message translates to:
  /// **'Stop Advertising'**
  String get stopAdvertising;

  /// No description provided for @discoveredDevices.
  ///
  /// In en, this message translates to:
  /// **'Discovered devices'**
  String get discoveredDevices;

  /// No description provided for @noDevicesDiscovered.
  ///
  /// In en, this message translates to:
  /// **'No devices discovered yet. Start a scan on both devices.'**
  String get noDevicesDiscovered;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @testMessage.
  ///
  /// In en, this message translates to:
  /// **'Test message'**
  String get testMessage;

  /// No description provided for @bleRangeDiagnostic.
  ///
  /// In en, this message translates to:
  /// **'BLE range / quality diagnostic'**
  String get bleRangeDiagnostic;

  /// No description provided for @rangeDiagnosticSafety.
  ///
  /// In en, this message translates to:
  /// **'Record the real distance yourself. RSSI is signal strength and is never converted to distance. Repeat each distance in open and obstructed conditions.'**
  String get rangeDiagnosticSafety;

  /// No description provided for @startRangeRun.
  ///
  /// In en, this message translates to:
  /// **'Start range run'**
  String get startRangeRun;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @receivedMessages.
  ///
  /// In en, this message translates to:
  /// **'Received messages ({count})'**
  String receivedMessages(int count);

  /// No description provided for @noCompleteMessages.
  ///
  /// In en, this message translates to:
  /// **'No complete messages received yet.'**
  String get noCompleteMessages;

  /// No description provided for @diagnosticLog.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic log'**
  String get diagnosticLog;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @noDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'No diagnostics yet.'**
  String get noDiagnostics;

  /// No description provided for @mapConfigProductionProviderMissing.
  ///
  /// In en, this message translates to:
  /// **'A production map provider is not configured for this build.'**
  String get mapConfigProductionProviderMissing;

  /// No description provided for @mapConfigUrlMissing.
  ///
  /// In en, this message translates to:
  /// **'The map service address is missing.'**
  String get mapConfigUrlMissing;

  /// No description provided for @mapConfigUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'The map service address must use HTTPS.'**
  String get mapConfigUrlInvalid;

  /// No description provided for @mapConfigPublicOsmBlocked.
  ///
  /// In en, this message translates to:
  /// **'The public OpenStreetMap tile service is not available in release builds.'**
  String get mapConfigPublicOsmBlocked;

  /// No description provided for @mapConfigGeoapifyKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'The map service key is missing.'**
  String get mapConfigGeoapifyKeyMissing;

  /// No description provided for @mapConfigTemplateInvalid.
  ///
  /// In en, this message translates to:
  /// **'The map service configuration is incomplete.'**
  String get mapConfigTemplateInvalid;

  /// No description provided for @mapConfigAttributionMissing.
  ///
  /// In en, this message translates to:
  /// **'Required map attribution is missing.'**
  String get mapConfigAttributionMissing;

  /// No description provided for @mapConfigGeoapifyAttributionIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Geoapify and OpenStreetMap attribution are required.'**
  String get mapConfigGeoapifyAttributionIncomplete;

  /// No description provided for @mapConfigUserAgentMissing.
  ///
  /// In en, this message translates to:
  /// **'The map service identity is missing.'**
  String get mapConfigUserAgentMissing;

  /// No description provided for @offlineMapStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Offline map storage is unavailable on this device.'**
  String get offlineMapStorageUnavailable;

  /// No description provided for @offlineMapDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The offline map could not be downloaded. Check your connection, storage, and map provider.'**
  String get offlineMapDownloadFailed;

  /// No description provided for @incidentCoordinatesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Incident coordinates are unavailable or invalid.'**
  String get incidentCoordinatesInvalid;

  /// No description provided for @sharedCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Shared: {latitude}, {longitude} · {time}'**
  String sharedCoordinates(String latitude, String longitude, String time);

  /// No description provided for @mapLegend.
  ///
  /// In en, this message translates to:
  /// **'Red: incident · Purple: shared · Blue: current device'**
  String get mapLegend;

  /// No description provided for @offlineMapDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Incident area {date}'**
  String offlineMapDefaultName(String date);

  /// No description provided for @offlineTileEstimate.
  ///
  /// In en, this message translates to:
  /// **'{count} tiles · about {megabytes} MB'**
  String offlineTileEstimate(int count, String megabytes);

  /// No description provided for @offlineMapTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Reduce the visible area or zoom range. The safety limit is {maxTiles} tiles.'**
  String offlineMapTooLarge(int maxTiles);

  /// No description provided for @offlineMapDownloadInfo.
  ///
  /// In en, this message translates to:
  /// **'Keep this app open during download. Only the visible bounded area is stored.'**
  String get offlineMapDownloadInfo;

  /// No description provided for @offlineMapStorageSummary.
  ///
  /// In en, this message translates to:
  /// **'Stored: {size}'**
  String offlineMapStorageSummary(String size);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
