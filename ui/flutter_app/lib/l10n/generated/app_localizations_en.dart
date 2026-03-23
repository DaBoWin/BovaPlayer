// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BovaPlayer';

  @override
  String get discoverTrendingNow => 'Trending Now';

  @override
  String get discoverTrendingNowSub =>
      'The titles getting the most attention today';

  @override
  String get discoverPopularMovies => 'Popular Movies';

  @override
  String get discoverPopularMoviesSub => 'Big-screen picks with broad appeal';

  @override
  String get discoverPopularTV => 'Popular TV';

  @override
  String get discoverPopularTVSub => 'Series people keep coming back to';

  @override
  String get discoverTrendingMovies => 'Trending Movies';

  @override
  String get discoverTrendingMoviesSub => 'Today\'s biggest movie momentum';

  @override
  String get discoverNowPlaying => 'Now Playing';

  @override
  String get discoverNowPlayingSub => 'Movies currently rolling out worldwide';

  @override
  String get discoverMovies => 'Discover Movies';

  @override
  String get discoverMoviesSub =>
      'High-popularity films surfaced from TMDB Discover';

  @override
  String get discoverTrendingShows => 'Trending Shows';

  @override
  String get discoverTrendingShowsSub => 'Series that are surging right now';

  @override
  String get discoverPopularTVShows => 'Popular TV';

  @override
  String get discoverPopularTVShowsSub => 'Broad-appeal TV picks from TMDB';

  @override
  String get discoverTV => 'Discover TV';

  @override
  String get discoverTVSub => 'Fresh series surfaced by popularity';

  @override
  String get playerLoading => 'Loading...';

  @override
  String playerFilePickError(String error) {
    return 'File pick failed: $error';
  }

  @override
  String playerPlayFailed(String error) {
    return 'Playback failed: $error';
  }

  @override
  String get playerRetry => 'Retry';

  @override
  String get playerNoVideo => 'No video selected';

  @override
  String get playerNoVideoHint =>
      'Click the folder icon at top right to select a video';

  @override
  String get playerSelectFile => 'Select Video File';

  @override
  String get navHome => 'Home';

  @override
  String get navMovies => 'Movies';

  @override
  String get navShows => 'Shows';

  @override
  String get navPlayer => 'Player';

  @override
  String get navMediaLibrary => 'Media Library';

  @override
  String get navAccount => 'Account';

  @override
  String get mobileNavDiscover => 'Discover';

  @override
  String get mobileNavPlayer => 'Player';

  @override
  String get mobileNavLibrary => 'Library';

  @override
  String get sidebarCollapse => 'Collapse';

  @override
  String get sidebarExpand => 'Expand';

  @override
  String get sidebarSignOut => 'Sign out';

  @override
  String profileGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get profileGuest => 'Guest';

  @override
  String get profileDiscovering => 'Discovering';

  @override
  String get profileWatching => 'Watching';

  @override
  String get profileBrowsing => 'Browsing';

  @override
  String get profileManagingAccount => 'Managing account';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionBookmarks => 'Bookmarks';

  @override
  String get actionNotifications => 'Notifications';

  @override
  String get actionRefreshSync => 'Refresh & Sync';

  @override
  String get actionSearchMedia => 'Search media';

  @override
  String get actionBack => 'Back';

  @override
  String get exitAppTitle => 'Exit App';

  @override
  String get exitAppMessage => 'Are you sure you want to exit BovaPlayer?';

  @override
  String get cancel => 'Cancel';

  @override
  String get exit => 'Exit';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get bookmarkSave => 'Save';

  @override
  String get bookmarkSaved => 'Saved';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get retry => 'Retry';

  @override
  String comingSoon(String label) {
    return '$label is coming next.';
  }

  @override
  String get addEmbyServer => 'Emby Server';

  @override
  String get addSmbShare => 'SMB Share';

  @override
  String get addFtpServer => 'FTP Server';

  @override
  String get selectLibrary => 'Select library to enter';

  @override
  String discoverNotFoundInLibrary(String title) {
    return 'Could not find \"$title\" in connected Emby libraries';
  }

  @override
  String bookmarkAdded(String title) {
    return 'Bookmarked: $title';
  }

  @override
  String bookmarkRemoved(String title) {
    return 'Removed bookmark: $title';
  }

  @override
  String get bookmarkSaveFailed => 'Failed to save bookmark, please try again';

  @override
  String get quickPlayFailed => 'Quick play failed, please try again';

  @override
  String get followSeriesStart => 'Follow';

  @override
  String get followSeriesActive => 'Following';

  @override
  String get followSeriesCancel => 'Unfollow';

  @override
  String get followSeriesUpdated => 'New episode';

  @override
  String followSeriesStarted(String title) {
    return 'Started following: $title';
  }

  @override
  String followSeriesCanceled(String title) {
    return 'Stopped following: $title';
  }

  @override
  String get followSeriesUnavailable =>
      'No Emby series available for following';

  @override
  String get discoverBookmarksSortedByUpdates =>
      'Followed shows with new episodes are shown first.';

  @override
  String get discoverOpen => 'Open';

  @override
  String get discoverFeatured => 'Featured';

  @override
  String get discoverHotWall => 'Hot Wall';

  @override
  String get discoverHotWallSubtitle =>
      'A live grid of high-interest titles pulled from TMDB.';

  @override
  String discoverTmdbCredentials(String title) {
    return '$title needs TMDB credentials';
  }

  @override
  String get discoverTmdbCredentialsHint =>
      'Add `TMDB_READ_ACCESS_TOKEN` or `TMDB_API_KEY` to `ui/flutter_app/.env` to load live posters, trending picks and featured backdrops.';

  @override
  String discoverSearchResultsFor(String query) {
    return 'Results for \"$query\"';
  }

  @override
  String get discoverExplore => 'Explore';

  @override
  String get discoverUnableToLoad => 'Unable to load discover feed';

  @override
  String get discoverTryAgain => 'Try again';

  @override
  String get discoverSearchHint => 'Search movies and shows from TMDB';

  @override
  String get discoverSearchGuide =>
      'Type a title to search TMDB and jump straight into your libraries.';

  @override
  String get discoverTmdbNotConfigured => 'TMDB not configured';

  @override
  String get discoverTmdbNotConfiguredHint =>
      'Add your TMDB token first to use search.';

  @override
  String get discoverStartSearching => 'Start searching';

  @override
  String get discoverSearchExploreHint =>
      'Find a movie or show, then Explore or quick-play it from your matched libraries.';

  @override
  String get discoverNoResults => 'No results';

  @override
  String get discoverNoResultsHint =>
      'Try another title, original name, or shorter keyword.';

  @override
  String get discoverNoBookmarks => 'No bookmarks yet';

  @override
  String get discoverNoBookmarksHint =>
      'Save titles from the featured hero or search results and they will show up here.';

  @override
  String discoverBookmarkCount(int count) {
    return '$count saved titles ready for Explore or quick play.';
  }

  @override
  String discoverExpandSources(int count) {
    return 'Expand $count more sources';
  }

  @override
  String get discoverLatencyGood => 'Good';

  @override
  String get discoverLatencyMedium => 'Medium';

  @override
  String get discoverLatencySlow => 'Slow';

  @override
  String get discoverLatencyUnreachable => 'Unreachable';

  @override
  String get embyServers => 'Emby Servers';

  @override
  String get embyServersDesc =>
      'Manage your Emby connections in the media library workspace.';

  @override
  String get embyNoServers => 'No servers added yet';

  @override
  String get embyNoServersHint =>
      'Tap the button in the top-right to add an Emby server. Your media library will be displayed here after connection.';

  @override
  String get embyNoServersHintMobile =>
      'Tap the button above to add an Emby server';

  @override
  String get embyEditServer => 'Edit Server';

  @override
  String get embyAddServer => 'Add Server';

  @override
  String get embyServerName => 'Name';

  @override
  String get embyServerNameHint => 'My Emby';

  @override
  String get embyServerAddress => 'Server Address';

  @override
  String get embyUsername => 'Username';

  @override
  String get embyPassword => 'Password';

  @override
  String get embyLoginFailed => 'Login failed: wrong username or password';

  @override
  String embyConnectionFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String embyUser(String name) {
    return 'User: $name';
  }

  @override
  String get embyBackToLibrary => 'Back to media library';

  @override
  String get embyRefresh => 'Refresh';

  @override
  String get embyContinueWatching => 'Continue Watching';

  @override
  String get embyShowAll => 'Show all';

  @override
  String get embyLatestAdded => 'Latest added';

  @override
  String get embyNameSort => 'Name';

  @override
  String get embyYearSort => 'Year';

  @override
  String get embyRatingSort => 'Rating';

  @override
  String embyItemCount(int count) {
    return '$count items';
  }

  @override
  String get embyNoContent => 'No content';

  @override
  String get embyNoContentHint =>
      'No media items to display in this directory.';

  @override
  String get embySeason => 'Season';

  @override
  String embyEpisodeCount(int count) {
    return '$count episodes';
  }

  @override
  String embyDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h${minutes}m';
  }

  @override
  String embyDurationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String get embyPlay => 'Play';

  @override
  String get embyFavorite => 'Favorite';

  @override
  String get embyDetails => 'Details';

  @override
  String get embyPlaybackOptions => 'Playback Options';

  @override
  String get embyVideoFormat => 'Video Format';

  @override
  String get embyAudioFormat => 'Audio Format';

  @override
  String get embyStreamInfo => 'Audio/Video/Subtitle Info';

  @override
  String get embyVideo => 'Video';

  @override
  String get embyAudio => 'Audio';

  @override
  String get embySubtitle => 'Subtitles';

  @override
  String get embyFillAllFields => 'Please fill all required fields';

  @override
  String get embySwitchServer => 'Switch server';

  @override
  String get embyAddServerTooltip => 'Add server';

  @override
  String get embyExitApp => 'Exit App';

  @override
  String get embyExitAppConfirm => 'Are you sure you want to exit the app?';

  @override
  String get embyPageLoadFailed => 'Page load failed';

  @override
  String get embySortTooltip => 'Sort';

  @override
  String get embyListView => 'List view';

  @override
  String get embyGridView => 'Grid view';

  @override
  String get embyHome => 'Home';

  @override
  String get embyBrowseSubtitle =>
      'Browse your media catalog by Emby directory.';

  @override
  String get embyContinueBrowse => 'Continue browsing your media catalog.';

  @override
  String get embyBack => 'Back';

  @override
  String embyEpisodeLabel(int number) {
    return 'Episode $number';
  }

  @override
  String get embyStreamTitle => 'Title';

  @override
  String get embyStreamLanguage => 'Language';

  @override
  String get embyStreamCodec => 'Codec';

  @override
  String get embyStreamProfile => 'Profile';

  @override
  String get embyStreamLevel => 'Level';

  @override
  String get embyStreamResolution => 'Resolution';

  @override
  String get embyStreamAspectRatio => 'Aspect Ratio';

  @override
  String get embyStreamInterlaced => 'Interlaced';

  @override
  String get embyStreamFrameRate => 'Frame Rate';

  @override
  String get embyStreamBitrate => 'Bitrate';

  @override
  String get embyStreamVideoRange => 'Video Range';

  @override
  String get embyStreamColorPrimaries => 'Color Primaries';

  @override
  String get embyStreamColorSpace => 'Color Space';

  @override
  String get embyStreamColorTransfer => 'Color Transfer';

  @override
  String get embyStreamBitDepth => 'Bit Depth';

  @override
  String get embyStreamPixelFormat => 'Pixel Format';

  @override
  String get embyStreamRefFrames => 'Reference Frames';

  @override
  String get embyStreamChannelLayout => 'Channel Layout';

  @override
  String get embyStreamChannels => 'Channels';

  @override
  String get embyStreamSampleRate => 'Sample Rate';

  @override
  String get embyStreamDefault => 'Default';

  @override
  String get embyStreamEmbeddedTitle => 'Embedded Title';

  @override
  String get embyStreamForced => 'Forced';

  @override
  String get embyYes => 'Yes';

  @override
  String get embyNo => 'No';

  @override
  String get embyType => 'Type';

  @override
  String get embyYear => 'Year';

  @override
  String get embyRating => 'Rating';

  @override
  String get embyRuntime => 'Runtime';

  @override
  String get embyScore => 'Score';

  @override
  String get embyOriginalTitle => 'Original Title';

  @override
  String get embyUnknown => 'Unknown';

  @override
  String get embyMediaContent => 'Media Content';

  @override
  String get embyPlaybackUrlFailed => 'Unable to get playback URL';

  @override
  String get mediaSourceList => 'Media Source List';

  @override
  String mediaSourceCount(int count) {
    return '$count items';
  }

  @override
  String get mediaSourceLoading => 'Loading media sources...';

  @override
  String get mediaSourceEmpty => 'No media sources yet';

  @override
  String get mediaSourceEmptyHint =>
      'Add Emby, SMB or FTP from the top-right, and your media sources will be listed here.';

  @override
  String get mediaSourceAdd => 'Add Media Source';

  @override
  String get mediaSourceEdit => 'Edit Media Source';

  @override
  String get mediaSourceDelete => 'Delete Media Source';

  @override
  String mediaSourceDeleteConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get mediaSourceSelectProtocol =>
      'Select a protocol to configure a new content source.';

  @override
  String get mediaSourceEmbyDesc => 'Connect to media service and metadata';

  @override
  String get mediaSourceSmbDesc => 'Add LAN shared directory';

  @override
  String get mediaSourceFtpDesc => 'Access remote file server';

  @override
  String get mediaSourceHostAddress => 'Host Address';

  @override
  String get mediaSourcePort => 'Port';

  @override
  String get mediaSourceShareName => 'Share Name';

  @override
  String get mediaSourceShareNameHint => 'e.g. share, movies';

  @override
  String get mediaSourceWorkgroup => 'Workgroup';

  @override
  String get mediaSourceSavePassword => 'Save password';

  @override
  String get mediaSourceNameHint => 'e.g. Home Server';

  @override
  String get mediaSourceFillRequired => 'Please fill all required fields';

  @override
  String get mediaSourceEnterShareName => 'Please enter share name';

  @override
  String get mediaSourceConnectionFailed => 'Connection failed';

  @override
  String get mediaSourceLoginFailed =>
      'Login failed, check server address and credentials';

  @override
  String get mediaSourceAddSuccess => 'Added successfully';

  @override
  String get mediaSourceUpdateSuccess => 'Updated successfully';

  @override
  String get mediaSourceDeleteSuccess => 'Deleted successfully';

  @override
  String mediaSourceDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String mediaSourceLoadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String get mediaSourceSyncComplete => 'Sync complete';

  @override
  String get mediaSourcePleaseLogin => 'Please login first';

  @override
  String get mediaSourceEnableSync =>
      'Please enable cloud sync in account page';

  @override
  String get mediaSourceNoActive => 'No active media source';

  @override
  String get mediaSourceFileUnsupported =>
      'This file type is not supported yet';

  @override
  String mediaSourcePlayFailed(String error) {
    return 'Playback failed: $error';
  }

  @override
  String get browserRefreshDir => 'Refresh directory';

  @override
  String browserCurrentPath(String path) {
    return 'Current path: $path';
  }

  @override
  String get browserRootDir => 'Root';

  @override
  String get browserLoadingDir => 'Loading directory...';

  @override
  String get browserLoadFailed => 'Directory load failed';

  @override
  String get browserReload => 'Reload';

  @override
  String get browserDirEmpty => 'Directory is empty';

  @override
  String get browserDirEmptyHint =>
      'No files or folders to display in this directory.';

  @override
  String get browserFolder => 'Folder';

  @override
  String get browserClickToEnter => 'Click to enter';

  @override
  String get browserBackToLibrary => 'Back to media library';

  @override
  String get mediaTypeEmbyService => 'Media service and metadata management';

  @override
  String get mediaTypeSmbShare => 'LAN shared directory browsing';

  @override
  String get mediaTypeFtpServer => 'Remote file server access';

  @override
  String get mediaTypeFolder => 'Folder';

  @override
  String get mediaTypeVideo => 'Video';

  @override
  String get mediaTypeAudio => 'Audio';

  @override
  String get mediaTypeSubtitle => 'Subtitle';

  @override
  String get mediaTypeFile => 'File';

  @override
  String get mediaTypeUsernameNotSet => 'Username not set';

  @override
  String mediaTypeUser(String name) {
    return 'User $name';
  }

  @override
  String get mediaTypeShareNotSet => 'Share name not set';

  @override
  String mediaTypeShare(String name) {
    return 'Share $name';
  }

  @override
  String get mediaTypeAnonymous => 'Anonymous access';

  @override
  String get accountCenter => 'Account Center';

  @override
  String get accountRefreshInfo => 'Refresh account info';

  @override
  String get accountNoInfo => 'Account info unavailable';

  @override
  String get accountNoInfoHint => 'Please re-login or go back and try again.';

  @override
  String get accountGoBack => 'Go back';

  @override
  String get accountAvatarUpdated => 'Avatar updated';

  @override
  String accountAvatarSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get accountRefreshed => 'Account data refreshed';

  @override
  String get accountRefreshFailed => 'Refresh failed, please try again later';

  @override
  String get accountTypeFree => 'Free';

  @override
  String get accountTypePro => 'Pro Member';

  @override
  String get accountTypeLifetime => 'Lifetime Member';

  @override
  String get accountLabelFree => 'Current Plan';

  @override
  String get accountLabelPro => 'Pro Access';

  @override
  String get accountLabelLifetime => 'Lifetime Access';

  @override
  String get accountPlanFree => 'Current Plan';

  @override
  String get accountPlanPro => 'Membership';

  @override
  String get accountPlanLifetime => 'Lifetime';

  @override
  String get accountDescFree =>
      'Local playback, library management and basic services are ready.';

  @override
  String get accountDescPro =>
      'Cross-device sync, more device quota and premium experience enabled.';

  @override
  String get accountDescLifetime =>
      'All Pro features included, no renewal needed.';

  @override
  String get accountFeatureLocalPlayback => 'Local playback';

  @override
  String get accountFeatureLibraryManagement => 'Library management';

  @override
  String get accountFeatureBasicService => 'Basic service';

  @override
  String get accountFeatureCloudSync => 'Cloud sync';

  @override
  String get accountFeatureMoreDevices => 'More devices';

  @override
  String get accountFeatureAdvancedWorkspace => 'Advanced workspace';

  @override
  String get accountFeaturePriorityAccess => 'Priority access';

  @override
  String get accountFeatureUnlimitedDevices => 'Unlimited devices';

  @override
  String get accountFeatureLargerQuota => 'Larger quota';

  @override
  String get accountFeatureNoRenewal => 'No renewal';

  @override
  String get accountRegisteredAt => 'Registered';

  @override
  String get accountLastUpdate => 'Last update';

  @override
  String get accountCloudSync => 'Cloud sync';

  @override
  String get accountSyncEnabled => 'Enabled';

  @override
  String get accountSyncDisabled => 'Disabled';

  @override
  String get accountUsage => 'Usage';

  @override
  String get accountUsageDescription =>
      'Current usage of servers, devices and storage quota.';

  @override
  String get accountUsageServers => 'Servers';

  @override
  String get accountUsageDevices => 'Devices';

  @override
  String get accountUsageStorage => 'Storage';

  @override
  String get accountUsageUnlimited => 'Unlimited';

  @override
  String get accountSyncTitle => 'Cloud Sync';

  @override
  String get accountSyncEnabledDesc =>
      'Media servers and config data synced securely';

  @override
  String get accountSyncDisabledProDesc =>
      'Enter password to enable encrypted sync';

  @override
  String get accountSyncDisabledFreeDesc =>
      'Upgrade to enable cross-device sync';

  @override
  String get accountEnableSync => 'Enable Cloud Sync';

  @override
  String get accountViewUpgrade => 'View Upgrade Plans';

  @override
  String get accountAdminTools => 'Admin Tools';

  @override
  String get accountAdminDesc => 'Manage redemption codes and backend config.';

  @override
  String get accountRedemptionManagement => 'Redemption Codes';

  @override
  String get accountRedemptionDesc =>
      'Generate, view and manage redemption codes';

  @override
  String get accountUpgradeTitle => 'Membership Upgrade';

  @override
  String get accountUpgradeToLifetime => 'Upgrade to Lifetime';

  @override
  String get accountUpgradeToPro => 'Upgrade to Pro';

  @override
  String get accountUpgradeLifetimeDesc =>
      'One-time upgrade, keep premium sync and more device quota.';

  @override
  String get accountUpgradeProDesc =>
      'Unlock cross-device sync, more premium features and higher quota.';

  @override
  String get accountViewLifetimePlan => 'View Lifetime Plan';

  @override
  String get accountViewProPlan => 'View Pro Plan';

  @override
  String get accountLogout => 'Sign Out';

  @override
  String get accountLogoutDesc =>
      'After signing out, local sync password will be cleared, re-login required.';

  @override
  String get accountLogoutConfirmTitle => 'Confirm Sign Out';

  @override
  String get accountLogoutConfirmMessage =>
      'After signing out, local sync password will be cleared.';

  @override
  String get accountLogoutButton => 'Sign Out';

  @override
  String get accountEnableSyncTitle => 'Enable Cloud Sync';

  @override
  String get accountEnableSyncMessage =>
      'Enter your password to verify and enable encrypted sync.';

  @override
  String get accountPasswordLabel => 'Password';

  @override
  String get accountPasswordHint => 'Enter password';

  @override
  String get accountPasswordRequired => 'Please enter password';

  @override
  String get accountEnableSyncButton => 'Enable Now';

  @override
  String get accountSyncEnabledSuccess => 'Cloud sync enabled';

  @override
  String get accountSyncEnableFailed =>
      'Password incorrect or enable failed, please try again';

  @override
  String accountExpiresAt(String date) {
    return 'Expires: $date';
  }

  @override
  String get accountUsernameNotSet => 'Username not set';

  @override
  String get accountLifetimeRightsTitle => 'BovaPlayer\nLifetime Access';

  @override
  String get accountLifetimeChip => 'Lifetime';

  @override
  String get accountVip => 'VIP';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowRestore => 'Restore';

  @override
  String get windowClose => 'Close';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeCyberpunk => 'Cyberpunk';

  @override
  String get settingsThemeCyberpunkPro => 'Cyberpunk Pro';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsLanguageZh => 'Chinese (Simplified)';

  @override
  String get authLoginTitle => 'Sign In';

  @override
  String get authLoginSubtitle =>
      'Enter email and password, or sign in with GitHub.';

  @override
  String get authEmailLabel => 'Email Address';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => 'Enter your password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authLoginButton => 'Sign In';

  @override
  String get authOrThirdParty => 'or sign in with';

  @override
  String get authGitHubLogin => 'Sign in with GitHub';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authRegisterNow => 'Register now';

  @override
  String get authLoginSuccess => 'Login successful!';

  @override
  String get authLoginFailed => 'Login failed';

  @override
  String get authGitHubLoginFailed => 'GitHub login failed';

  @override
  String get authInvalidEmail => 'Please enter a valid email address';

  @override
  String get authEnterPassword => 'Please enter password';

  @override
  String get authRegisterTitle => 'Create Account';

  @override
  String get authRegisterHeading => 'Create your account';

  @override
  String get authRegisterSubtitle =>
      'Register to enable media sync, purchase plans, and manage your workspace.';

  @override
  String get authRegisterDesc =>
      'Fill in basic info to get started. Username can be adjusted later in Account Center.';

  @override
  String get authRegisterFactSync => 'Cloud sync';

  @override
  String get authRegisterFactSyncValue => 'Available after registration';

  @override
  String get authRegisterFactRights => 'Rights management';

  @override
  String get authRegisterFactRightsValue => 'Upgrade & redeem supported';

  @override
  String get authRegisterFactSecurity => 'Account security';

  @override
  String get authRegisterFactSecurityValue => 'Email verification';

  @override
  String get authUsernameLabel => 'Username (optional)';

  @override
  String get authUsernameHint => 'Enter your username';

  @override
  String get authConfirmPasswordLabel => 'Confirm Password';

  @override
  String get authConfirmPasswordHint => 'Enter password again';

  @override
  String get authPasswordMinLength => 'Password must be at least 8 characters';

  @override
  String get authPasswordHintRegister =>
      'At least 8 chars, letters and numbers recommended';

  @override
  String get authPasswordMismatch => 'Passwords do not match';

  @override
  String get authRegisterButton => 'Register';

  @override
  String get authHasAccount => 'Already have an account?';

  @override
  String get authLoginNow => 'Sign in now';

  @override
  String get authRegisterSuccess =>
      'Registration successful! Please check your email for verification.';

  @override
  String get authRegisterFailed => 'Registration failed';

  @override
  String get authRegisterTooFrequent =>
      'Too many requests, please wait 45 seconds';

  @override
  String get authRegisterDbError =>
      'Database configuration error, contact admin';

  @override
  String get authRegisterEmailTaken => 'This email is already registered';

  @override
  String get authForgotTitle => 'Reset Password';

  @override
  String get authForgotCheckEmail => 'Check your email';

  @override
  String get authForgotSubtitleSent =>
      'Email has been sent. Complete password reset from your inbox, then log in again.';

  @override
  String get authForgotSubtitleForm =>
      'Enter your registration email and we will send a reset link.';

  @override
  String get authForgotFactEmailStatus => 'Email status';

  @override
  String get authForgotFactEmailSent => 'Sent';

  @override
  String get authForgotFactNextStep => 'Next step';

  @override
  String get authForgotFactNextStepValue => 'Check inbox & click link';

  @override
  String get authForgotFactEmailVerify => 'Email verification';

  @override
  String get authForgotFactRequired => 'Required';

  @override
  String get authForgotFactResetMethod => 'Reset method';

  @override
  String get authForgotFactResetViaEmail => 'Email link';

  @override
  String get authForgotSendLink => 'Send Reset Link';

  @override
  String get authForgotFormDesc =>
      'Enter your registration email, we will send a password reset link.';

  @override
  String get authForgotRemembered => 'Remember your password?';

  @override
  String get authForgotBackToLogin => 'Back to login';

  @override
  String get authForgotEmailSentTitle => 'Email Sent';

  @override
  String authForgotEmailSentDesc(String email) {
    return 'We have sent a password reset link to $email. Please check your inbox.';
  }

  @override
  String get authForgotReturnLogin => 'Back to login';

  @override
  String get authForgotResend => 'Resend';

  @override
  String get authForgotSendFailed => 'Send failed';

  @override
  String authRedeemFailed(String error) {
    return 'Redemption failed: $error';
  }

  @override
  String authGenerateFailed(String error) {
    return 'Generation failed: $error';
  }

  @override
  String authQueryFailed(String error) {
    return 'Query failed: $error';
  }

  @override
  String get pricingTitle => 'Membership Plans';

  @override
  String get pricingChoosePlan => 'Choose the right plan for you';

  @override
  String get pricingHeroDesc =>
      'Account, benefits and upgrade flow are unified in one workspace. You can upgrade directly or enter a redemption code first.';

  @override
  String get pricingCrossDeviceSync => 'Cross-device sync';

  @override
  String get pricingDeviceQuota => 'Device quota';

  @override
  String get pricingCloudStorage => 'Cloud storage';

  @override
  String get pricingPlanFree => 'Community Free';

  @override
  String get pricingPlanFreePrice => '¥0';

  @override
  String get pricingPlanFreePeriod => 'Free forever';

  @override
  String get pricingPlanFreeDesc =>
      'Ideal for lightweight use and local playback, retaining the most basic core capabilities.';

  @override
  String get pricingPlanFreeCta => 'Current Plan';

  @override
  String get pricingPlanFreeFeature1 => 'Up to 10 servers';

  @override
  String get pricingPlanFreeFeature2 => 'Up to 2 devices';

  @override
  String get pricingPlanFreeFeature3 => '100 MB cloud storage';

  @override
  String get pricingPlanFreeFeature4 => 'Basic playback';

  @override
  String get pricingPlanFreeFeature5 => 'Community support';

  @override
  String get pricingPlanPro => 'Pro';

  @override
  String get pricingPlanProPrice => '¥6.9';

  @override
  String get pricingPlanProPeriod => '/ month';

  @override
  String get pricingPlanProDesc =>
      'The go-to plan for multi-device, multi-library and cross-device sync.';

  @override
  String get pricingPlanProCta => 'Upgrade to Pro';

  @override
  String get pricingPlanProFeature1 => 'Unlimited servers';

  @override
  String get pricingPlanProFeature2 => 'Up to 5 devices';

  @override
  String get pricingPlanProFeature3 => '1 GB cloud storage';

  @override
  String get pricingPlanProFeature4 => 'Advanced playback';

  @override
  String get pricingPlanProFeature5 => 'Priority support';

  @override
  String get pricingPlanProFeature6 => 'GitHub sync';

  @override
  String get pricingPlanLifetime => 'Lifetime';

  @override
  String get pricingPlanLifetimePrice => '¥69';

  @override
  String get pricingPlanLifetimePeriod => 'One-time payment';

  @override
  String get pricingPlanLifetimeDesc =>
      'Buy once, unlock premium sync, full quota and future updates permanently.';

  @override
  String get pricingPlanLifetimeCta => 'Unlock Lifetime';

  @override
  String get pricingPlanLifetimeFeature1 => 'Unlimited servers';

  @override
  String get pricingPlanLifetimeFeature2 => 'Unlimited devices';

  @override
  String get pricingPlanLifetimeFeature3 => '5 GB cloud storage';

  @override
  String get pricingPlanLifetimeFeature4 => 'All premium features';

  @override
  String get pricingPlanLifetimeFeature5 => 'Lifetime updates';

  @override
  String get pricingPlanLifetimeFeature6 => 'Priority support';

  @override
  String get pricingPlanLifetimeFeature7 => 'GitHub sync';

  @override
  String get pricingRecommended => 'Recommended';

  @override
  String get pricingCurrentPlan => 'Current Plan';

  @override
  String get pricingFeatureComparison => 'Feature Comparison';

  @override
  String get pricingFeatureComparisonDesc =>
      'Quickly compare core capabilities of each plan in one table.';

  @override
  String get pricingServerCount => 'Servers';

  @override
  String get pricingDeviceCount => 'Devices';

  @override
  String get pricingGitHubSync => 'GitHub Sync';

  @override
  String get pricingPrioritySupport => 'Priority Support';

  @override
  String get pricingLifetimeUpdates => 'Lifetime Updates';

  @override
  String get pricingSupported => 'Supported';

  @override
  String get pricingUnlimited => 'Unlimited';

  @override
  String get pricingFaq => 'FAQ';

  @override
  String get pricingFaqDesc =>
      'Most frequently asked questions before purchasing or redeeming.';

  @override
  String get pricingFaqQ1 => 'How soon does it take effect after purchase?';

  @override
  String get pricingFaqA1 =>
      'Account benefits update immediately after payment or redemption. Re-enter the account page to see the latest status.';

  @override
  String get pricingFaqQ2 => 'Can I enter a redemption code first?';

  @override
  String get pricingFaqA2 =>
      'Yes. Enter the code directly in the purchase confirmation popup, and the system will try to redeem it first.';

  @override
  String get pricingFaqQ3 => 'What\'s the difference between Pro and Lifetime?';

  @override
  String get pricingFaqA3 =>
      'Pro is better for monthly subscription and continuous use; Lifetime is better for long-term power users with one-time unlock.';

  @override
  String get pricingConfirmPurchase => 'Confirm Purchase';

  @override
  String get pricingHaveRedemptionCode => 'Have a redemption code?';

  @override
  String get pricingRedemptionCode => 'Redemption Code';

  @override
  String get pricingRedeem => 'Redeem';

  @override
  String get pricingGoPay => 'Go Pay';

  @override
  String get pricingProMonthly => 'Pro (Monthly)';

  @override
  String get pricingProMonthlyPrice => '¥6.9 / month';

  @override
  String get pricingLifetimeOnce => '¥69 (one-time)';

  @override
  String get pricingRedeemSuccess => 'Redeemed Successfully';

  @override
  String get pricingAccountUpdated => 'Account benefits have been updated.';

  @override
  String get pricingOk => 'OK';

  @override
  String get pricingRedeemFailed => 'Redemption failed';

  @override
  String pricingRedeemError(String error) {
    return 'Redemption failed: $error';
  }

  @override
  String get danmakuSettings => 'Danmaku Settings';

  @override
  String get danmakuShowDanmaku => 'Show Danmaku';

  @override
  String get danmakuOpacity => 'Opacity';

  @override
  String get danmakuFontSize => 'Font Size';

  @override
  String get danmakuSpeed => 'Danmaku Speed';

  @override
  String get danmakuDisplayArea => 'Display Area';

  @override
  String get danmakuFullScreen => 'Full screen';

  @override
  String get danmakuThreeQuarters => '3/4 screen';

  @override
  String get danmakuHalfScreen => 'Half screen';

  @override
  String get danmakuQuarterScreen => '1/4 screen';

  @override
  String get danmakuUnknownVideo => 'Unknown video';

  @override
  String danmakuCount(int count) {
    return '$count danmaku total';
  }

  @override
  String get danmakuUpgradeToPro => 'Upgrade to Pro';

  @override
  String get danmakuUpgradeDesc =>
      'Danmaku feature is only available for Pro and Lifetime users.\n\nAfter upgrading:\n• Real-time danmaku display\n• Custom danmaku settings\n• Cloud sync\n• More advanced features';

  @override
  String get danmakuViewPlans => 'View Plans';

  @override
  String get danmakuUpgradeUnlock => 'Upgrade to Pro to unlock danmaku';

  @override
  String get danmakuUpgrade => 'Upgrade';

  @override
  String get netBrowserTitle => 'Network Browser';

  @override
  String netBrowserLoadConnectionsFailed(String error) {
    return 'Failed to load connections: $error';
  }

  @override
  String get netBrowserConnectionFailed => 'Connection failed';

  @override
  String netBrowserConnectionError(String error) {
    return 'Connection failed: $error';
  }

  @override
  String netBrowserLoadDirFailed(String error) {
    return 'Failed to load directory: $error';
  }

  @override
  String netBrowserPlayFailed(String error) {
    return 'Playback failed: $error';
  }

  @override
  String get netBrowserNoConnections =>
      'No connections yet\nTap + at bottom right to add';

  @override
  String get netBrowserDirEmpty => 'Directory is empty';

  @override
  String get netBrowserRetry => 'Retry';

  @override
  String get netBrowserAddConnection => 'Add Connection';

  @override
  String get netBrowserProtocol => 'Protocol';

  @override
  String get netBrowserName => 'Name';

  @override
  String get netBrowserHost => 'Host';

  @override
  String get netBrowserPort => 'Port';

  @override
  String get netBrowserUsername => 'Username';

  @override
  String get netBrowserPassword => 'Password';

  @override
  String get netBrowserShareName => 'Share Name';

  @override
  String get netBrowserShareHint => 'e.g. share, movies';

  @override
  String get netBrowserWorkgroup => 'Workgroup';

  @override
  String get netBrowserWorkgroupHint => 'Default: WORKGROUP';

  @override
  String get netBrowserSavePassword => 'Save password';

  @override
  String get netBrowserEnterName => 'Please enter name';

  @override
  String get netBrowserEnterHost => 'Please enter host';

  @override
  String get netBrowserEnterPort => 'Please enter port';

  @override
  String get netBrowserEnterShareName => 'Please enter share name';

  @override
  String get redemptionTitle => 'Redemption Code Management';

  @override
  String get redemptionHeroTitle => 'Manage Redemption Codes';

  @override
  String get redemptionHeroDesc =>
      'Unified view of code status, type, expiry and generation entry. Consistent with account workspace style.';

  @override
  String get redemptionGenerateTooltip => 'Generate code';

  @override
  String get redemptionFilterAll => 'All';

  @override
  String get redemptionFilterUnused => 'Unused';

  @override
  String get redemptionFilterUsed => 'Used';

  @override
  String get redemptionFilterExpired => 'Expired';

  @override
  String get redemptionLoadFailed => 'Failed to load';

  @override
  String redemptionLoadError(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get redemptionEmpty => 'No redemption codes';

  @override
  String get redemptionEmptyHint =>
      'Tap the plus icon at top right to generate new codes.';

  @override
  String get redemptionStatusUsed => 'Used';

  @override
  String get redemptionStatusExpired => 'Expired';

  @override
  String get redemptionStatusAvailable => 'Available';

  @override
  String get redemptionTypePro => 'Pro';

  @override
  String get redemptionTypeLifetime => 'Lifetime';

  @override
  String get redemptionCopyTooltip => 'Copy code';

  @override
  String get redemptionCopied => 'Copied code';

  @override
  String get redemptionCreatedAt => 'Created at';

  @override
  String get redemptionExpiresAt => 'Expires at';

  @override
  String get redemptionUsedBy => 'Used by';

  @override
  String get redemptionUsedAt => 'Used at';

  @override
  String get redemptionGenerateTitle => 'Generate Codes';

  @override
  String get redemptionGenerateDesc =>
      'Select benefit type and fill in quantity, validity days and notes.';

  @override
  String get redemptionGenerateCount => 'Quantity';

  @override
  String get redemptionGenerateCountHint => '1-100';

  @override
  String get redemptionProDuration => 'Pro validity days';

  @override
  String get redemptionProDurationHint => 'e.g. 30, 90, 365';

  @override
  String get redemptionCodeExpiry => 'Code expiry days';

  @override
  String get redemptionCodeExpiryHint =>
      'Valid for how many days after generation';

  @override
  String get redemptionNote => 'Note (optional)';

  @override
  String get redemptionNoteHint => 'e.g. For event users';

  @override
  String get redemptionGenerate => 'Generate';

  @override
  String redemptionGenerateSuccess(int count) {
    return 'Successfully generated $count codes';
  }

  @override
  String redemptionCopiedCode(String code) {
    return 'Copied: $code';
  }

  @override
  String get redemptionGenerateFailed => 'Generation failed';

  @override
  String redemptionGenerateError(String error) {
    return 'Generation failed: $error';
  }
}
