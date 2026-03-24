import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
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
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

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
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'BovaPlayer'**
  String get appTitle;

  /// No description provided for @discoverTrendingNow.
  ///
  /// In en, this message translates to:
  /// **'Trending Now'**
  String get discoverTrendingNow;

  /// No description provided for @discoverTrendingNowSub.
  ///
  /// In en, this message translates to:
  /// **'The titles getting the most attention today'**
  String get discoverTrendingNowSub;

  /// No description provided for @discoverPopularMovies.
  ///
  /// In en, this message translates to:
  /// **'Popular Movies'**
  String get discoverPopularMovies;

  /// No description provided for @discoverPopularMoviesSub.
  ///
  /// In en, this message translates to:
  /// **'Big-screen picks with broad appeal'**
  String get discoverPopularMoviesSub;

  /// No description provided for @discoverPopularTV.
  ///
  /// In en, this message translates to:
  /// **'Popular TV'**
  String get discoverPopularTV;

  /// No description provided for @discoverPopularTVSub.
  ///
  /// In en, this message translates to:
  /// **'Series people keep coming back to'**
  String get discoverPopularTVSub;

  /// No description provided for @discoverTrendingMovies.
  ///
  /// In en, this message translates to:
  /// **'Trending Movies'**
  String get discoverTrendingMovies;

  /// No description provided for @discoverTrendingMoviesSub.
  ///
  /// In en, this message translates to:
  /// **'Today\'s biggest movie momentum'**
  String get discoverTrendingMoviesSub;

  /// No description provided for @discoverNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get discoverNowPlaying;

  /// No description provided for @discoverNowPlayingSub.
  ///
  /// In en, this message translates to:
  /// **'Movies currently rolling out worldwide'**
  String get discoverNowPlayingSub;

  /// No description provided for @discoverMovies.
  ///
  /// In en, this message translates to:
  /// **'Discover Movies'**
  String get discoverMovies;

  /// No description provided for @discoverMoviesSub.
  ///
  /// In en, this message translates to:
  /// **'High-popularity films surfaced from TMDB Discover'**
  String get discoverMoviesSub;

  /// No description provided for @discoverTrendingShows.
  ///
  /// In en, this message translates to:
  /// **'Trending Shows'**
  String get discoverTrendingShows;

  /// No description provided for @discoverTrendingShowsSub.
  ///
  /// In en, this message translates to:
  /// **'Series that are surging right now'**
  String get discoverTrendingShowsSub;

  /// No description provided for @discoverPopularTVShows.
  ///
  /// In en, this message translates to:
  /// **'Popular TV'**
  String get discoverPopularTVShows;

  /// No description provided for @discoverPopularTVShowsSub.
  ///
  /// In en, this message translates to:
  /// **'Broad-appeal TV picks from TMDB'**
  String get discoverPopularTVShowsSub;

  /// No description provided for @discoverTV.
  ///
  /// In en, this message translates to:
  /// **'Discover TV'**
  String get discoverTV;

  /// No description provided for @discoverTVSub.
  ///
  /// In en, this message translates to:
  /// **'Fresh series surfaced by popularity'**
  String get discoverTVSub;

  /// No description provided for @playerLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get playerLoading;

  /// No description provided for @playerFilePickError.
  ///
  /// In en, this message translates to:
  /// **'File pick failed: {error}'**
  String playerFilePickError(String error);

  /// No description provided for @playerPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed: {error}'**
  String playerPlayFailed(String error);

  /// No description provided for @playerRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get playerRetry;

  /// No description provided for @playerNoVideo.
  ///
  /// In en, this message translates to:
  /// **'No video selected'**
  String get playerNoVideo;

  /// No description provided for @playerNoVideoHint.
  ///
  /// In en, this message translates to:
  /// **'Click the folder icon at top right to select a video'**
  String get playerNoVideoHint;

  /// No description provided for @playerSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Select Video File'**
  String get playerSelectFile;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get navMovies;

  /// No description provided for @navShows.
  ///
  /// In en, this message translates to:
  /// **'Shows'**
  String get navShows;

  /// No description provided for @navPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get navPlayer;

  /// No description provided for @navMediaLibrary.
  ///
  /// In en, this message translates to:
  /// **'Media Library'**
  String get navMediaLibrary;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// No description provided for @mobileNavDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get mobileNavDiscover;

  /// No description provided for @mobileNavPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get mobileNavPlayer;

  /// No description provided for @mobileNavLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get mobileNavLibrary;

  /// No description provided for @sidebarCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get sidebarCollapse;

  /// No description provided for @sidebarExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get sidebarExpand;

  /// No description provided for @sidebarSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get sidebarSignOut;

  /// No description provided for @profileGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String profileGreeting(String name);

  /// No description provided for @profileGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get profileGuest;

  /// No description provided for @profileDiscovering.
  ///
  /// In en, this message translates to:
  /// **'Discovering'**
  String get profileDiscovering;

  /// No description provided for @profileWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get profileWatching;

  /// No description provided for @profileBrowsing.
  ///
  /// In en, this message translates to:
  /// **'Browsing'**
  String get profileBrowsing;

  /// No description provided for @profileManagingAccount.
  ///
  /// In en, this message translates to:
  /// **'Managing account'**
  String get profileManagingAccount;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get actionBookmarks;

  /// No description provided for @actionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get actionNotifications;

  /// No description provided for @actionRefreshSync.
  ///
  /// In en, this message translates to:
  /// **'Refresh & Sync'**
  String get actionRefreshSync;

  /// No description provided for @actionSearchMedia.
  ///
  /// In en, this message translates to:
  /// **'Search media'**
  String get actionSearchMedia;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @exitAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get exitAppTitle;

  /// No description provided for @exitAppMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit BovaPlayer?'**
  String get exitAppMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

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

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @bookmarkSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get bookmarkSave;

  /// No description provided for @bookmarkSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get bookmarkSaved;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'{label} is coming next.'**
  String comingSoon(String label);

  /// No description provided for @addEmbyServer.
  ///
  /// In en, this message translates to:
  /// **'Emby Server'**
  String get addEmbyServer;

  /// No description provided for @addSmbShare.
  ///
  /// In en, this message translates to:
  /// **'SMB Share'**
  String get addSmbShare;

  /// No description provided for @addFtpServer.
  ///
  /// In en, this message translates to:
  /// **'FTP Server'**
  String get addFtpServer;

  /// No description provided for @selectLibrary.
  ///
  /// In en, this message translates to:
  /// **'Select library to enter'**
  String get selectLibrary;

  /// No description provided for @discoverNotFoundInLibrary.
  ///
  /// In en, this message translates to:
  /// **'Could not find \"{title}\" in connected Emby libraries'**
  String discoverNotFoundInLibrary(String title);

  /// No description provided for @bookmarkAdded.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked: {title}'**
  String bookmarkAdded(String title);

  /// No description provided for @bookmarkRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed bookmark: {title}'**
  String bookmarkRemoved(String title);

  /// No description provided for @bookmarkSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save bookmark, please try again'**
  String get bookmarkSaveFailed;

  /// No description provided for @quickPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Quick play failed, please try again'**
  String get quickPlayFailed;

  /// No description provided for @followSeriesStart.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get followSeriesStart;

  /// No description provided for @followSeriesActive.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followSeriesActive;

  /// No description provided for @followSeriesCancel.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get followSeriesCancel;

  /// No description provided for @followSeriesUpdated.
  ///
  /// In en, this message translates to:
  /// **'New episode'**
  String get followSeriesUpdated;

  /// No description provided for @followSeriesStarted.
  ///
  /// In en, this message translates to:
  /// **'Started following: {title}'**
  String followSeriesStarted(String title);

  /// No description provided for @followSeriesCanceled.
  ///
  /// In en, this message translates to:
  /// **'Stopped following: {title}'**
  String followSeriesCanceled(String title);

  /// No description provided for @followSeriesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No Emby series available for following'**
  String get followSeriesUnavailable;

  /// No description provided for @discoverBookmarksSortedByUpdates.
  ///
  /// In en, this message translates to:
  /// **'Followed shows with new episodes are shown first.'**
  String get discoverBookmarksSortedByUpdates;

  /// No description provided for @discoverOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get discoverOpen;

  /// No description provided for @discoverFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get discoverFeatured;

  /// No description provided for @discoverHotWall.
  ///
  /// In en, this message translates to:
  /// **'Hot Wall'**
  String get discoverHotWall;

  /// No description provided for @discoverHotWallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A live grid of high-interest titles pulled from TMDB.'**
  String get discoverHotWallSubtitle;

  /// No description provided for @discoverTmdbCredentials.
  ///
  /// In en, this message translates to:
  /// **'{title} needs TMDB credentials'**
  String discoverTmdbCredentials(String title);

  /// No description provided for @discoverTmdbCredentialsHint.
  ///
  /// In en, this message translates to:
  /// **'Add `TMDB_READ_ACCESS_TOKEN` or `TMDB_API_KEY` to `ui/flutter_app/.env` to load live posters, trending picks and featured backdrops.'**
  String get discoverTmdbCredentialsHint;

  /// No description provided for @discoverSearchResultsFor.
  ///
  /// In en, this message translates to:
  /// **'Results for \"{query}\"'**
  String discoverSearchResultsFor(String query);

  /// No description provided for @discoverExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get discoverExplore;

  /// No description provided for @discoverUnableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load discover feed'**
  String get discoverUnableToLoad;

  /// No description provided for @discoverTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get discoverTryAgain;

  /// No description provided for @discoverSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search movies and shows from TMDB'**
  String get discoverSearchHint;

  /// No description provided for @discoverSearchGuide.
  ///
  /// In en, this message translates to:
  /// **'Type a title to search TMDB and jump straight into your libraries.'**
  String get discoverSearchGuide;

  /// No description provided for @discoverTmdbNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'TMDB not configured'**
  String get discoverTmdbNotConfigured;

  /// No description provided for @discoverTmdbNotConfiguredHint.
  ///
  /// In en, this message translates to:
  /// **'Add your TMDB token first to use search.'**
  String get discoverTmdbNotConfiguredHint;

  /// No description provided for @discoverStartSearching.
  ///
  /// In en, this message translates to:
  /// **'Start searching'**
  String get discoverStartSearching;

  /// No description provided for @discoverSearchExploreHint.
  ///
  /// In en, this message translates to:
  /// **'Find a movie or show, then Explore or quick-play it from your matched libraries.'**
  String get discoverSearchExploreHint;

  /// No description provided for @discoverNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get discoverNoResults;

  /// No description provided for @discoverNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try another title, original name, or shorter keyword.'**
  String get discoverNoResultsHint;

  /// No description provided for @discoverNoBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get discoverNoBookmarks;

  /// No description provided for @discoverNoBookmarksHint.
  ///
  /// In en, this message translates to:
  /// **'Save titles from the featured hero or search results and they will show up here.'**
  String get discoverNoBookmarksHint;

  /// No description provided for @discoverBookmarkCount.
  ///
  /// In en, this message translates to:
  /// **'{count} saved titles ready for Explore or quick play.'**
  String discoverBookmarkCount(int count);

  /// No description provided for @discoverExpandSources.
  ///
  /// In en, this message translates to:
  /// **'Expand {count} more sources'**
  String discoverExpandSources(int count);

  /// No description provided for @discoverLatencyGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get discoverLatencyGood;

  /// No description provided for @discoverLatencyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get discoverLatencyMedium;

  /// No description provided for @discoverLatencySlow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get discoverLatencySlow;

  /// No description provided for @discoverLatencyUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get discoverLatencyUnreachable;

  /// No description provided for @embyServers.
  ///
  /// In en, this message translates to:
  /// **'Emby Servers'**
  String get embyServers;

  /// No description provided for @embyServersDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your Emby connections in the media library workspace.'**
  String get embyServersDesc;

  /// No description provided for @embyNoServers.
  ///
  /// In en, this message translates to:
  /// **'No servers added yet'**
  String get embyNoServers;

  /// No description provided for @embyNoServersHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the button in the top-right to add an Emby server. Your media library will be displayed here after connection.'**
  String get embyNoServersHint;

  /// No description provided for @embyNoServersHintMobile.
  ///
  /// In en, this message translates to:
  /// **'Tap the button above to add an Emby server'**
  String get embyNoServersHintMobile;

  /// No description provided for @embyEditServer.
  ///
  /// In en, this message translates to:
  /// **'Edit Server'**
  String get embyEditServer;

  /// No description provided for @embyAddServer.
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get embyAddServer;

  /// No description provided for @embyServerName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get embyServerName;

  /// No description provided for @embyServerNameHint.
  ///
  /// In en, this message translates to:
  /// **'My Emby'**
  String get embyServerNameHint;

  /// No description provided for @embyServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Server Address'**
  String get embyServerAddress;

  /// No description provided for @embyUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get embyUsername;

  /// No description provided for @embyPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get embyPassword;

  /// No description provided for @embyLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: wrong username or password'**
  String get embyLoginFailed;

  /// No description provided for @embyConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String embyConnectionFailed(String error);

  /// No description provided for @embyUser.
  ///
  /// In en, this message translates to:
  /// **'User: {name}'**
  String embyUser(String name);

  /// No description provided for @embyBackToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back to media library'**
  String get embyBackToLibrary;

  /// No description provided for @embyRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get embyRefresh;

  /// No description provided for @embyContinueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get embyContinueWatching;

  /// No description provided for @embyShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get embyShowAll;

  /// No description provided for @embyLatestAdded.
  ///
  /// In en, this message translates to:
  /// **'Latest added'**
  String get embyLatestAdded;

  /// No description provided for @embyNameSort.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get embyNameSort;

  /// No description provided for @embyYearSort.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get embyYearSort;

  /// No description provided for @embyRatingSort.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get embyRatingSort;

  /// No description provided for @embyItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String embyItemCount(int count);

  /// No description provided for @embyNoContent.
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get embyNoContent;

  /// No description provided for @embyNoContentHint.
  ///
  /// In en, this message translates to:
  /// **'No media items to display in this directory.'**
  String get embyNoContentHint;

  /// No description provided for @embySeason.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get embySeason;

  /// No description provided for @embyEpisodeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} episodes'**
  String embyEpisodeCount(int count);

  /// No description provided for @embyDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h{minutes}m'**
  String embyDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @embyDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String embyDurationMinutes(int minutes);

  /// No description provided for @embyPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get embyPlay;

  /// No description provided for @embyFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get embyFavorite;

  /// No description provided for @embyDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get embyDetails;

  /// No description provided for @embyPlaybackOptions.
  ///
  /// In en, this message translates to:
  /// **'Playback Options'**
  String get embyPlaybackOptions;

  /// No description provided for @embyVideoFormat.
  ///
  /// In en, this message translates to:
  /// **'Video Format'**
  String get embyVideoFormat;

  /// No description provided for @embyAudioFormat.
  ///
  /// In en, this message translates to:
  /// **'Audio Format'**
  String get embyAudioFormat;

  /// No description provided for @embyStreamInfo.
  ///
  /// In en, this message translates to:
  /// **'Audio/Video/Subtitle Info'**
  String get embyStreamInfo;

  /// No description provided for @embyVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get embyVideo;

  /// No description provided for @embyAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get embyAudio;

  /// No description provided for @embySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get embySubtitle;

  /// No description provided for @embyFillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill all required fields'**
  String get embyFillAllFields;

  /// No description provided for @embySwitchServer.
  ///
  /// In en, this message translates to:
  /// **'Switch server'**
  String get embySwitchServer;

  /// No description provided for @embyAddServerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get embyAddServerTooltip;

  /// No description provided for @embyExitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get embyExitApp;

  /// No description provided for @embyExitAppConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit the app?'**
  String get embyExitAppConfirm;

  /// No description provided for @embyPageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Page load failed'**
  String get embyPageLoadFailed;

  /// No description provided for @embySortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get embySortTooltip;

  /// No description provided for @embyListView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get embyListView;

  /// No description provided for @embyGridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get embyGridView;

  /// No description provided for @embyHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get embyHome;

  /// No description provided for @embyBrowseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse your media catalog by Emby directory.'**
  String get embyBrowseSubtitle;

  /// No description provided for @embyContinueBrowse.
  ///
  /// In en, this message translates to:
  /// **'Continue browsing your media catalog.'**
  String get embyContinueBrowse;

  /// No description provided for @embyBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get embyBack;

  /// No description provided for @embyEpisodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String embyEpisodeLabel(int number);

  /// No description provided for @embyStreamTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get embyStreamTitle;

  /// No description provided for @embyStreamLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get embyStreamLanguage;

  /// No description provided for @embyStreamCodec.
  ///
  /// In en, this message translates to:
  /// **'Codec'**
  String get embyStreamCodec;

  /// No description provided for @embyStreamProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get embyStreamProfile;

  /// No description provided for @embyStreamLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get embyStreamLevel;

  /// No description provided for @embyStreamResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get embyStreamResolution;

  /// No description provided for @embyStreamAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect Ratio'**
  String get embyStreamAspectRatio;

  /// No description provided for @embyStreamInterlaced.
  ///
  /// In en, this message translates to:
  /// **'Interlaced'**
  String get embyStreamInterlaced;

  /// No description provided for @embyStreamFrameRate.
  ///
  /// In en, this message translates to:
  /// **'Frame Rate'**
  String get embyStreamFrameRate;

  /// No description provided for @embyStreamBitrate.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get embyStreamBitrate;

  /// No description provided for @embyStreamVideoRange.
  ///
  /// In en, this message translates to:
  /// **'Video Range'**
  String get embyStreamVideoRange;

  /// No description provided for @embyStreamColorPrimaries.
  ///
  /// In en, this message translates to:
  /// **'Color Primaries'**
  String get embyStreamColorPrimaries;

  /// No description provided for @embyStreamColorSpace.
  ///
  /// In en, this message translates to:
  /// **'Color Space'**
  String get embyStreamColorSpace;

  /// No description provided for @embyStreamColorTransfer.
  ///
  /// In en, this message translates to:
  /// **'Color Transfer'**
  String get embyStreamColorTransfer;

  /// No description provided for @embyStreamBitDepth.
  ///
  /// In en, this message translates to:
  /// **'Bit Depth'**
  String get embyStreamBitDepth;

  /// No description provided for @embyStreamPixelFormat.
  ///
  /// In en, this message translates to:
  /// **'Pixel Format'**
  String get embyStreamPixelFormat;

  /// No description provided for @embyStreamRefFrames.
  ///
  /// In en, this message translates to:
  /// **'Reference Frames'**
  String get embyStreamRefFrames;

  /// No description provided for @embyStreamChannelLayout.
  ///
  /// In en, this message translates to:
  /// **'Channel Layout'**
  String get embyStreamChannelLayout;

  /// No description provided for @embyStreamChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get embyStreamChannels;

  /// No description provided for @embyStreamSampleRate.
  ///
  /// In en, this message translates to:
  /// **'Sample Rate'**
  String get embyStreamSampleRate;

  /// No description provided for @embyStreamDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get embyStreamDefault;

  /// No description provided for @embyStreamEmbeddedTitle.
  ///
  /// In en, this message translates to:
  /// **'Embedded Title'**
  String get embyStreamEmbeddedTitle;

  /// No description provided for @embyStreamForced.
  ///
  /// In en, this message translates to:
  /// **'Forced'**
  String get embyStreamForced;

  /// No description provided for @embyYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get embyYes;

  /// No description provided for @embyNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get embyNo;

  /// No description provided for @embyType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get embyType;

  /// No description provided for @embyYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get embyYear;

  /// No description provided for @embyRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get embyRating;

  /// No description provided for @embyRuntime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get embyRuntime;

  /// No description provided for @embyScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get embyScore;

  /// No description provided for @embyOriginalTitle.
  ///
  /// In en, this message translates to:
  /// **'Original Title'**
  String get embyOriginalTitle;

  /// No description provided for @embyUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get embyUnknown;

  /// No description provided for @embyMediaContent.
  ///
  /// In en, this message translates to:
  /// **'Media Content'**
  String get embyMediaContent;

  /// No description provided for @embyPlaybackUrlFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to get playback URL'**
  String get embyPlaybackUrlFailed;

  /// No description provided for @mediaSourceList.
  ///
  /// In en, this message translates to:
  /// **'Media Source List'**
  String get mediaSourceList;

  /// No description provided for @mediaSourceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String mediaSourceCount(int count);

  /// No description provided for @mediaSourceLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading media sources...'**
  String get mediaSourceLoading;

  /// No description provided for @mediaSourceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No media sources yet'**
  String get mediaSourceEmpty;

  /// No description provided for @mediaSourceEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add Emby, SMB or FTP from the top-right, and your media sources will be listed here.'**
  String get mediaSourceEmptyHint;

  /// No description provided for @mediaSourceAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Media Source'**
  String get mediaSourceAdd;

  /// No description provided for @mediaSourceEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Media Source'**
  String get mediaSourceEdit;

  /// No description provided for @mediaSourceDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Media Source'**
  String get mediaSourceDelete;

  /// No description provided for @mediaSourceDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String mediaSourceDeleteConfirm(String name);

  /// No description provided for @mediaSourceSelectProtocol.
  ///
  /// In en, this message translates to:
  /// **'Select a protocol to configure a new content source.'**
  String get mediaSourceSelectProtocol;

  /// No description provided for @mediaSourceEmbyDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect to media service and metadata'**
  String get mediaSourceEmbyDesc;

  /// No description provided for @mediaSourceSmbDesc.
  ///
  /// In en, this message translates to:
  /// **'Add LAN shared directory'**
  String get mediaSourceSmbDesc;

  /// No description provided for @mediaSourceFtpDesc.
  ///
  /// In en, this message translates to:
  /// **'Access remote file server'**
  String get mediaSourceFtpDesc;

  /// No description provided for @mediaSourceHostAddress.
  ///
  /// In en, this message translates to:
  /// **'Host Address'**
  String get mediaSourceHostAddress;

  /// No description provided for @mediaSourcePort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get mediaSourcePort;

  /// No description provided for @mediaSourceShareName.
  ///
  /// In en, this message translates to:
  /// **'Share Name'**
  String get mediaSourceShareName;

  /// No description provided for @mediaSourceShareNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. share, movies'**
  String get mediaSourceShareNameHint;

  /// No description provided for @mediaSourceWorkgroup.
  ///
  /// In en, this message translates to:
  /// **'Workgroup'**
  String get mediaSourceWorkgroup;

  /// No description provided for @mediaSourceSavePassword.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get mediaSourceSavePassword;

  /// No description provided for @mediaSourceNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Home Server'**
  String get mediaSourceNameHint;

  /// No description provided for @mediaSourceFillRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill all required fields'**
  String get mediaSourceFillRequired;

  /// No description provided for @mediaSourceEnterShareName.
  ///
  /// In en, this message translates to:
  /// **'Please enter share name'**
  String get mediaSourceEnterShareName;

  /// No description provided for @mediaSourceConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get mediaSourceConnectionFailed;

  /// No description provided for @mediaSourceLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed, check server address and credentials'**
  String get mediaSourceLoginFailed;

  /// No description provided for @mediaSourceAddSuccess.
  ///
  /// In en, this message translates to:
  /// **'Added successfully'**
  String get mediaSourceAddSuccess;

  /// No description provided for @mediaSourceUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Updated successfully'**
  String get mediaSourceUpdateSuccess;

  /// No description provided for @mediaSourceDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deleted successfully'**
  String get mediaSourceDeleteSuccess;

  /// No description provided for @mediaSourceDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String mediaSourceDeleteFailed(String error);

  /// No description provided for @mediaSourceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String mediaSourceLoadFailed(String error);

  /// No description provided for @mediaSourceSyncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get mediaSourceSyncComplete;

  /// No description provided for @mediaSourcePleaseLogin.
  ///
  /// In en, this message translates to:
  /// **'Please login first'**
  String get mediaSourcePleaseLogin;

  /// No description provided for @mediaSourceEnableSync.
  ///
  /// In en, this message translates to:
  /// **'Please enable cloud sync in account page'**
  String get mediaSourceEnableSync;

  /// No description provided for @mediaSourceNoActive.
  ///
  /// In en, this message translates to:
  /// **'No active media source'**
  String get mediaSourceNoActive;

  /// No description provided for @mediaSourceFileUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This file type is not supported yet'**
  String get mediaSourceFileUnsupported;

  /// No description provided for @mediaSourcePlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed: {error}'**
  String mediaSourcePlayFailed(String error);

  /// No description provided for @browserRefreshDir.
  ///
  /// In en, this message translates to:
  /// **'Refresh directory'**
  String get browserRefreshDir;

  /// No description provided for @browserCurrentPath.
  ///
  /// In en, this message translates to:
  /// **'Current path: {path}'**
  String browserCurrentPath(String path);

  /// No description provided for @browserRootDir.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get browserRootDir;

  /// No description provided for @browserLoadingDir.
  ///
  /// In en, this message translates to:
  /// **'Loading directory...'**
  String get browserLoadingDir;

  /// No description provided for @browserLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Directory load failed'**
  String get browserLoadFailed;

  /// No description provided for @browserReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get browserReload;

  /// No description provided for @browserDirEmpty.
  ///
  /// In en, this message translates to:
  /// **'Directory is empty'**
  String get browserDirEmpty;

  /// No description provided for @browserDirEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No files or folders to display in this directory.'**
  String get browserDirEmptyHint;

  /// No description provided for @browserFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get browserFolder;

  /// No description provided for @browserClickToEnter.
  ///
  /// In en, this message translates to:
  /// **'Click to enter'**
  String get browserClickToEnter;

  /// No description provided for @browserBackToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back to media library'**
  String get browserBackToLibrary;

  /// No description provided for @mediaTypeEmbyService.
  ///
  /// In en, this message translates to:
  /// **'Media service and metadata management'**
  String get mediaTypeEmbyService;

  /// No description provided for @mediaTypeSmbShare.
  ///
  /// In en, this message translates to:
  /// **'LAN shared directory browsing'**
  String get mediaTypeSmbShare;

  /// No description provided for @mediaTypeFtpServer.
  ///
  /// In en, this message translates to:
  /// **'Remote file server access'**
  String get mediaTypeFtpServer;

  /// No description provided for @mediaTypeFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get mediaTypeFolder;

  /// No description provided for @mediaTypeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get mediaTypeVideo;

  /// No description provided for @mediaTypeAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get mediaTypeAudio;

  /// No description provided for @mediaTypeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get mediaTypeSubtitle;

  /// No description provided for @mediaTypeFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get mediaTypeFile;

  /// No description provided for @mediaTypeUsernameNotSet.
  ///
  /// In en, this message translates to:
  /// **'Username not set'**
  String get mediaTypeUsernameNotSet;

  /// No description provided for @mediaTypeUser.
  ///
  /// In en, this message translates to:
  /// **'User {name}'**
  String mediaTypeUser(String name);

  /// No description provided for @mediaTypeShareNotSet.
  ///
  /// In en, this message translates to:
  /// **'Share name not set'**
  String get mediaTypeShareNotSet;

  /// No description provided for @mediaTypeShare.
  ///
  /// In en, this message translates to:
  /// **'Share {name}'**
  String mediaTypeShare(String name);

  /// No description provided for @mediaTypeAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous access'**
  String get mediaTypeAnonymous;

  /// No description provided for @accountCenter.
  ///
  /// In en, this message translates to:
  /// **'Account Center'**
  String get accountCenter;

  /// No description provided for @accountRefreshInfo.
  ///
  /// In en, this message translates to:
  /// **'Refresh account info'**
  String get accountRefreshInfo;

  /// No description provided for @accountNoInfo.
  ///
  /// In en, this message translates to:
  /// **'Account info unavailable'**
  String get accountNoInfo;

  /// No description provided for @accountNoInfoHint.
  ///
  /// In en, this message translates to:
  /// **'Please re-login or go back and try again.'**
  String get accountNoInfoHint;

  /// No description provided for @accountGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get accountGoBack;

  /// No description provided for @accountAvatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get accountAvatarUpdated;

  /// No description provided for @accountAvatarSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String accountAvatarSaveFailed(String error);

  /// No description provided for @accountRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Account data refreshed'**
  String get accountRefreshed;

  /// No description provided for @accountRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed, please try again later'**
  String get accountRefreshFailed;

  /// No description provided for @accountTypeFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get accountTypeFree;

  /// No description provided for @accountTypePro.
  ///
  /// In en, this message translates to:
  /// **'Pro Member'**
  String get accountTypePro;

  /// No description provided for @accountTypeLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime Member'**
  String get accountTypeLifetime;

  /// No description provided for @accountLabelFree.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get accountLabelFree;

  /// No description provided for @accountLabelPro.
  ///
  /// In en, this message translates to:
  /// **'Pro Access'**
  String get accountLabelPro;

  /// No description provided for @accountLabelLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime Access'**
  String get accountLabelLifetime;

  /// No description provided for @accountPlanFree.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get accountPlanFree;

  /// No description provided for @accountPlanPro.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get accountPlanPro;

  /// No description provided for @accountPlanLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get accountPlanLifetime;

  /// No description provided for @accountDescFree.
  ///
  /// In en, this message translates to:
  /// **'Local playback, library management and basic services are ready.'**
  String get accountDescFree;

  /// No description provided for @accountDescPro.
  ///
  /// In en, this message translates to:
  /// **'Cross-device sync, more device quota and premium experience enabled.'**
  String get accountDescPro;

  /// No description provided for @accountDescLifetime.
  ///
  /// In en, this message translates to:
  /// **'All Pro features included, no renewal needed.'**
  String get accountDescLifetime;

  /// No description provided for @accountFeatureLocalPlayback.
  ///
  /// In en, this message translates to:
  /// **'Local playback'**
  String get accountFeatureLocalPlayback;

  /// No description provided for @accountFeatureLibraryManagement.
  ///
  /// In en, this message translates to:
  /// **'Library management'**
  String get accountFeatureLibraryManagement;

  /// No description provided for @accountFeatureBasicService.
  ///
  /// In en, this message translates to:
  /// **'Basic service'**
  String get accountFeatureBasicService;

  /// No description provided for @accountFeatureCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get accountFeatureCloudSync;

  /// No description provided for @accountFeatureMoreDevices.
  ///
  /// In en, this message translates to:
  /// **'More devices'**
  String get accountFeatureMoreDevices;

  /// No description provided for @accountFeatureAdvancedWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Advanced workspace'**
  String get accountFeatureAdvancedWorkspace;

  /// No description provided for @accountFeaturePriorityAccess.
  ///
  /// In en, this message translates to:
  /// **'Priority access'**
  String get accountFeaturePriorityAccess;

  /// No description provided for @accountFeatureUnlimitedDevices.
  ///
  /// In en, this message translates to:
  /// **'Unlimited devices'**
  String get accountFeatureUnlimitedDevices;

  /// No description provided for @accountFeatureLargerQuota.
  ///
  /// In en, this message translates to:
  /// **'Larger quota'**
  String get accountFeatureLargerQuota;

  /// No description provided for @accountFeatureNoRenewal.
  ///
  /// In en, this message translates to:
  /// **'No renewal'**
  String get accountFeatureNoRenewal;

  /// No description provided for @accountRegisteredAt.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get accountRegisteredAt;

  /// No description provided for @accountLastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last update'**
  String get accountLastUpdate;

  /// No description provided for @accountCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get accountCloudSync;

  /// No description provided for @accountSyncEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get accountSyncEnabled;

  /// No description provided for @accountSyncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get accountSyncDisabled;

  /// No description provided for @accountUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get accountUsage;

  /// No description provided for @accountUsageDescription.
  ///
  /// In en, this message translates to:
  /// **'Current usage of servers, devices and storage quota.'**
  String get accountUsageDescription;

  /// No description provided for @accountUsageServers.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get accountUsageServers;

  /// No description provided for @accountUsageDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get accountUsageDevices;

  /// No description provided for @accountUsageStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get accountUsageStorage;

  /// No description provided for @accountUsageUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get accountUsageUnlimited;

  /// No description provided for @accountSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get accountSyncTitle;

  /// No description provided for @accountSyncEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Media servers and config data synced securely'**
  String get accountSyncEnabledDesc;

  /// No description provided for @accountSyncDisabledProDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter password to enable encrypted sync'**
  String get accountSyncDisabledProDesc;

  /// No description provided for @accountSyncDisabledFreeDesc.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to enable cross-device sync'**
  String get accountSyncDisabledFreeDesc;

  /// No description provided for @accountEnableSync.
  ///
  /// In en, this message translates to:
  /// **'Enable Cloud Sync'**
  String get accountEnableSync;

  /// No description provided for @accountViewUpgrade.
  ///
  /// In en, this message translates to:
  /// **'View Upgrade Plans'**
  String get accountViewUpgrade;

  /// No description provided for @accountAdminTools.
  ///
  /// In en, this message translates to:
  /// **'Admin Tools'**
  String get accountAdminTools;

  /// No description provided for @accountAdminDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage redemption codes and backend config.'**
  String get accountAdminDesc;

  /// No description provided for @accountRedemptionManagement.
  ///
  /// In en, this message translates to:
  /// **'Redemption Codes'**
  String get accountRedemptionManagement;

  /// No description provided for @accountRedemptionDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate, view and manage redemption codes'**
  String get accountRedemptionDesc;

  /// No description provided for @accountPricingManagement.
  ///
  /// In en, this message translates to:
  /// **'Pricing Management'**
  String get accountPricingManagement;

  /// No description provided for @accountPricingDesc.
  ///
  /// In en, this message translates to:
  /// **'Edit pricing_configs to keep storefront and checkout amounts in sync.'**
  String get accountPricingDesc;

  /// No description provided for @accountUpgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership Upgrade'**
  String get accountUpgradeTitle;

  /// No description provided for @accountUpgradeToLifetime.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Lifetime'**
  String get accountUpgradeToLifetime;

  /// No description provided for @accountUpgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get accountUpgradeToPro;

  /// No description provided for @accountUpgradeLifetimeDesc.
  ///
  /// In en, this message translates to:
  /// **'One-time upgrade, keep premium sync and more device quota.'**
  String get accountUpgradeLifetimeDesc;

  /// No description provided for @accountUpgradeProDesc.
  ///
  /// In en, this message translates to:
  /// **'Unlock cross-device sync, more premium features and higher quota.'**
  String get accountUpgradeProDesc;

  /// No description provided for @accountViewLifetimePlan.
  ///
  /// In en, this message translates to:
  /// **'View Lifetime Plan'**
  String get accountViewLifetimePlan;

  /// No description provided for @accountViewProPlan.
  ///
  /// In en, this message translates to:
  /// **'View Pro Plan'**
  String get accountViewProPlan;

  /// No description provided for @accountLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get accountLogout;

  /// No description provided for @accountLogoutDesc.
  ///
  /// In en, this message translates to:
  /// **'After signing out, local sync password will be cleared, re-login required.'**
  String get accountLogoutDesc;

  /// No description provided for @accountLogoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Sign Out'**
  String get accountLogoutConfirmTitle;

  /// No description provided for @accountLogoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'After signing out, local sync password will be cleared.'**
  String get accountLogoutConfirmMessage;

  /// No description provided for @accountLogoutButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get accountLogoutButton;

  /// No description provided for @accountEnableSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Cloud Sync'**
  String get accountEnableSyncTitle;

  /// No description provided for @accountEnableSyncMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to verify and enable encrypted sync.'**
  String get accountEnableSyncMessage;

  /// No description provided for @accountPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get accountPasswordLabel;

  /// No description provided for @accountPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get accountPasswordHint;

  /// No description provided for @accountPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter password'**
  String get accountPasswordRequired;

  /// No description provided for @accountEnableSyncButton.
  ///
  /// In en, this message translates to:
  /// **'Enable Now'**
  String get accountEnableSyncButton;

  /// No description provided for @accountSyncEnabledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync enabled'**
  String get accountSyncEnabledSuccess;

  /// No description provided for @accountSyncEnableFailed.
  ///
  /// In en, this message translates to:
  /// **'Password incorrect or enable failed, please try again'**
  String get accountSyncEnableFailed;

  /// No description provided for @accountExpiresAt.
  ///
  /// In en, this message translates to:
  /// **'Expires: {date}'**
  String accountExpiresAt(String date);

  /// No description provided for @accountUsernameNotSet.
  ///
  /// In en, this message translates to:
  /// **'Username not set'**
  String get accountUsernameNotSet;

  /// No description provided for @accountLifetimeRightsTitle.
  ///
  /// In en, this message translates to:
  /// **'BovaPlayer\nLifetime Access'**
  String get accountLifetimeRightsTitle;

  /// No description provided for @accountLifetimeChip.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get accountLifetimeChip;

  /// No description provided for @accountVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get accountVip;

  /// No description provided for @windowMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get windowMinimize;

  /// No description provided for @windowMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get windowMaximize;

  /// No description provided for @windowRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get windowRestore;

  /// No description provided for @windowClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get windowClose;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeCyberpunk.
  ///
  /// In en, this message translates to:
  /// **'Cyberpunk'**
  String get settingsThemeCyberpunk;

  /// No description provided for @settingsThemeCyberpunkPro.
  ///
  /// In en, this message translates to:
  /// **'Cyberpunk Pro'**
  String get settingsThemeCyberpunkPro;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsLanguageZh.
  ///
  /// In en, this message translates to:
  /// **'Chinese (Simplified)'**
  String get settingsLanguageZh;

  /// No description provided for @authLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter email and password, or sign in with GitHub.'**
  String get authLoginSubtitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordHint;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authLoginButton;

  /// No description provided for @authOrThirdParty.
  ///
  /// In en, this message translates to:
  /// **'or sign in with'**
  String get authOrThirdParty;

  /// No description provided for @authGitHubLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in with GitHub'**
  String get authGitHubLogin;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccount;

  /// No description provided for @authRegisterNow.
  ///
  /// In en, this message translates to:
  /// **'Register now'**
  String get authRegisterNow;

  /// No description provided for @authLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful!'**
  String get authLoginSuccess;

  /// No description provided for @authLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get authLoginFailed;

  /// No description provided for @authGitHubLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'GitHub login failed'**
  String get authGitHubLoginFailed;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get authInvalidEmail;

  /// No description provided for @authEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter password'**
  String get authEnterPassword;

  /// No description provided for @authRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterHeading.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authRegisterHeading;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Register to enable media sync, purchase plans, and manage your workspace.'**
  String get authRegisterSubtitle;

  /// No description provided for @authRegisterDesc.
  ///
  /// In en, this message translates to:
  /// **'Fill in basic info to get started. Username can be adjusted later in Account Center.'**
  String get authRegisterDesc;

  /// No description provided for @authRegisterFactSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get authRegisterFactSync;

  /// No description provided for @authRegisterFactSyncValue.
  ///
  /// In en, this message translates to:
  /// **'Available after registration'**
  String get authRegisterFactSyncValue;

  /// No description provided for @authRegisterFactRights.
  ///
  /// In en, this message translates to:
  /// **'Rights management'**
  String get authRegisterFactRights;

  /// No description provided for @authRegisterFactRightsValue.
  ///
  /// In en, this message translates to:
  /// **'Upgrade & redeem supported'**
  String get authRegisterFactRightsValue;

  /// No description provided for @authRegisterFactSecurity.
  ///
  /// In en, this message translates to:
  /// **'Account security'**
  String get authRegisterFactSecurity;

  /// No description provided for @authRegisterFactSecurityValue.
  ///
  /// In en, this message translates to:
  /// **'Email verification'**
  String get authRegisterFactSecurityValue;

  /// No description provided for @authUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get authUsernameLabel;

  /// No description provided for @authUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get authUsernameHint;

  /// No description provided for @authConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPasswordLabel;

  /// No description provided for @authConfirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password again'**
  String get authConfirmPasswordHint;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get authPasswordMinLength;

  /// No description provided for @authPasswordHintRegister.
  ///
  /// In en, this message translates to:
  /// **'At least 8 chars, letters and numbers recommended'**
  String get authPasswordHintRegister;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordMismatch;

  /// No description provided for @authRegisterButton.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authRegisterButton;

  /// No description provided for @authHasAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHasAccount;

  /// No description provided for @authLoginNow.
  ///
  /// In en, this message translates to:
  /// **'Sign in now'**
  String get authLoginNow;

  /// No description provided for @authRegisterSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration successful! Please check your email for verification.'**
  String get authRegisterSuccess;

  /// No description provided for @authRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get authRegisterFailed;

  /// No description provided for @authRegisterTooFrequent.
  ///
  /// In en, this message translates to:
  /// **'Too many requests, please wait 45 seconds'**
  String get authRegisterTooFrequent;

  /// No description provided for @authRegisterDbError.
  ///
  /// In en, this message translates to:
  /// **'Database configuration error, contact admin'**
  String get authRegisterDbError;

  /// No description provided for @authRegisterEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered'**
  String get authRegisterEmailTaken;

  /// No description provided for @authForgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get authForgotTitle;

  /// No description provided for @authForgotCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authForgotCheckEmail;

  /// No description provided for @authForgotSubtitleSent.
  ///
  /// In en, this message translates to:
  /// **'Email has been sent. Complete password reset from your inbox, then log in again.'**
  String get authForgotSubtitleSent;

  /// No description provided for @authForgotSubtitleForm.
  ///
  /// In en, this message translates to:
  /// **'Enter your registration email and we will send a reset link.'**
  String get authForgotSubtitleForm;

  /// No description provided for @authForgotFactEmailStatus.
  ///
  /// In en, this message translates to:
  /// **'Email status'**
  String get authForgotFactEmailStatus;

  /// No description provided for @authForgotFactEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get authForgotFactEmailSent;

  /// No description provided for @authForgotFactNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get authForgotFactNextStep;

  /// No description provided for @authForgotFactNextStepValue.
  ///
  /// In en, this message translates to:
  /// **'Check inbox & click link'**
  String get authForgotFactNextStepValue;

  /// No description provided for @authForgotFactEmailVerify.
  ///
  /// In en, this message translates to:
  /// **'Email verification'**
  String get authForgotFactEmailVerify;

  /// No description provided for @authForgotFactRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get authForgotFactRequired;

  /// No description provided for @authForgotFactResetMethod.
  ///
  /// In en, this message translates to:
  /// **'Reset method'**
  String get authForgotFactResetMethod;

  /// No description provided for @authForgotFactResetViaEmail.
  ///
  /// In en, this message translates to:
  /// **'Email link'**
  String get authForgotFactResetViaEmail;

  /// No description provided for @authForgotSendLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get authForgotSendLink;

  /// No description provided for @authForgotFormDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter your registration email, we will send a password reset link.'**
  String get authForgotFormDesc;

  /// No description provided for @authForgotRemembered.
  ///
  /// In en, this message translates to:
  /// **'Remember your password?'**
  String get authForgotRemembered;

  /// No description provided for @authForgotBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get authForgotBackToLogin;

  /// No description provided for @authForgotEmailSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Email Sent'**
  String get authForgotEmailSentTitle;

  /// No description provided for @authForgotEmailSentDesc.
  ///
  /// In en, this message translates to:
  /// **'We have sent a password reset link to {email}. Please check your inbox.'**
  String authForgotEmailSentDesc(String email);

  /// No description provided for @authForgotReturnLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get authForgotReturnLogin;

  /// No description provided for @authForgotResend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get authForgotResend;

  /// No description provided for @authForgotSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed'**
  String get authForgotSendFailed;

  /// No description provided for @authRedeemFailed.
  ///
  /// In en, this message translates to:
  /// **'Redemption failed: {error}'**
  String authRedeemFailed(String error);

  /// No description provided for @authGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation failed: {error}'**
  String authGenerateFailed(String error);

  /// No description provided for @authQueryFailed.
  ///
  /// In en, this message translates to:
  /// **'Query failed: {error}'**
  String authQueryFailed(String error);

  /// No description provided for @pricingTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership Plans'**
  String get pricingTitle;

  /// No description provided for @pricingChoosePlan.
  ///
  /// In en, this message translates to:
  /// **'Choose the right plan for you'**
  String get pricingChoosePlan;

  /// No description provided for @pricingHeroDesc.
  ///
  /// In en, this message translates to:
  /// **'Account, benefits and upgrade flow are unified in one workspace. You can upgrade directly or enter a redemption code first.'**
  String get pricingHeroDesc;

  /// No description provided for @pricingCrossDeviceSync.
  ///
  /// In en, this message translates to:
  /// **'Cross-device sync'**
  String get pricingCrossDeviceSync;

  /// No description provided for @pricingDeviceQuota.
  ///
  /// In en, this message translates to:
  /// **'Device quota'**
  String get pricingDeviceQuota;

  /// No description provided for @pricingCloudStorage.
  ///
  /// In en, this message translates to:
  /// **'Cloud storage'**
  String get pricingCloudStorage;

  /// No description provided for @pricingPlanFree.
  ///
  /// In en, this message translates to:
  /// **'Community Free'**
  String get pricingPlanFree;

  /// No description provided for @pricingPlanFreePrice.
  ///
  /// In en, this message translates to:
  /// **'¥0'**
  String get pricingPlanFreePrice;

  /// No description provided for @pricingPlanFreePeriod.
  ///
  /// In en, this message translates to:
  /// **'Free forever'**
  String get pricingPlanFreePeriod;

  /// No description provided for @pricingPlanFreeDesc.
  ///
  /// In en, this message translates to:
  /// **'Ideal for lightweight use and local playback, retaining the most basic core capabilities.'**
  String get pricingPlanFreeDesc;

  /// No description provided for @pricingPlanFreeCta.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get pricingPlanFreeCta;

  /// No description provided for @pricingPlanFreeFeature1.
  ///
  /// In en, this message translates to:
  /// **'Up to 10 servers'**
  String get pricingPlanFreeFeature1;

  /// No description provided for @pricingPlanFreeFeature2.
  ///
  /// In en, this message translates to:
  /// **'Up to 2 devices'**
  String get pricingPlanFreeFeature2;

  /// No description provided for @pricingPlanFreeFeature3.
  ///
  /// In en, this message translates to:
  /// **'100 MB cloud storage'**
  String get pricingPlanFreeFeature3;

  /// No description provided for @pricingPlanFreeFeature4.
  ///
  /// In en, this message translates to:
  /// **'Basic playback'**
  String get pricingPlanFreeFeature4;

  /// No description provided for @pricingPlanFreeFeature5.
  ///
  /// In en, this message translates to:
  /// **'Community support'**
  String get pricingPlanFreeFeature5;

  /// No description provided for @pricingPlanPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get pricingPlanPro;

  /// No description provided for @pricingPlanProPrice.
  ///
  /// In en, this message translates to:
  /// **'¥6.9'**
  String get pricingPlanProPrice;

  /// No description provided for @pricingPlanProPeriod.
  ///
  /// In en, this message translates to:
  /// **'/ month'**
  String get pricingPlanProPeriod;

  /// No description provided for @pricingPlanProDesc.
  ///
  /// In en, this message translates to:
  /// **'The go-to plan for multi-device, multi-library and cross-device sync.'**
  String get pricingPlanProDesc;

  /// No description provided for @pricingPlanProCta.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get pricingPlanProCta;

  /// No description provided for @pricingPlanProFeature1.
  ///
  /// In en, this message translates to:
  /// **'Unlimited servers'**
  String get pricingPlanProFeature1;

  /// No description provided for @pricingPlanProFeature2.
  ///
  /// In en, this message translates to:
  /// **'Up to 5 devices'**
  String get pricingPlanProFeature2;

  /// No description provided for @pricingPlanProFeature3.
  ///
  /// In en, this message translates to:
  /// **'1 GB cloud storage'**
  String get pricingPlanProFeature3;

  /// No description provided for @pricingPlanProFeature4.
  ///
  /// In en, this message translates to:
  /// **'Advanced playback'**
  String get pricingPlanProFeature4;

  /// No description provided for @pricingPlanProFeature5.
  ///
  /// In en, this message translates to:
  /// **'Priority support'**
  String get pricingPlanProFeature5;

  /// No description provided for @pricingPlanProFeature6.
  ///
  /// In en, this message translates to:
  /// **'GitHub sync'**
  String get pricingPlanProFeature6;

  /// No description provided for @pricingPlanLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get pricingPlanLifetime;

  /// No description provided for @pricingPlanLifetimePrice.
  ///
  /// In en, this message translates to:
  /// **'¥69'**
  String get pricingPlanLifetimePrice;

  /// No description provided for @pricingPlanLifetimePeriod.
  ///
  /// In en, this message translates to:
  /// **'One-time payment'**
  String get pricingPlanLifetimePeriod;

  /// No description provided for @pricingPlanLifetimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Buy once, unlock premium sync, full quota and future updates permanently.'**
  String get pricingPlanLifetimeDesc;

  /// No description provided for @pricingPlanLifetimeCta.
  ///
  /// In en, this message translates to:
  /// **'Unlock Lifetime'**
  String get pricingPlanLifetimeCta;

  /// No description provided for @pricingPlanLifetimeFeature1.
  ///
  /// In en, this message translates to:
  /// **'Unlimited servers'**
  String get pricingPlanLifetimeFeature1;

  /// No description provided for @pricingPlanLifetimeFeature2.
  ///
  /// In en, this message translates to:
  /// **'Unlimited devices'**
  String get pricingPlanLifetimeFeature2;

  /// No description provided for @pricingPlanLifetimeFeature3.
  ///
  /// In en, this message translates to:
  /// **'5 GB cloud storage'**
  String get pricingPlanLifetimeFeature3;

  /// No description provided for @pricingPlanLifetimeFeature4.
  ///
  /// In en, this message translates to:
  /// **'All premium features'**
  String get pricingPlanLifetimeFeature4;

  /// No description provided for @pricingPlanLifetimeFeature5.
  ///
  /// In en, this message translates to:
  /// **'Lifetime updates'**
  String get pricingPlanLifetimeFeature5;

  /// No description provided for @pricingPlanLifetimeFeature6.
  ///
  /// In en, this message translates to:
  /// **'Priority support'**
  String get pricingPlanLifetimeFeature6;

  /// No description provided for @pricingPlanLifetimeFeature7.
  ///
  /// In en, this message translates to:
  /// **'GitHub sync'**
  String get pricingPlanLifetimeFeature7;

  /// No description provided for @pricingRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get pricingRecommended;

  /// No description provided for @pricingCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get pricingCurrentPlan;

  /// No description provided for @pricingFeatureComparison.
  ///
  /// In en, this message translates to:
  /// **'Feature Comparison'**
  String get pricingFeatureComparison;

  /// No description provided for @pricingFeatureComparisonDesc.
  ///
  /// In en, this message translates to:
  /// **'Quickly compare core capabilities of each plan in one table.'**
  String get pricingFeatureComparisonDesc;

  /// No description provided for @pricingServerCount.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get pricingServerCount;

  /// No description provided for @pricingDeviceCount.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get pricingDeviceCount;

  /// No description provided for @pricingGitHubSync.
  ///
  /// In en, this message translates to:
  /// **'GitHub Sync'**
  String get pricingGitHubSync;

  /// No description provided for @pricingPrioritySupport.
  ///
  /// In en, this message translates to:
  /// **'Priority Support'**
  String get pricingPrioritySupport;

  /// No description provided for @pricingLifetimeUpdates.
  ///
  /// In en, this message translates to:
  /// **'Lifetime Updates'**
  String get pricingLifetimeUpdates;

  /// No description provided for @pricingSupported.
  ///
  /// In en, this message translates to:
  /// **'Supported'**
  String get pricingSupported;

  /// No description provided for @pricingUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not included'**
  String get pricingUnsupported;

  /// No description provided for @pricingPeriodYear.
  ///
  /// In en, this message translates to:
  /// **'/ year'**
  String get pricingPeriodYear;

  /// No description provided for @pricingBadgeMostPopular.
  ///
  /// In en, this message translates to:
  /// **'Most Popular'**
  String get pricingBadgeMostPopular;

  /// No description provided for @pricingBadgeBestForTeams.
  ///
  /// In en, this message translates to:
  /// **'Best for Teams'**
  String get pricingBadgeBestForTeams;

  /// No description provided for @pricingBadgeBestValue.
  ///
  /// In en, this message translates to:
  /// **'Best Value'**
  String get pricingBadgeBestValue;

  /// No description provided for @pricingWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Membership Workspace'**
  String get pricingWorkspace;

  /// No description provided for @pricingIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get pricingIncluded;

  /// No description provided for @pricingLoadConfigsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load pricing configs: {error}'**
  String pricingLoadConfigsFailed(String error);

  /// No description provided for @pricingProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get pricingProcessing;

  /// No description provided for @pricingWaitingForConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment confirmation...'**
  String get pricingWaitingForConfirmation;

  /// No description provided for @pricingPaymentSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment successful'**
  String get pricingPaymentSuccessTitle;

  /// No description provided for @pricingPaymentSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your subscription benefits have been refreshed. You can now view the latest membership status in Account Center.'**
  String get pricingPaymentSuccessMessage;

  /// No description provided for @pricingViewAccount.
  ///
  /// In en, this message translates to:
  /// **'View Account'**
  String get pricingViewAccount;

  /// No description provided for @pricingPaymentPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment result not confirmed yet'**
  String get pricingPaymentPendingTitle;

  /// No description provided for @pricingPaymentPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'The payment result has not finished syncing. You can check your subscription status later in Account Center. If payment was completed, it usually takes effect shortly.'**
  String get pricingPaymentPendingMessage;

  /// No description provided for @pricingPaymentFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get pricingPaymentFailedTitle;

  /// No description provided for @pricingPaymentFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment was not completed. Please try again later.'**
  String get pricingPaymentFailedMessage;

  /// No description provided for @pricingReopenPayment.
  ///
  /// In en, this message translates to:
  /// **'Reopen payment page'**
  String get pricingReopenPayment;

  /// No description provided for @pricingPaymentCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled'**
  String get pricingPaymentCancelledTitle;

  /// No description provided for @pricingPaymentCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'You cancelled this payment. Reopen the payment page if you want to continue.'**
  String get pricingPaymentCancelledMessage;

  /// No description provided for @pricingPaymentExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment expired'**
  String get pricingPaymentExpiredTitle;

  /// No description provided for @pricingPaymentExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'The current order has expired. Please create a new order.'**
  String get pricingPaymentExpiredMessage;

  /// No description provided for @pricingAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get pricingAcknowledge;

  /// No description provided for @pricingPaymentFlowFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment flow failed'**
  String get pricingPaymentFlowFailedTitle;

  /// No description provided for @pricingPaymentFlowFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'An exception occurred while creating the order or checking payment status: {error}'**
  String pricingPaymentFlowFailedMessage(String error);

  /// No description provided for @pricingClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get pricingClose;

  /// No description provided for @pricingCheckoutUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment page unavailable'**
  String get pricingCheckoutUnavailableTitle;

  /// No description provided for @pricingCheckoutUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'The order did not return a valid payment link.'**
  String get pricingCheckoutUnavailableMessage;

  /// No description provided for @pricingCheckoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete payment'**
  String get pricingCheckoutTitle;

  /// No description provided for @pricingCheckoutInstruction.
  ///
  /// In en, this message translates to:
  /// **'Please complete payment inside the app, then tap \"I have completed payment\" below.'**
  String get pricingCheckoutInstruction;

  /// No description provided for @pricingOrderId.
  ///
  /// In en, this message translates to:
  /// **'Order ID: {id}'**
  String pricingOrderId(String id);

  /// No description provided for @pricingAmountValue.
  ///
  /// In en, this message translates to:
  /// **'Amount: ¥{amount}'**
  String pricingAmountValue(String amount);

  /// No description provided for @pricingExpiresAtValue.
  ///
  /// In en, this message translates to:
  /// **'Valid until: {date}'**
  String pricingExpiresAtValue(String date);

  /// No description provided for @pricingPaymentCompleted.
  ///
  /// In en, this message translates to:
  /// **'I have completed payment'**
  String get pricingPaymentCompleted;

  /// No description provided for @pricingStarter.
  ///
  /// In en, this message translates to:
  /// **'Starter'**
  String get pricingStarter;

  /// No description provided for @pricingAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Pricing Management'**
  String get pricingAdminTitle;

  /// No description provided for @pricingAdminRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh pricing configs'**
  String get pricingAdminRefreshTooltip;

  /// No description provided for @pricingAdminWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Pricing Workspace'**
  String get pricingAdminWorkspace;

  /// No description provided for @pricingAdminHeadline.
  ///
  /// In en, this message translates to:
  /// **'Manage plan pricing from the database'**
  String get pricingAdminHeadline;

  /// No description provided for @pricingAdminDescription.
  ///
  /// In en, this message translates to:
  /// **'Changes here become the single source of truth for storefront pricing and backend order creation. You can review inactive plans, adjust quotas, and update payment copy.'**
  String get pricingAdminDescription;

  /// No description provided for @pricingAdminStatTotalPlans.
  ///
  /// In en, this message translates to:
  /// **'Total plans'**
  String get pricingAdminStatTotalPlans;

  /// No description provided for @pricingAdminStatActivePlans.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get pricingAdminStatActivePlans;

  /// No description provided for @pricingAdminStatHighestPrice.
  ///
  /// In en, this message translates to:
  /// **'Highest price'**
  String get pricingAdminStatHighestPrice;

  /// No description provided for @pricingAdminFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get pricingAdminFilterAll;

  /// No description provided for @pricingAdminFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get pricingAdminFilterActive;

  /// No description provided for @pricingAdminFilterInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get pricingAdminFilterInactive;

  /// No description provided for @pricingAdminEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No pricing configs to display'**
  String get pricingAdminEmptyTitle;

  /// No description provided for @pricingAdminEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Make sure pricing_configs has been initialized in the database.'**
  String get pricingAdminEmptyHint;

  /// No description provided for @pricingAdminStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get pricingAdminStatusActive;

  /// No description provided for @pricingAdminStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get pricingAdminStatusInactive;

  /// No description provided for @pricingAdminEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get pricingAdminEdit;

  /// No description provided for @pricingAdminPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get pricingAdminPriceLabel;

  /// No description provided for @pricingAdminPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get pricingAdminPeriodLabel;

  /// No description provided for @pricingAdminServersLabel.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get pricingAdminServersLabel;

  /// No description provided for @pricingAdminDevicesLabel.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get pricingAdminDevicesLabel;

  /// No description provided for @pricingAdminStorageLabel.
  ///
  /// In en, this message translates to:
  /// **'Cloud storage'**
  String get pricingAdminStorageLabel;

  /// No description provided for @pricingAdminSortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort order'**
  String get pricingAdminSortLabel;

  /// No description provided for @pricingAdminPaymentCopyTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment copy'**
  String get pricingAdminPaymentCopyTitle;

  /// No description provided for @pricingAdminPaymentSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject: {value}'**
  String pricingAdminPaymentSubject(String value);

  /// No description provided for @pricingAdminPaymentBody.
  ///
  /// In en, this message translates to:
  /// **'Body: {value}'**
  String pricingAdminPaymentBody(String value);

  /// No description provided for @pricingAdminLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load pricing configs: {error}'**
  String pricingAdminLoadFailed(String error);

  /// No description provided for @pricingAdminUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Updated {name}'**
  String pricingAdminUpdateSuccess(String name);

  /// No description provided for @pricingAdminUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update pricing config: {error}'**
  String pricingAdminUpdateFailed(String error);

  /// No description provided for @pricingAdminPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get pricingAdminPeriodMonth;

  /// No description provided for @pricingAdminPeriodYear.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get pricingAdminPeriodYear;

  /// No description provided for @pricingAdminPeriodOneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time'**
  String get pricingAdminPeriodOneTime;

  /// No description provided for @pricingAdminEditPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit plan: {planId}'**
  String pricingAdminEditPlanTitle(String planId);

  /// No description provided for @pricingAdminFieldDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get pricingAdminFieldDisplayName;

  /// No description provided for @pricingAdminFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get pricingAdminFieldDescription;

  /// No description provided for @pricingAdminFieldPriceCny.
  ///
  /// In en, this message translates to:
  /// **'Price (CNY)'**
  String get pricingAdminFieldPriceCny;

  /// No description provided for @pricingAdminFieldBillingPeriod.
  ///
  /// In en, this message translates to:
  /// **'Billing period'**
  String get pricingAdminFieldBillingPeriod;

  /// No description provided for @pricingAdminFieldAccountType.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get pricingAdminFieldAccountType;

  /// No description provided for @pricingAdminFieldSubscriptionType.
  ///
  /// In en, this message translates to:
  /// **'Subscription type'**
  String get pricingAdminFieldSubscriptionType;

  /// No description provided for @pricingAdminFieldDurationDaysOptional.
  ///
  /// In en, this message translates to:
  /// **'Duration (days, optional)'**
  String get pricingAdminFieldDurationDaysOptional;

  /// No description provided for @pricingAdminFieldMaxServers.
  ///
  /// In en, this message translates to:
  /// **'Max servers'**
  String get pricingAdminFieldMaxServers;

  /// No description provided for @pricingAdminFieldMaxDevices.
  ///
  /// In en, this message translates to:
  /// **'Max devices'**
  String get pricingAdminFieldMaxDevices;

  /// No description provided for @pricingAdminFieldStorageQuotaMb.
  ///
  /// In en, this message translates to:
  /// **'Cloud storage quota (MB)'**
  String get pricingAdminFieldStorageQuotaMb;

  /// No description provided for @pricingAdminFieldSortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort order'**
  String get pricingAdminFieldSortOrder;

  /// No description provided for @pricingAdminFieldPaymentSubject.
  ///
  /// In en, this message translates to:
  /// **'Payment subject'**
  String get pricingAdminFieldPaymentSubject;

  /// No description provided for @pricingAdminFieldPaymentBody.
  ///
  /// In en, this message translates to:
  /// **'Payment body'**
  String get pricingAdminFieldPaymentBody;

  /// No description provided for @pricingAdminInvalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid price'**
  String get pricingAdminInvalidPrice;

  /// No description provided for @pricingAdminInvalidInteger.
  ///
  /// In en, this message translates to:
  /// **'Please enter an integer'**
  String get pricingAdminInvalidInteger;

  /// No description provided for @pricingAdminInvalidNonNegativeInteger.
  ///
  /// In en, this message translates to:
  /// **'Please enter a non-negative integer'**
  String get pricingAdminInvalidNonNegativeInteger;

  /// No description provided for @pricingAdminRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get pricingAdminRequired;

  /// No description provided for @pricingAdminEnablePlan.
  ///
  /// In en, this message translates to:
  /// **'Enable this plan'**
  String get pricingAdminEnablePlan;

  /// No description provided for @pricingAdminEnablePlanHint.
  ///
  /// In en, this message translates to:
  /// **'Disabled plans will not be shown on the purchase page, but they remain visible here.'**
  String get pricingAdminEnablePlanHint;

  /// No description provided for @pricingUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get pricingUnlimited;

  /// No description provided for @pricingFaq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get pricingFaq;

  /// No description provided for @pricingFaqDesc.
  ///
  /// In en, this message translates to:
  /// **'Most frequently asked questions before purchasing or redeeming.'**
  String get pricingFaqDesc;

  /// No description provided for @pricingFaqQ1.
  ///
  /// In en, this message translates to:
  /// **'How soon does it take effect after purchase?'**
  String get pricingFaqQ1;

  /// No description provided for @pricingFaqA1.
  ///
  /// In en, this message translates to:
  /// **'Account benefits update immediately after payment or redemption. Re-enter the account page to see the latest status.'**
  String get pricingFaqA1;

  /// No description provided for @pricingFaqQ2.
  ///
  /// In en, this message translates to:
  /// **'Can I enter a redemption code first?'**
  String get pricingFaqQ2;

  /// No description provided for @pricingFaqA2.
  ///
  /// In en, this message translates to:
  /// **'Yes. Enter the code directly in the purchase confirmation popup, and the system will try to redeem it first.'**
  String get pricingFaqA2;

  /// No description provided for @pricingFaqQ3.
  ///
  /// In en, this message translates to:
  /// **'What\'s the difference between Pro and Lifetime?'**
  String get pricingFaqQ3;

  /// No description provided for @pricingFaqA3.
  ///
  /// In en, this message translates to:
  /// **'Pro is better for monthly subscription and continuous use; Lifetime is better for long-term power users with one-time unlock.'**
  String get pricingFaqA3;

  /// No description provided for @pricingConfirmPurchase.
  ///
  /// In en, this message translates to:
  /// **'Confirm Purchase'**
  String get pricingConfirmPurchase;

  /// No description provided for @pricingHaveRedemptionCode.
  ///
  /// In en, this message translates to:
  /// **'Have a redemption code?'**
  String get pricingHaveRedemptionCode;

  /// No description provided for @pricingRedemptionCode.
  ///
  /// In en, this message translates to:
  /// **'Redemption Code'**
  String get pricingRedemptionCode;

  /// No description provided for @pricingRedeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get pricingRedeem;

  /// No description provided for @pricingGoPay.
  ///
  /// In en, this message translates to:
  /// **'Go Pay'**
  String get pricingGoPay;

  /// No description provided for @pricingProMonthly.
  ///
  /// In en, this message translates to:
  /// **'Pro (Monthly)'**
  String get pricingProMonthly;

  /// No description provided for @pricingProMonthlyPrice.
  ///
  /// In en, this message translates to:
  /// **'¥6.9 / month'**
  String get pricingProMonthlyPrice;

  /// No description provided for @pricingLifetimeOnce.
  ///
  /// In en, this message translates to:
  /// **'¥69 (one-time)'**
  String get pricingLifetimeOnce;

  /// No description provided for @pricingRedeemSuccess.
  ///
  /// In en, this message translates to:
  /// **'Redeemed Successfully'**
  String get pricingRedeemSuccess;

  /// No description provided for @pricingAccountUpdated.
  ///
  /// In en, this message translates to:
  /// **'Account benefits have been updated.'**
  String get pricingAccountUpdated;

  /// No description provided for @pricingOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get pricingOk;

  /// No description provided for @pricingRedeemFailed.
  ///
  /// In en, this message translates to:
  /// **'Redemption failed'**
  String get pricingRedeemFailed;

  /// No description provided for @pricingRedeemError.
  ///
  /// In en, this message translates to:
  /// **'Redemption failed: {error}'**
  String pricingRedeemError(String error);

  /// No description provided for @danmakuSettings.
  ///
  /// In en, this message translates to:
  /// **'Danmaku Settings'**
  String get danmakuSettings;

  /// No description provided for @danmakuShowDanmaku.
  ///
  /// In en, this message translates to:
  /// **'Show Danmaku'**
  String get danmakuShowDanmaku;

  /// No description provided for @danmakuOpacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get danmakuOpacity;

  /// No description provided for @danmakuFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get danmakuFontSize;

  /// No description provided for @danmakuSpeed.
  ///
  /// In en, this message translates to:
  /// **'Danmaku Speed'**
  String get danmakuSpeed;

  /// No description provided for @danmakuDisplayArea.
  ///
  /// In en, this message translates to:
  /// **'Display Area'**
  String get danmakuDisplayArea;

  /// No description provided for @danmakuFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get danmakuFullScreen;

  /// No description provided for @danmakuThreeQuarters.
  ///
  /// In en, this message translates to:
  /// **'3/4 screen'**
  String get danmakuThreeQuarters;

  /// No description provided for @danmakuHalfScreen.
  ///
  /// In en, this message translates to:
  /// **'Half screen'**
  String get danmakuHalfScreen;

  /// No description provided for @danmakuQuarterScreen.
  ///
  /// In en, this message translates to:
  /// **'1/4 screen'**
  String get danmakuQuarterScreen;

  /// No description provided for @danmakuUnknownVideo.
  ///
  /// In en, this message translates to:
  /// **'Unknown video'**
  String get danmakuUnknownVideo;

  /// No description provided for @danmakuCount.
  ///
  /// In en, this message translates to:
  /// **'{count} danmaku total'**
  String danmakuCount(int count);

  /// No description provided for @danmakuUpgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get danmakuUpgradeToPro;

  /// No description provided for @danmakuUpgradeDesc.
  ///
  /// In en, this message translates to:
  /// **'Danmaku feature is only available for Pro and Lifetime users.\n\nAfter upgrading:\n• Real-time danmaku display\n• Custom danmaku settings\n• Cloud sync\n• More advanced features'**
  String get danmakuUpgradeDesc;

  /// No description provided for @danmakuViewPlans.
  ///
  /// In en, this message translates to:
  /// **'View Plans'**
  String get danmakuViewPlans;

  /// No description provided for @danmakuUpgradeUnlock.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro to unlock danmaku'**
  String get danmakuUpgradeUnlock;

  /// No description provided for @danmakuUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get danmakuUpgrade;

  /// No description provided for @netBrowserTitle.
  ///
  /// In en, this message translates to:
  /// **'Network Browser'**
  String get netBrowserTitle;

  /// No description provided for @netBrowserLoadConnectionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load connections: {error}'**
  String netBrowserLoadConnectionsFailed(String error);

  /// No description provided for @netBrowserConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get netBrowserConnectionFailed;

  /// No description provided for @netBrowserConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String netBrowserConnectionError(String error);

  /// No description provided for @netBrowserLoadDirFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load directory: {error}'**
  String netBrowserLoadDirFailed(String error);

  /// No description provided for @netBrowserPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed: {error}'**
  String netBrowserPlayFailed(String error);

  /// No description provided for @netBrowserNoConnections.
  ///
  /// In en, this message translates to:
  /// **'No connections yet\nTap + at bottom right to add'**
  String get netBrowserNoConnections;

  /// No description provided for @netBrowserDirEmpty.
  ///
  /// In en, this message translates to:
  /// **'Directory is empty'**
  String get netBrowserDirEmpty;

  /// No description provided for @netBrowserRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get netBrowserRetry;

  /// No description provided for @netBrowserAddConnection.
  ///
  /// In en, this message translates to:
  /// **'Add Connection'**
  String get netBrowserAddConnection;

  /// No description provided for @netBrowserProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get netBrowserProtocol;

  /// No description provided for @netBrowserName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get netBrowserName;

  /// No description provided for @netBrowserHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get netBrowserHost;

  /// No description provided for @netBrowserPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get netBrowserPort;

  /// No description provided for @netBrowserUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get netBrowserUsername;

  /// No description provided for @netBrowserPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get netBrowserPassword;

  /// No description provided for @netBrowserShareName.
  ///
  /// In en, this message translates to:
  /// **'Share Name'**
  String get netBrowserShareName;

  /// No description provided for @netBrowserShareHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. share, movies'**
  String get netBrowserShareHint;

  /// No description provided for @netBrowserWorkgroup.
  ///
  /// In en, this message translates to:
  /// **'Workgroup'**
  String get netBrowserWorkgroup;

  /// No description provided for @netBrowserWorkgroupHint.
  ///
  /// In en, this message translates to:
  /// **'Default: WORKGROUP'**
  String get netBrowserWorkgroupHint;

  /// No description provided for @netBrowserSavePassword.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get netBrowserSavePassword;

  /// No description provided for @netBrowserEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter name'**
  String get netBrowserEnterName;

  /// No description provided for @netBrowserEnterHost.
  ///
  /// In en, this message translates to:
  /// **'Please enter host'**
  String get netBrowserEnterHost;

  /// No description provided for @netBrowserEnterPort.
  ///
  /// In en, this message translates to:
  /// **'Please enter port'**
  String get netBrowserEnterPort;

  /// No description provided for @netBrowserEnterShareName.
  ///
  /// In en, this message translates to:
  /// **'Please enter share name'**
  String get netBrowserEnterShareName;

  /// No description provided for @redemptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Redemption Code Management'**
  String get redemptionTitle;

  /// No description provided for @redemptionHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Redemption Codes'**
  String get redemptionHeroTitle;

  /// No description provided for @redemptionHeroDesc.
  ///
  /// In en, this message translates to:
  /// **'Unified view of code status, type, expiry and generation entry. Consistent with account workspace style.'**
  String get redemptionHeroDesc;

  /// No description provided for @redemptionGenerateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Generate code'**
  String get redemptionGenerateTooltip;

  /// No description provided for @redemptionFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get redemptionFilterAll;

  /// No description provided for @redemptionFilterUnused.
  ///
  /// In en, this message translates to:
  /// **'Unused'**
  String get redemptionFilterUnused;

  /// No description provided for @redemptionFilterUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get redemptionFilterUsed;

  /// No description provided for @redemptionFilterExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get redemptionFilterExpired;

  /// No description provided for @redemptionLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get redemptionLoadFailed;

  /// No description provided for @redemptionLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String redemptionLoadError(String error);

  /// No description provided for @redemptionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No redemption codes'**
  String get redemptionEmpty;

  /// No description provided for @redemptionEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the plus icon at top right to generate new codes.'**
  String get redemptionEmptyHint;

  /// No description provided for @redemptionStatusUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get redemptionStatusUsed;

  /// No description provided for @redemptionStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get redemptionStatusExpired;

  /// No description provided for @redemptionStatusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get redemptionStatusAvailable;

  /// No description provided for @redemptionTypePro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get redemptionTypePro;

  /// No description provided for @redemptionTypeLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get redemptionTypeLifetime;

  /// No description provided for @redemptionCopyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get redemptionCopyTooltip;

  /// No description provided for @redemptionCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied code'**
  String get redemptionCopied;

  /// No description provided for @redemptionCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created at'**
  String get redemptionCreatedAt;

  /// No description provided for @redemptionExpiresAt.
  ///
  /// In en, this message translates to:
  /// **'Expires at'**
  String get redemptionExpiresAt;

  /// No description provided for @redemptionUsedBy.
  ///
  /// In en, this message translates to:
  /// **'Used by'**
  String get redemptionUsedBy;

  /// No description provided for @redemptionUsedAt.
  ///
  /// In en, this message translates to:
  /// **'Used at'**
  String get redemptionUsedAt;

  /// No description provided for @redemptionGenerateTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate Codes'**
  String get redemptionGenerateTitle;

  /// No description provided for @redemptionGenerateDesc.
  ///
  /// In en, this message translates to:
  /// **'Select benefit type and fill in quantity, validity days and notes.'**
  String get redemptionGenerateDesc;

  /// No description provided for @redemptionGenerateCount.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get redemptionGenerateCount;

  /// No description provided for @redemptionGenerateCountHint.
  ///
  /// In en, this message translates to:
  /// **'1-100'**
  String get redemptionGenerateCountHint;

  /// No description provided for @redemptionProDuration.
  ///
  /// In en, this message translates to:
  /// **'Pro validity days'**
  String get redemptionProDuration;

  /// No description provided for @redemptionProDurationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 30, 90, 365'**
  String get redemptionProDurationHint;

  /// No description provided for @redemptionCodeExpiry.
  ///
  /// In en, this message translates to:
  /// **'Code expiry days'**
  String get redemptionCodeExpiry;

  /// No description provided for @redemptionCodeExpiryHint.
  ///
  /// In en, this message translates to:
  /// **'Valid for how many days after generation'**
  String get redemptionCodeExpiryHint;

  /// No description provided for @redemptionNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get redemptionNote;

  /// No description provided for @redemptionNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. For event users'**
  String get redemptionNoteHint;

  /// No description provided for @redemptionGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get redemptionGenerate;

  /// No description provided for @redemptionGenerateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully generated {count} codes'**
  String redemptionGenerateSuccess(int count);

  /// No description provided for @redemptionCopiedCode.
  ///
  /// In en, this message translates to:
  /// **'Copied: {code}'**
  String redemptionCopiedCode(String code);

  /// No description provided for @redemptionGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation failed'**
  String get redemptionGenerateFailed;

  /// No description provided for @redemptionGenerateError.
  ///
  /// In en, this message translates to:
  /// **'Generation failed: {error}'**
  String redemptionGenerateError(String error);
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
      'S.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
