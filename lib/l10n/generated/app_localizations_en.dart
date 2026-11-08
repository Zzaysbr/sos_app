// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Emergency';

  @override
  String get authStatusUnavailable => 'Unable to check authentication status.';

  @override
  String get navNearby => 'Nearby';

  @override
  String get navHelping => 'Helping';

  @override
  String get navHelp => 'Need help';

  @override
  String get navHelpCompact => 'SOS';

  @override
  String get navHistory => 'History';

  @override
  String get navChat => 'Chat';

  @override
  String get navSettings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get preferences => 'PREFERENCES';

  @override
  String get language => 'Language';

  @override
  String get languageDescription => 'Choose the app display language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageThai => 'Thai';

  @override
  String get languageSaveFailed =>
      'Language could not be saved. The previous language remains active.';

  @override
  String get usageMode => 'Usage mode';

  @override
  String get modeRescueDescription => 'Rescue · tap to change mode';

  @override
  String get modeNeedHelpDescription => 'Need help · tap to change mode';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsDescription => 'SOS updates and in-app alerts';

  @override
  String get notificationsReady => 'Notifications are ready';

  @override
  String get notificationsReadyDetail => 'SOS updates will appear here.';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get noNotifications => 'No notifications yet.';

  @override
  String get location => 'Location';

  @override
  String get locationSettingsDescription => 'Permission and location services';

  @override
  String get automaticPublicRelay => 'Automatic public relay for my SOS';

  @override
  String get automaticPublicRelayOn =>
      'On. During an emergency, signed SOS data may be stored and forwarded by opted-in nearby devices for up to 30 minutes.';

  @override
  String get automaticPublicRelayOff =>
      'Off. Configure this before an emergency. Bluetooth permission alone never enables public relay.';

  @override
  String get includeLocationRelay => 'Include location in public relay';

  @override
  String get includeLocationRelayDescription =>
      'Separate consent. When off, relay messages contain no coordinates.';

  @override
  String get nearbyRelay => 'Nearby SOS relay';

  @override
  String get nearbyRelayOn =>
      'On while the app is open. This device may store and forward public emergency SOS messages; it does not become a responder.';

  @override
  String get nearbyRelayOff =>
      'Off by default. Turn this on only to store and forward other people\'s public emergency SOS messages. Your own Public Relay SOS uses the consent selected for that incident.';

  @override
  String get relayDiagnostics => 'Relay Diagnostics';

  @override
  String get relayDiagnosticsDescription =>
      'Read-only local Relay v2 evidence (developer builds)';

  @override
  String get bleTest => 'BLE Test (Debug)';

  @override
  String get bleTestDescription => 'Test nearby Bluetooth between phones';

  @override
  String get emergencyCommunication => 'Emergency communication';

  @override
  String get myAccount => 'My account';

  @override
  String get savedOnDevice => 'Saved on this device';

  @override
  String get noEmailAvailable => 'No email available';

  @override
  String get signInForCloud => 'Sign in for new cloud SOS';

  @override
  String get emailVerified => 'Email verified';

  @override
  String get emailNotVerified => 'Email not verified';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get createAccount => 'Create account';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get resetPasswordDescription =>
      'We will send a password reset link to your email.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get pleaseWait => 'Please wait…';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get backToLogin => 'Back to Login';

  @override
  String get alreadyHaveAccount => 'Already have an account? Login';

  @override
  String get createNewAccount => 'Create a new account';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get sendingResetLink => 'Sending reset link…';

  @override
  String get enterValidEmail => 'Enter a valid email address.';

  @override
  String get authFailed =>
      'Unable to sign in. Check your connection and try again.';

  @override
  String get checkEmail => 'Check your email';

  @override
  String resetEmailPrivacy(String email) {
    return 'If an account exists for $email, you may receive a reset link.\nCheck your Inbox and Spam/Junk folder.';
  }

  @override
  String resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get resendEmail => 'Resend Email';

  @override
  String get manageAccount => 'Manage your account and security settings.';

  @override
  String get accountDetails => 'ACCOUNT DETAILS';

  @override
  String get account => 'ACCOUNT';

  @override
  String get verification => 'VERIFICATION';

  @override
  String get security => 'SECURITY';

  @override
  String get userId => 'User ID';

  @override
  String get unknown => 'Unknown';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get resetPasswordByEmail => 'Send a password reset link by email';

  @override
  String get verifyEmail => 'Verify email address';

  @override
  String get verifyEmailDescription => 'Send a verification link to your email';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutDescription => 'Sign out from this device';

  @override
  String get signOutQuestion => 'Sign out?';

  @override
  String get signOutWarning =>
      'You will need to sign in again to use this account.';

  @override
  String get verificationSent => 'Verification email sent. Check your inbox.';

  @override
  String get verificationFailed =>
      'Unable to send verification email. Try again later.';

  @override
  String get genericError => 'Something went wrong. Please try again.';

  @override
  String get noAccountEmail =>
      'No email address is associated with this account.';

  @override
  String get passwordResetSent =>
      'If an account exists for this email, password reset instructions were sent.';

  @override
  String get passwordResetFailed =>
      'Unable to send password reset email. Please try again later.';

  @override
  String get passwordRecoveryUnavailable =>
      'Secure password recovery is not configured yet. Contact support instead of using an email-only reset.';

  @override
  String get signOutFailed => 'Unable to sign out. Please try again.';

  @override
  String get roleQuestion => 'What do you need today?';

  @override
  String get roleInstruction =>
      'Choose a mode for this situation. You can switch modes later without deleting your data.';

  @override
  String get needHelpEyebrow => 'NEED HELP';

  @override
  String get needHelpTitle => 'I need help';

  @override
  String get needHelpDescription =>
      'Send an SOS, track nearby delivery, and return to an active incident.';

  @override
  String get rescueEyebrow => 'RESCUE';

  @override
  String get rescueTitle => 'I want to help';

  @override
  String get rescueDescription =>
      'Listen for nearby incidents, review details, and track incidents you are helping.';

  @override
  String get chooseMode => 'Choose this mode';

  @override
  String get roleTrustNotice =>
      'A mode only changes the app layout. It does not verify identity, responder authority, or access to another person\'s incident.';

  @override
  String get emergencyChat => 'Emergency chat';

  @override
  String chatIncidentSemantics(String incidentId) {
    return 'Chat for incident $incidentId';
  }

  @override
  String get savedLocallyFirst => 'Saved on this device first';

  @override
  String get chatNeedsRecipient =>
      'Queued messages need a BLE recipient. Choose the intended peer; the app will not guess one.';

  @override
  String get assigning => 'Assigning…';

  @override
  String get chooseRecipient => 'Choose recipient';

  @override
  String get tryAgain => 'Try again';

  @override
  String get chooseIncidentBeforeChat =>
      'Choose an incident before starting chat';

  @override
  String get noChatMessages =>
      'No messages yet\nSend a short update that the other person needs to know.';

  @override
  String get emergencyMessage => 'Emergency message';

  @override
  String get typeMessage => 'Type a message…';

  @override
  String get send => 'Send';

  @override
  String get statusQueued => 'Queued';

  @override
  String get statusSending => 'Sending';

  @override
  String get statusAwaitingConfirmation => 'Relayed — delivery not confirmed';

  @override
  String get statusConfirmedStored =>
      'Confirmed stored on the selected nearby device';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusFailedRetryable => 'Failed; retryable';

  @override
  String get statusFailedNoRetry => 'Delivery failed; retry not scheduled';

  @override
  String get statusFailedRetryScheduled => 'Failed; retry scheduled';

  @override
  String get statusExpired => 'Expired';

  @override
  String get deliveryStatusUnavailable =>
      'Delivery status is temporarily unavailable. The SOS remains saved locally.';

  @override
  String get savedNearbyUnavailable =>
      'Saved locally. Nearby delivery is unavailable in this session.';

  @override
  String get directStoredConfirmed =>
      'Confirmed stored on the selected nearby device.';

  @override
  String get sentAwaitingConfirmation =>
      'Sent to a nearby device; awaiting application confirmation.';

  @override
  String storedOnRelay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relay devices',
      one: '1 relay device',
    );
    return 'Stored on $_temp0; final delivery is unconfirmed.';
  }

  @override
  String get forwardingAuthenticatedRelay =>
      'Forwarding to an authenticated nearby relay.';

  @override
  String get nearbyFailedNoRetry =>
      'Nearby delivery failed; no retry is currently scheduled.';

  @override
  String get nearbyFailedRetry => 'Nearby delivery failed; retry is scheduled.';

  @override
  String get nearbyExpired => 'Nearby delivery expired without confirmation.';

  @override
  String get preparingNearbyRoute => 'Preparing the trusted nearby route.';

  @override
  String get noRelayAccepted =>
      'No relay accepted yet. The saved SOS will retry while eligible.';

  @override
  String get searchingEligibleDevice =>
      'Searching for an eligible nearby device. Final delivery is unconfirmed.';

  @override
  String get foregroundLocationSharing => 'Foreground location sharing';

  @override
  String locationDeliverySemantics(String status) {
    return 'Location delivery: $status';
  }

  @override
  String get locationOff => 'Off';

  @override
  String get readyToSend => 'Ready to send';

  @override
  String get gettingLocation => 'Getting location…';

  @override
  String get statusFailed => 'Failed';

  @override
  String recipientLabel(String recipient) {
    return 'Recipient: $recipient';
  }

  @override
  String get recipientNotSelected => 'not selected';

  @override
  String get locationOffDescription =>
      'Off. Choose a recipient before sharing.';

  @override
  String lastUpdate(String time) {
    return 'Last update: $time';
  }

  @override
  String previousDelivery(String status) {
    return 'Previous delivery: $status';
  }

  @override
  String get starting => 'Starting…';

  @override
  String get startSharing => 'Start sharing';

  @override
  String get sendLocation => 'Send location';

  @override
  String get stopSharing => 'Stop sharing';

  @override
  String get selectRecipientToShare =>
      'Select a connected recipient to start sharing.';

  @override
  String get currentLocationUnavailable =>
      'Current location is unavailable or invalid.';

  @override
  String get locationUnavailableSaved =>
      'Location unavailable — SOS was saved without coordinates';

  @override
  String get locationServicesDisabled => 'Location Services are disabled.';

  @override
  String get locationPermissionDenied => 'Location permission was denied.';

  @override
  String get locationPermissionDeniedForever =>
      'Location permission is permanently denied. Open Settings.';

  @override
  String get locationTimedOut => 'Location request timed out.';

  @override
  String get locationShareFailed =>
      'Unable to share the current location. Try again.';

  @override
  String get chooseBleRecipient => 'Choose BLE recipient';

  @override
  String get bleRecipientTrustNotice =>
      'Select the intended nearby device. The identifier is a transport identifier and is not verified as a person identity.';

  @override
  String get bleNotReady => 'BLE is not ready';

  @override
  String get scanningNearby => 'Scanning for nearby devices…';

  @override
  String get unnamedDevice => 'Unnamed device';

  @override
  String deviceStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get useDevice => 'Use';

  @override
  String get connect => 'Connect';

  @override
  String get continueWithoutRecipient => 'Continue without recipient';

  @override
  String get cancel => 'Cancel';

  @override
  String get details => 'Details';

  @override
  String get sosHold => 'Hold to send SOS';

  @override
  String get sendSos => 'Send SOS';

  @override
  String get creatingSos => 'Creating SOS…';

  @override
  String get keepHolding => 'Keep holding';

  @override
  String get checkingLocation => 'Checking location';

  @override
  String get holdToStart => 'Hold to start';

  @override
  String get openActiveChat => 'Open active SOS chat';

  @override
  String get activeSos => 'SOS in progress';

  @override
  String tapToOpenIncidentChat(String incidentId) {
    return 'Tap to open chat · Incident $incidentId';
  }

  @override
  String get historyTitle => 'SOS History';

  @override
  String get closeSearch => 'Close search';

  @override
  String get searchHistory => 'Search history';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get newestFirst => 'Newest first · tap for oldest first';

  @override
  String get oldestFirst => 'Oldest first · tap for newest first';

  @override
  String get deviceData => 'Data on this device';

  @override
  String get accountHistoryPendingSync =>
      'Current account history (including pending sync)';

  @override
  String get historySearch => 'Search SOS or message';

  @override
  String get filterAll => 'All';

  @override
  String get filterActive => 'Active';

  @override
  String get filterCompleted => 'Completed';

  @override
  String get filterCancelled => 'Cancelled';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get waitingForRecipient => 'Waiting for recipient';

  @override
  String get waitingReceiverConfirmation => 'Awaiting receiver confirmation';

  @override
  String get nearbyRescueCenter => 'Nearby rescue center';

  @override
  String get receivedOnDevice => 'Incidents received over BLE on this device';

  @override
  String get switchToNeedHelp => 'Switch to Need Help mode';

  @override
  String get readyForNearbyIncidents => 'Ready for nearby incidents';

  @override
  String get listenWhenReady => 'Start listening when you are ready';

  @override
  String get rescueListeningDescription =>
      'Bluetooth is accepting connections. Keep the app in the foreground for the most reliable operation.';

  @override
  String get rescueOffDescription =>
      'Bluetooth permission is requested only after you start listening. A connection is not treated as human acceptance.';

  @override
  String get incidentMap => 'Incident Map';

  @override
  String get mapTilesRequireInternet =>
      'Map tiles require internet. Coordinates remain available offline.';

  @override
  String get finalDeliveryUnconfirmed => 'Final delivery unconfirmed';

  @override
  String get activeIncidentExists => 'An incident is still active';

  @override
  String get roleSwitchPreservesData =>
      'Switching modes does not cancel the incident, delete data, or stop the BLE queue. You can return to it at any time.';

  @override
  String get stayInMode => 'Stay in this mode';

  @override
  String get switchMode => 'Switch mode';

  @override
  String get rescuePreparingBluetooth => 'Preparing Bluetooth…';

  @override
  String get rescueListening => 'Listening for incidents';

  @override
  String get startRescueListening => 'Start listening';

  @override
  String get receivedIncidents => 'Received incidents';

  @override
  String incidentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count incidents',
      one: '1 incident',
    );
    return '$_temp0';
  }

  @override
  String get helpingIncidents => 'Incidents being helped';

  @override
  String get switchModeTooltip => 'Switch mode';

  @override
  String get storedOnThisDevice => 'Stored on this device';

  @override
  String get helpingStateNotice =>
      'This state helps you reopen an incident quickly. It is not an exclusive assignment and does not send a human acceptance to the person requesting help.';

  @override
  String get noTrackedIncidents => 'No tracked incidents';

  @override
  String get trackIncidentHint =>
      'Choose “Track on this device” from a received incident to pin it here.';

  @override
  String get viewReceivedIncidents => 'View received incidents';

  @override
  String get noReceivedIncidents => 'No incidents received';

  @override
  String get receivedIncidentHint =>
      'Start listening and have the sender choose this device. The incident appears after it is stored successfully.';

  @override
  String get openTrackedIncident => 'Open tracked incident';

  @override
  String rescueStartFailed(String error) {
    return 'Unable to start listening: $error';
  }

  @override
  String get switchToRescue => 'Switch to Rescue mode';

  @override
  String get locationServices => 'Location Services';

  @override
  String get permission => 'Permission';

  @override
  String get openLocationSettings => 'Open Location Settings';

  @override
  String get openAppSettings => 'Open App Settings';

  @override
  String get close => 'Close';

  @override
  String get incidentChats => 'Incident chats';

  @override
  String get noChatIncidents => 'No incidents available for chat';

  @override
  String openIncidentChatSemantics(String type, String incidentId) {
    return 'Open chat for $type incident $incidentId';
  }

  @override
  String get enableLocationServices =>
      'Please enable Location Services and try again.';

  @override
  String get locationPermissionRequired =>
      'Location permission is required to send SOS.';

  @override
  String get unableGetLocation => 'Unable to get your current location.';

  @override
  String get sosSavedRelaySearching =>
      'SOS saved. Searching for opted-in relay devices; final delivery is unconfirmed.';

  @override
  String get sosSavedWithLocation =>
      'SOS saved with location. Waiting for a trusted nearby route.';

  @override
  String get sosSavedLocally =>
      'SOS saved locally. Waiting for a trusted nearby route.';

  @override
  String sosSendFailed(String error) {
    return 'Failed to send SOS: $error';
  }

  @override
  String get deviceHistory => 'Data on this device';

  @override
  String get guestHistoryNotice =>
      'Guest SOS stays on this device, is not linked to an account, and is not uploaded to the cloud.';

  @override
  String get noGuestHistory => 'No Guest data on this device';

  @override
  String get sosDetails => 'SOS Details';

  @override
  String get manageSos => 'Manage SOS';

  @override
  String get editMessage => 'Edit message';

  @override
  String get deleteSos => 'Delete SOS';

  @override
  String get closeSosDetails => 'Close SOS details';

  @override
  String get type => 'Type';

  @override
  String get humanResponse => 'Human response';

  @override
  String get noHumanConfirmation =>
      'The current protocol has no verified human acceptance. BLE status only confirms storage on the receiving device.';

  @override
  String get responderStatus => 'Helper status';

  @override
  String get sharedLocation => 'Shared location';

  @override
  String get noVerifiedSharedLocation =>
      'No verified shared location is available for this incident.';

  @override
  String get viewSharedLocation => 'View shared location';

  @override
  String get created => 'Created';

  @override
  String get updated => 'Updated';

  @override
  String get sync => 'Sync';

  @override
  String get deviceOnly => 'On this device only';

  @override
  String get synced => 'Synced';

  @override
  String get pendingSync => 'Pending sync';

  @override
  String get message => 'Message';

  @override
  String get openIncidentChat => 'Open incident chat';

  @override
  String get viewOnMap => 'View on map';

  @override
  String get markResolved => 'Mark as Resolved';

  @override
  String get cancelSos => 'Cancel SOS';

  @override
  String get bleDelivery => 'BLE delivery';

  @override
  String get recipient => 'Recipient';

  @override
  String unableSetRecipient(String error) {
    return 'Unable to set recipient: $error';
  }

  @override
  String get publicSosRelay => 'Public SOS relay';

  @override
  String get relayExpiredUnconfirmed =>
      'Relay expired before final delivery could be confirmed';

  @override
  String get relayForwardingUnconfirmed =>
      'Forwarding through nearby devices; final delivery unconfirmed';

  @override
  String get relayRetryUnconfirmed =>
      'Waiting to retry relay forwarding; final delivery unconfirmed';

  @override
  String get relayWaitingUnconfirmed =>
      'Waiting to forward; final delivery unconfirmed';

  @override
  String get deleteSosQuestion => 'Delete SOS?';

  @override
  String get deleteCannotUndo => 'This action cannot be undone.';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get editSos => 'Edit SOS';

  @override
  String get describeEmergency => 'Describe the emergency';

  @override
  String get downloadVisibleArea => 'Download visible area';

  @override
  String get offlineDownloadRequiresProvider =>
      'Offline downloads require the production Geoapify provider';

  @override
  String get manageOfflineMaps => 'Manage offline maps';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get centerCurrentLocation => 'Center map on current location';

  @override
  String get refreshCurrentLocation => 'Refresh current location';

  @override
  String get sharedLocationAvailable =>
      'Shared location available from the matched peer.';

  @override
  String get sharedLocationExpired =>
      'Shared location is expired and is not shown as current.';

  @override
  String get sharedLocationUnavailable => 'Shared location is unavailable.';

  @override
  String get currentLocationIncidentAvailable =>
      'Current location unavailable. Incident location remains available.';

  @override
  String get currentLocationStale =>
      'Current location is stale. Refresh before relying on it.';

  @override
  String get currentLocationAvailable => 'Current location available.';

  @override
  String incidentCoordinates(String latitude, String longitude) {
    return 'Incident: $latitude, $longitude';
  }

  @override
  String get incidentCoordinatesUnavailable =>
      'Incident coordinates are not available.';

  @override
  String get downloadedTilesAvailable =>
      'Downloaded map tiles are available offline. Missing tiles still require internet.';

  @override
  String get preparingMapStorage => 'Preparing map storage…';

  @override
  String downloadingTiles(int completed, int total) {
    return 'Downloading $completed/$total tiles';
  }

  @override
  String get retryMapTiles => 'Retry map tiles';

  @override
  String get mapProviderUnavailable =>
      'Map provider is unavailable for this build.';

  @override
  String get developmentTileProvider =>
      'Development tile provider; configure MAP_TILE_URL for production.';

  @override
  String get noIncidentLocation =>
      'No location is available for this incident.';

  @override
  String get mapName => 'Map name';

  @override
  String minimumZoom(int zoom) {
    return 'Minimum zoom: $zoom';
  }

  @override
  String maximumZoom(int zoom) {
    return 'Maximum zoom: $zoom';
  }

  @override
  String get download => 'Download';

  @override
  String get offlineMaps => 'Offline maps';

  @override
  String get noDownloadedRegions => 'No downloaded map regions.';

  @override
  String get offlineDownloadCancelled => 'Offline map download cancelled.';

  @override
  String get chatSavedPending => 'Saved locally; BLE delivery is pending.';

  @override
  String get chatSendFailed => 'Message could not be sent. Try again.';

  @override
  String get noQueuedMessagesNeedRecipient =>
      'No queued messages needed a recipient.';

  @override
  String recipientAssigned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Recipient assigned to $count queued messages.',
      one: 'Recipient assigned to 1 queued message.',
    );
    return '$_temp0';
  }

  @override
  String assignRecipientFailed(String error) {
    return 'Unable to assign recipient: $error';
  }

  @override
  String get developerToolUnavailable => 'Developer tool unavailable';

  @override
  String get relayDiagnosticsUnavailable => 'Relay diagnostics unavailable';

  @override
  String get relayDiagnosticsReadFailed =>
      'The local relay state could not be read. No data changed.';

  @override
  String get noRelayRecords => 'No relay records';

  @override
  String get noRelayRecordsDescription =>
      'This device has no retained Relay v2 messages. Relay-only records never appear in SOS History.';

  @override
  String get relayEvidenceNotice =>
      'Developer evidence only. A hop receipt proves storage by the next relay; it does not prove that a responder received the SOS.';

  @override
  String relayMessagesStored(int count) {
    return 'Relay messages stored: $count';
  }

  @override
  String get locallyOriginatedSos => 'Locally originated SOS';

  @override
  String get relayOnlyEnvelope => 'Relay-only envelope';

  @override
  String get messageId => 'Message ID';

  @override
  String get payloadDigest => 'Payload digest';

  @override
  String get incomingHopCount => 'Incoming hop count';

  @override
  String get latestPersisted => 'Latest persisted';

  @override
  String get latestRelayJobStatus => 'Latest relay job status';

  @override
  String get relayAttemptCount => 'Relay attempt count';

  @override
  String get hopReceipt => 'Hop receipt';

  @override
  String get hopReceiptsStored => 'Hop receipts stored';

  @override
  String get finalResponderReceipt => 'Final responder receipt';

  @override
  String get confirmed => 'Confirmed';

  @override
  String get notConfirmed => 'Not confirmed';

  @override
  String get finalReceiptsStored => 'Final receipts stored';

  @override
  String get lastRelayErrorCategory => 'Last relay error category';

  @override
  String get none => 'None';

  @override
  String get storedOnRelayStatus => 'Stored on relay';

  @override
  String get storedByNextRelay => 'Stored by next relay';

  @override
  String get awaitingHopReceipt => 'Awaiting hop receipt';

  @override
  String get finalReceiptRecorded => 'Final receipt recorded';

  @override
  String get receivedFromNextRelay => 'Received from next relay';

  @override
  String get pending => 'Pending';

  @override
  String get failedOrExpired => 'Failed or expired';

  @override
  String get notRecordedLocally => 'Not recorded locally';

  @override
  String get resolveSosQuestion => 'Resolve SOS?';

  @override
  String get cancelSosQuestion => 'Cancel SOS?';

  @override
  String get resolveSosConfirmation =>
      'Are you sure you want to mark this SOS as resolved?';

  @override
  String get cancelSosConfirmation =>
      'Are you sure you want to cancel this SOS?';

  @override
  String get back => 'Back';

  @override
  String get resolve => 'Resolve';

  @override
  String get sosMarkedResolved => 'SOS marked as resolved.';

  @override
  String get sosCancelled => 'SOS cancelled.';

  @override
  String failedUpdateSos(String error) {
    return 'Failed to update SOS: $error';
  }

  @override
  String get sosUpdated => 'SOS updated.';

  @override
  String get sosDeleted => 'SOS deleted.';

  @override
  String failedDeleteSos(String error) {
    return 'Failed to delete SOS: $error';
  }

  @override
  String get syncCompleted => 'Sync completed.';

  @override
  String syncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get localDataOnly => 'Local data only';

  @override
  String get tapToOpenChat => 'Tap to open chat';

  @override
  String get tapToViewDetails => 'Tap to view details';

  @override
  String get unableOpenAttribution => 'Unable to open attribution link.';

  @override
  String offlineRegionAvailable(String name) {
    return '$name is available offline.';
  }

  @override
  String deleteNamedItem(String name) {
    return 'Delete $name';
  }

  @override
  String offlineRegionSummary(
    int count,
    String size,
    int minZoom,
    int maxZoom,
  ) {
    return '$count tiles · $size · zoom $minZoom–$maxZoom';
  }

  @override
  String get bleTestDebug => 'BLE Test (Debug)';

  @override
  String get debugToolOnly => 'Debug tool only';

  @override
  String get debugToolSafety =>
      'This screen does not create or send production SOS alerts.';

  @override
  String get bluetoothStatus => 'Bluetooth status';

  @override
  String get permissions => 'Permissions';

  @override
  String get blePlatformCapabilities =>
      'Android and iOS support scan, advertise, connect, write and receive BLE data. Foreground testing is required. Range diagnostics use an application ACK; ordinary test messages report native write acceptance only.';

  @override
  String get startScan => 'Start Scan';

  @override
  String get stopScan => 'Stop Scan';

  @override
  String get startAdvertising => 'Start Advertising';

  @override
  String get stopAdvertising => 'Stop Advertising';

  @override
  String get discoveredDevices => 'Discovered devices';

  @override
  String get noDevicesDiscovered =>
      'No devices discovered yet. Start a scan on both devices.';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get testMessage => 'Test message';

  @override
  String get bleRangeDiagnostic => 'BLE range / quality diagnostic';

  @override
  String get rangeDiagnosticSafety =>
      'Record the real distance yourself. RSSI is signal strength and is never converted to distance. Repeat each distance in open and obstructed conditions.';

  @override
  String get startRangeRun => 'Start range run';

  @override
  String get stop => 'Stop';

  @override
  String receivedMessages(int count) {
    return 'Received messages ($count)';
  }

  @override
  String get noCompleteMessages => 'No complete messages received yet.';

  @override
  String get diagnosticLog => 'Diagnostic log';

  @override
  String get clear => 'Clear';

  @override
  String get noDiagnostics => 'No diagnostics yet.';

  @override
  String get mapConfigProductionProviderMissing =>
      'A production map provider is not configured for this build.';

  @override
  String get mapConfigUrlMissing => 'The map service address is missing.';

  @override
  String get mapConfigUrlInvalid => 'The map service address must use HTTPS.';

  @override
  String get mapConfigPublicOsmBlocked =>
      'The public OpenStreetMap tile service is not available in release builds.';

  @override
  String get mapConfigGeoapifyKeyMissing => 'The map service key is missing.';

  @override
  String get mapConfigTemplateInvalid =>
      'The map service configuration is incomplete.';

  @override
  String get mapConfigAttributionMissing =>
      'Required map attribution is missing.';

  @override
  String get mapConfigGeoapifyAttributionIncomplete =>
      'Geoapify and OpenStreetMap attribution are required.';

  @override
  String get mapConfigUserAgentMissing =>
      'The map service identity is missing.';

  @override
  String get offlineMapStorageUnavailable =>
      'Offline map storage is unavailable on this device.';

  @override
  String get offlineMapDownloadFailed =>
      'The offline map could not be downloaded. Check your connection, storage, and map provider.';

  @override
  String get incidentCoordinatesInvalid =>
      'Incident coordinates are unavailable or invalid.';

  @override
  String sharedCoordinates(String latitude, String longitude, String time) {
    return 'Shared: $latitude, $longitude · $time';
  }

  @override
  String get mapLegend =>
      'Red: incident · Purple: shared · Blue: current device';

  @override
  String offlineMapDefaultName(String date) {
    return 'Incident area $date';
  }

  @override
  String offlineTileEstimate(int count, String megabytes) {
    return '$count tiles · about $megabytes MB';
  }

  @override
  String offlineMapTooLarge(int maxTiles) {
    return 'Reduce the visible area or zoom range. The safety limit is $maxTiles tiles.';
  }

  @override
  String get offlineMapDownloadInfo =>
      'Keep this app open during download. Only the visible bounded area is stored.';

  @override
  String offlineMapStorageSummary(String size) {
    return 'Stored: $size';
  }

  @override
  String get checkCurrentLocation => 'Check current location';

  @override
  String get checkCurrentLocationHint =>
      'Tap to try again without creating an SOS or sharing coordinates.';

  @override
  String get checkingCurrentLocation => 'Finding your location...';

  @override
  String get currentLocationCheckReady =>
      'Current location found. This check did not share coordinates.';

  @override
  String get recentLocationCheckReady =>
      'A recent saved location is available. This check did not share coordinates.';

  @override
  String get stopFollowing => 'Stop following on this device';

  @override
  String get stopFollowingQuestion => 'Stop following this incident?';

  @override
  String get stopFollowingExplanation =>
      'Moves this incident out of Helping on this device. History and messages stay available. This does not cancel or resolve the SOS for anyone else.';

  @override
  String get stoppedFollowing => 'Stopped following on this device';

  @override
  String get stopFollowingFailed => 'Could not stop following. Try again.';

  @override
  String get receivedHistory => 'Received incident history';

  @override
  String get receivedHistoryEmpty => 'No received incidents saved yet.';

  @override
  String get receivedHistoryError =>
      'Could not load received incident history.';

  @override
  String get receivedHistoryNotice =>
      'Incidents and messages saved on this device. Stopping following does not change the origin\'s SOS status.';

  @override
  String get rescueHistoryHelping => 'Following on this device';

  @override
  String get rescueHistoryCancelled => 'Cancelled by the origin';

  @override
  String get rescueHistoryResolved => 'Resolved by the origin';

  @override
  String get rescueHistoryExpired => 'Offer expired';
}
