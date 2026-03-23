// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class SZh extends S {
  SZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'BovaPlayer';

  @override
  String get discoverTrendingNow => '今日热门';

  @override
  String get discoverTrendingNowSub => '今天最受关注的影视作品';

  @override
  String get discoverPopularMovies => '热门电影';

  @override
  String get discoverPopularMoviesSub => '广受欢迎的大银幕之选';

  @override
  String get discoverPopularTV => '热门剧集';

  @override
  String get discoverPopularTVSub => '观众反复追看的剧集';

  @override
  String get discoverTrendingMovies => '电影趋势';

  @override
  String get discoverTrendingMoviesSub => '今日最火电影动态';

  @override
  String get discoverNowPlaying => '正在热映';

  @override
  String get discoverNowPlayingSub => '全球院线同步上映中';

  @override
  String get discoverMovies => '发现电影';

  @override
  String get discoverMoviesSub => '来自 TMDB Discover 的高人气影片';

  @override
  String get discoverTrendingShows => '剧集趋势';

  @override
  String get discoverTrendingShowsSub => '当下飙升最快的剧集';

  @override
  String get discoverPopularTVShows => '热门剧集';

  @override
  String get discoverPopularTVShowsSub => '来自 TMDB 的热门电视推荐';

  @override
  String get discoverTV => '发现剧集';

  @override
  String get discoverTVSub => '按热度涌现的新鲜剧集';

  @override
  String get playerLoading => '加载中...';

  @override
  String playerFilePickError(String error) {
    return '文件选择失败: $error';
  }

  @override
  String playerPlayFailed(String error) {
    return '播放失败: $error';
  }

  @override
  String get playerRetry => '重试';

  @override
  String get playerNoVideo => '还没有选择视频';

  @override
  String get playerNoVideoHint => '点击右上角文件夹图标选择视频';

  @override
  String get playerSelectFile => '选择视频文件';

  @override
  String get navHome => '首页';

  @override
  String get navMovies => '电影';

  @override
  String get navShows => '剧集';

  @override
  String get navPlayer => '播放器';

  @override
  String get navMediaLibrary => '媒体库';

  @override
  String get navAccount => '账号';

  @override
  String get mobileNavDiscover => '发现';

  @override
  String get mobileNavPlayer => '播放';

  @override
  String get mobileNavLibrary => '媒体库';

  @override
  String get sidebarCollapse => '收起';

  @override
  String get sidebarExpand => '展开';

  @override
  String get sidebarSignOut => '退出登录';

  @override
  String profileGreeting(String name) {
    return '你好, $name';
  }

  @override
  String get profileGuest => '访客';

  @override
  String get profileDiscovering => '正在探索';

  @override
  String get profileWatching => '正在观看';

  @override
  String get profileBrowsing => '正在浏览';

  @override
  String get profileManagingAccount => '管理账号';

  @override
  String get actionSearch => '搜索';

  @override
  String get actionBookmarks => '书签';

  @override
  String get actionNotifications => '通知';

  @override
  String get actionRefreshSync => '刷新并同步';

  @override
  String get actionSearchMedia => '搜索媒体';

  @override
  String get actionBack => '返回';

  @override
  String get exitAppTitle => '退出应用';

  @override
  String get exitAppMessage => '确定要退出 BovaPlayer 吗？';

  @override
  String get cancel => '取消';

  @override
  String get exit => '退出';

  @override
  String get confirm => '确认';

  @override
  String get delete => '删除';

  @override
  String get save => '保存';

  @override
  String get saved => '已收藏';

  @override
  String get bookmarkSave => '收藏';

  @override
  String get bookmarkSaved => '已收藏';

  @override
  String get add => '添加';

  @override
  String get edit => '编辑';

  @override
  String get retry => '重试';

  @override
  String comingSoon(String label) {
    return '$label 即将上线。';
  }

  @override
  String get addEmbyServer => 'Emby 服务器';

  @override
  String get addSmbShare => 'SMB 共享';

  @override
  String get addFtpServer => 'FTP 服务器';

  @override
  String get selectLibrary => '选择进入的媒体库';

  @override
  String discoverNotFoundInLibrary(String title) {
    return '没有在已连接的 Emby 媒体库中找到《$title》';
  }

  @override
  String bookmarkAdded(String title) {
    return '已加入书签：$title';
  }

  @override
  String bookmarkRemoved(String title) {
    return '已移除书签：$title';
  }

  @override
  String get bookmarkSaveFailed => '书签保存失败，请重试';

  @override
  String get quickPlayFailed => '快速播放失败，请重试';

  @override
  String get followSeriesStart => '追剧';

  @override
  String get followSeriesActive => '追剧中';

  @override
  String get followSeriesCancel => '取消追剧';

  @override
  String get followSeriesUpdated => '新集';

  @override
  String followSeriesStarted(String title) {
    return '已开始追剧：$title';
  }

  @override
  String followSeriesCanceled(String title) {
    return '已取消追剧：$title';
  }

  @override
  String get followSeriesUnavailable => '未找到可追剧的 Emby 剧集';

  @override
  String get discoverBookmarksSortedByUpdates => '已优先显示有新集的追剧收藏。';

  @override
  String get discoverOpen => '打开';

  @override
  String get discoverFeatured => '精选';

  @override
  String get discoverHotWall => '热门墙';

  @override
  String get discoverHotWallSubtitle => '从 TMDB 拉取的高热度标题实时网格。';

  @override
  String discoverTmdbCredentials(String title) {
    return '$title 需要 TMDB 凭证';
  }

  @override
  String get discoverTmdbCredentialsHint =>
      '在 `ui/flutter_app/.env` 中添加 `TMDB_READ_ACCESS_TOKEN` 或 `TMDB_API_KEY`，即可加载海报、热门推荐和精选背景。';

  @override
  String discoverSearchResultsFor(String query) {
    return '$query 的搜索结果';
  }

  @override
  String get discoverExplore => '探索';

  @override
  String get discoverUnableToLoad => '无法加载发现内容';

  @override
  String get discoverTryAgain => '重试';

  @override
  String get discoverSearchHint => '从 TMDB 搜索电影和剧集';

  @override
  String get discoverSearchGuide => '输入片名即可搜索 TMDB，快速跳转到你的媒体库。';

  @override
  String get discoverTmdbNotConfigured => 'TMDB 未配置';

  @override
  String get discoverTmdbNotConfiguredHint => '请先添加 TMDB Token 才能使用搜索。';

  @override
  String get discoverStartSearching => '开始搜索';

  @override
  String get discoverSearchExploreHint => '搜索电影或剧集，然后从匹配的媒体库中探索或快速播放。';

  @override
  String get discoverNoResults => '没有结果';

  @override
  String get discoverNoResultsHint => '换个片名、原名或更短的关键词试试。';

  @override
  String get discoverNoBookmarks => '还没有书签';

  @override
  String get discoverNoBookmarksHint => '从精选推荐或搜索结果中收藏标题，它们会显示在这里。';

  @override
  String discoverBookmarkCount(int count) {
    return '$count 个收藏标题，可探索或快速播放。';
  }

  @override
  String discoverExpandSources(int count) {
    return '展开另外 $count 个媒体源';
  }

  @override
  String get discoverLatencyGood => '优';

  @override
  String get discoverLatencyMedium => '中';

  @override
  String get discoverLatencySlow => '慢';

  @override
  String get discoverLatencyUnreachable => '连接不可达';

  @override
  String get embyServers => 'Emby 服务器';

  @override
  String get embyServersDesc => '在媒体库工作区里管理你的 Emby 连接。';

  @override
  String get embyNoServers => '还没有添加服务器';

  @override
  String get embyNoServersHint => '点击右上角按钮添加 Emby 服务器，连接后这里会展示你的媒体世界。';

  @override
  String get embyNoServersHintMobile => '点击上方按钮添加 Emby 服务器';

  @override
  String get embyEditServer => '编辑服务器';

  @override
  String get embyAddServer => '添加服务器';

  @override
  String get embyServerName => '名称';

  @override
  String get embyServerNameHint => '我的 Emby';

  @override
  String get embyServerAddress => '服务器地址';

  @override
  String get embyUsername => '用户名';

  @override
  String get embyPassword => '密码';

  @override
  String get embyLoginFailed => '登录失败: 用户名或密码错误';

  @override
  String embyConnectionFailed(String error) {
    return '连接失败: $error';
  }

  @override
  String embyUser(String name) {
    return '用户: $name';
  }

  @override
  String get embyBackToLibrary => '返回媒体库';

  @override
  String get embyRefresh => '刷新';

  @override
  String get embyContinueWatching => '继续观看';

  @override
  String get embyShowAll => '查看全部';

  @override
  String get embyLatestAdded => '最新添加';

  @override
  String get embyNameSort => '名称';

  @override
  String get embyYearSort => '年份';

  @override
  String get embyRatingSort => '评分';

  @override
  String embyItemCount(int count) {
    return '共 $count 项内容';
  }

  @override
  String get embyNoContent => '暂无内容';

  @override
  String get embyNoContentHint => '这个目录目前没有可显示的媒体项目。';

  @override
  String get embySeason => '季';

  @override
  String embyEpisodeCount(int count) {
    return '$count 集';
  }

  @override
  String embyDurationHoursMinutes(int hours, int minutes) {
    return '$hours小时$minutes分钟';
  }

  @override
  String embyDurationMinutes(int minutes) {
    return '$minutes分钟';
  }

  @override
  String get embyPlay => '播放';

  @override
  String get embyFavorite => '收藏';

  @override
  String get embyDetails => '详细信息';

  @override
  String get embyPlaybackOptions => '播放选项';

  @override
  String get embyVideoFormat => '视频格式';

  @override
  String get embyAudioFormat => '音频格式';

  @override
  String get embyStreamInfo => '音视频字幕信息';

  @override
  String get embyVideo => '视频';

  @override
  String get embyAudio => '音频';

  @override
  String get embySubtitle => '字幕';

  @override
  String get embyFillAllFields => '请填写所有必填字段';

  @override
  String get embySwitchServer => '切换服务器';

  @override
  String get embyAddServerTooltip => '添加服务器';

  @override
  String get embyExitApp => '退出应用';

  @override
  String get embyExitAppConfirm => '确定要退出应用吗？';

  @override
  String get embyPageLoadFailed => '页面加载失败';

  @override
  String get embySortTooltip => '排序';

  @override
  String get embyListView => '列表视图';

  @override
  String get embyGridView => '网格视图';

  @override
  String get embyHome => '首页';

  @override
  String get embyBrowseSubtitle => '按 Emby 目录整理的媒体内容。';

  @override
  String get embyContinueBrowse => '继续浏览你的媒体目录。';

  @override
  String get embyBack => '返回';

  @override
  String embyEpisodeLabel(int number) {
    return '第 $number 集';
  }

  @override
  String get embyStreamTitle => '标题';

  @override
  String get embyStreamLanguage => '语言';

  @override
  String get embyStreamCodec => '编码';

  @override
  String get embyStreamProfile => '配置文件';

  @override
  String get embyStreamLevel => '等级';

  @override
  String get embyStreamResolution => '分辨率';

  @override
  String get embyStreamAspectRatio => '宽高比';

  @override
  String get embyStreamInterlaced => '隔行扫描';

  @override
  String get embyStreamFrameRate => '帧率';

  @override
  String get embyStreamBitrate => '比特率';

  @override
  String get embyStreamVideoRange => '视频范围';

  @override
  String get embyStreamColorPrimaries => '颜色基色';

  @override
  String get embyStreamColorSpace => '色域';

  @override
  String get embyStreamColorTransfer => '色偏';

  @override
  String get embyStreamBitDepth => '位深度';

  @override
  String get embyStreamPixelFormat => '像素格式';

  @override
  String get embyStreamRefFrames => '参考帧';

  @override
  String get embyStreamChannelLayout => '声道布局';

  @override
  String get embyStreamChannels => '声道数';

  @override
  String get embyStreamSampleRate => '采样率';

  @override
  String get embyStreamDefault => '默认';

  @override
  String get embyStreamEmbeddedTitle => '内嵌标题';

  @override
  String get embyStreamForced => '强制';

  @override
  String get embyYes => '是';

  @override
  String get embyNo => '否';

  @override
  String get embyType => '类型';

  @override
  String get embyYear => '年份';

  @override
  String get embyRating => '分级';

  @override
  String get embyRuntime => '时长';

  @override
  String get embyScore => '评分';

  @override
  String get embyOriginalTitle => '原始标题';

  @override
  String get embyUnknown => '未知';

  @override
  String get embyMediaContent => '媒体内容';

  @override
  String get embyPlaybackUrlFailed => '无法获取播放地址';

  @override
  String get mediaSourceList => '媒体源列表';

  @override
  String mediaSourceCount(int count) {
    return '$count 项';
  }

  @override
  String get mediaSourceLoading => '正在加载媒体源…';

  @override
  String get mediaSourceEmpty => '还没有媒体源';

  @override
  String get mediaSourceEmptyHint => '从右上角添加 Emby、SMB 或 FTP 后，这里会直接显示你的媒体源列表。';

  @override
  String get mediaSourceAdd => '添加媒体源';

  @override
  String get mediaSourceEdit => '编辑媒体源';

  @override
  String get mediaSourceDelete => '删除媒体源';

  @override
  String mediaSourceDeleteConfirm(String name) {
    return '确定要删除 $name 吗？';
  }

  @override
  String get mediaSourceSelectProtocol => '选择一种协议，继续配置新的内容入口。';

  @override
  String get mediaSourceEmbyDesc => '连接媒体服务与元数据管理';

  @override
  String get mediaSourceSmbDesc => '添加局域网共享目录';

  @override
  String get mediaSourceFtpDesc => '访问远程文件服务器';

  @override
  String get mediaSourceHostAddress => '主机地址';

  @override
  String get mediaSourcePort => '端口';

  @override
  String get mediaSourceShareName => '共享名';

  @override
  String get mediaSourceShareNameHint => '例如：share, movies';

  @override
  String get mediaSourceWorkgroup => '工作组';

  @override
  String get mediaSourceSavePassword => '保存密码';

  @override
  String get mediaSourceNameHint => '例如：家庭服务器';

  @override
  String get mediaSourceFillRequired => '请填写所有必填字段';

  @override
  String get mediaSourceEnterShareName => '请输入共享名';

  @override
  String get mediaSourceConnectionFailed => '连接失败';

  @override
  String get mediaSourceLoginFailed => '登录失败，请检查服务器地址和凭据';

  @override
  String get mediaSourceAddSuccess => '添加成功';

  @override
  String get mediaSourceUpdateSuccess => '媒体源更新成功';

  @override
  String get mediaSourceDeleteSuccess => '删除成功';

  @override
  String mediaSourceDeleteFailed(String error) {
    return '删除失败: $error';
  }

  @override
  String mediaSourceLoadFailed(String error) {
    return '加载失败: $error';
  }

  @override
  String get mediaSourceSyncComplete => '同步完成';

  @override
  String get mediaSourcePleaseLogin => '请先登录';

  @override
  String get mediaSourceEnableSync => '请先在账户页面启用云同步';

  @override
  String get mediaSourceNoActive => '当前没有激活的媒体源';

  @override
  String get mediaSourceFileUnsupported => '暂不支持打开此文件类型';

  @override
  String mediaSourcePlayFailed(String error) {
    return '播放失败: $error';
  }

  @override
  String get browserRefreshDir => '刷新目录';

  @override
  String browserCurrentPath(String path) {
    return '当前位置：$path';
  }

  @override
  String get browserRootDir => '根目录';

  @override
  String get browserLoadingDir => '正在载入目录内容…';

  @override
  String get browserLoadFailed => '目录加载失败';

  @override
  String get browserReload => '重新加载';

  @override
  String get browserDirEmpty => '当前目录为空';

  @override
  String get browserDirEmptyHint => '这个目录里暂时没有可显示的文件或文件夹。';

  @override
  String get browserFolder => '文件夹';

  @override
  String get browserClickToEnter => '点击进入';

  @override
  String get browserBackToLibrary => '返回媒体库';

  @override
  String get mediaTypeEmbyService => '媒体服务与元数据管理';

  @override
  String get mediaTypeSmbShare => '局域网共享目录浏览';

  @override
  String get mediaTypeFtpServer => '远程文件服务器访问';

  @override
  String get mediaTypeFolder => '文件夹';

  @override
  String get mediaTypeVideo => '视频';

  @override
  String get mediaTypeAudio => '音频';

  @override
  String get mediaTypeSubtitle => '字幕';

  @override
  String get mediaTypeFile => '文件';

  @override
  String get mediaTypeUsernameNotSet => '未填写用户名';

  @override
  String mediaTypeUser(String name) {
    return '用户 $name';
  }

  @override
  String get mediaTypeShareNotSet => '未指定共享名';

  @override
  String mediaTypeShare(String name) {
    return '共享 $name';
  }

  @override
  String get mediaTypeAnonymous => '匿名访问';

  @override
  String get accountCenter => '账号中心';

  @override
  String get accountRefreshInfo => '刷新账号信息';

  @override
  String get accountNoInfo => '未获取到账号信息';

  @override
  String get accountNoInfoHint => '请重新登录或返回上一页后再次进入账户中心。';

  @override
  String get accountGoBack => '返回';

  @override
  String get accountAvatarUpdated => '头像已更新';

  @override
  String accountAvatarSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get accountRefreshed => '账号数据已刷新';

  @override
  String get accountRefreshFailed => '刷新失败，请稍后重试';

  @override
  String get accountTypeFree => '基础账号';

  @override
  String get accountTypePro => 'Pro 会员';

  @override
  String get accountTypeLifetime => '永久会员';

  @override
  String get accountLabelFree => 'Current Plan';

  @override
  String get accountLabelPro => 'Pro Access';

  @override
  String get accountLabelLifetime => 'Lifetime Access';

  @override
  String get accountPlanFree => '当前方案';

  @override
  String get accountPlanPro => '会员权益';

  @override
  String get accountPlanLifetime => '永久权益';

  @override
  String get accountDescFree => '本地播放、媒体库管理与基础服务都已就绪。';

  @override
  String get accountDescPro => '跨设备同步、更多设备额度与高级体验已经开启。';

  @override
  String get accountDescLifetime => '包含全部 Pro 高级功能，长期使用无需再关心续费。';

  @override
  String get accountFeatureLocalPlayback => '本地播放';

  @override
  String get accountFeatureLibraryManagement => '媒体库管理';

  @override
  String get accountFeatureBasicService => '基础账户服务';

  @override
  String get accountFeatureCloudSync => '云同步';

  @override
  String get accountFeatureMoreDevices => '更多设备';

  @override
  String get accountFeatureAdvancedWorkspace => '高级工作区';

  @override
  String get accountFeaturePriorityAccess => '优先体验新功能';

  @override
  String get accountFeatureUnlimitedDevices => '无限设备';

  @override
  String get accountFeatureLargerQuota => '更大配额';

  @override
  String get accountFeatureNoRenewal => '长期免续费';

  @override
  String get accountRegisteredAt => '注册时间';

  @override
  String get accountLastUpdate => '最近更新';

  @override
  String get accountCloudSync => '云同步';

  @override
  String get accountSyncEnabled => '已启用';

  @override
  String get accountSyncDisabled => '未启用';

  @override
  String get accountUsage => '使用情况';

  @override
  String get accountUsageDescription => '服务器、设备与空间额度的当前占用。';

  @override
  String get accountUsageServers => '服务器';

  @override
  String get accountUsageDevices => '设备';

  @override
  String get accountUsageStorage => '存储空间';

  @override
  String get accountUsageUnlimited => '无限';

  @override
  String get accountSyncTitle => '云同步';

  @override
  String get accountSyncEnabledDesc => '媒体服务器与配置数据已安全同步';

  @override
  String get accountSyncDisabledProDesc => '输入账号密码即可启用加密同步';

  @override
  String get accountSyncDisabledFreeDesc => '升级即可开启跨设备同步';

  @override
  String get accountEnableSync => '启用云同步';

  @override
  String get accountViewUpgrade => '查看升级方案';

  @override
  String get accountAdminTools => '管理员工具';

  @override
  String get accountAdminDesc => '管理兑换码与后台运营配置。';

  @override
  String get accountRedemptionManagement => '兑换码管理';

  @override
  String get accountRedemptionDesc => '生成、查看和维护兑换码状态';

  @override
  String get accountUpgradeTitle => 'Membership Upgrade';

  @override
  String get accountUpgradeToLifetime => '升级到永久版';

  @override
  String get accountUpgradeToPro => '升级到 Pro';

  @override
  String get accountUpgradeLifetimeDesc => '一次升级，长期保留高级同步与更多设备额度。';

  @override
  String get accountUpgradeProDesc => '解锁跨设备同步、更多高级功能与更高配额。';

  @override
  String get accountViewLifetimePlan => '查看永久版方案';

  @override
  String get accountViewProPlan => '查看 Pro 方案';

  @override
  String get accountLogout => '安全退出';

  @override
  String get accountLogoutDesc => '退出后需要重新登录，云同步密码也会从本地清除。';

  @override
  String get accountLogoutConfirmTitle => '确认登出';

  @override
  String get accountLogoutConfirmMessage => '登出后将清除本地同步密码，下次使用需要重新登录。';

  @override
  String get accountLogoutButton => '登出';

  @override
  String get accountEnableSyncTitle => '启用云同步';

  @override
  String get accountEnableSyncMessage => '请输入当前账号密码，验证成功后会立即开启加密同步。';

  @override
  String get accountPasswordLabel => '账号密码';

  @override
  String get accountPasswordHint => '请输入密码';

  @override
  String get accountPasswordRequired => '请输入密码';

  @override
  String get accountEnableSyncButton => '立即启用';

  @override
  String get accountSyncEnabledSuccess => '云同步已启用';

  @override
  String get accountSyncEnableFailed => '密码错误或启用失败，请重试';

  @override
  String accountExpiresAt(String date) {
    return '到期时间 $date';
  }

  @override
  String get accountUsernameNotSet => '未设置用户名';

  @override
  String get accountLifetimeRightsTitle => 'BovaPlayer\n永久权益';

  @override
  String get accountLifetimeChip => '永久版';

  @override
  String get accountVip => 'VIP';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowRestore => '还原';

  @override
  String get windowClose => '关闭';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsThemeCyberpunk => '赛博朋克';

  @override
  String get settingsThemeCyberpunkPro => '赛博朋克 Pro';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsLanguageZh => '简体中文';

  @override
  String get authLoginTitle => '登录账户';

  @override
  String get authLoginSubtitle => '输入邮箱和密码继续，或直接使用 GitHub 登录。';

  @override
  String get authEmailLabel => '邮箱地址';

  @override
  String get authPasswordLabel => '密码';

  @override
  String get authPasswordHint => '输入您的密码';

  @override
  String get authForgotPassword => '忘记密码？';

  @override
  String get authLoginButton => '登录';

  @override
  String get authOrThirdParty => '或使用第三方登录';

  @override
  String get authGitHubLogin => '使用 GitHub 登录';

  @override
  String get authNoAccount => '还没有账户？';

  @override
  String get authRegisterNow => '立即注册';

  @override
  String get authLoginSuccess => '登录成功！';

  @override
  String get authLoginFailed => '登录失败';

  @override
  String get authGitHubLoginFailed => 'GitHub 登录失败';

  @override
  String get authInvalidEmail => '请输入正确的邮箱地址';

  @override
  String get authEnterPassword => '请输入密码';

  @override
  String get authRegisterTitle => '注册新账户';

  @override
  String get authRegisterHeading => '创建你的账户';

  @override
  String get authRegisterSubtitle => '注册后即可开启媒体同步、购买会员方案并管理你的工作区配置。';

  @override
  String get authRegisterDesc => '填写基础信息后即可开始使用。用户名可稍后在账户中心继续调整。';

  @override
  String get authRegisterFactSync => '云同步';

  @override
  String get authRegisterFactSyncValue => '注册后可启用';

  @override
  String get authRegisterFactRights => '权益管理';

  @override
  String get authRegisterFactRightsValue => '支持升级与兑换';

  @override
  String get authRegisterFactSecurity => '账号安全';

  @override
  String get authRegisterFactSecurityValue => '邮箱验证';

  @override
  String get authUsernameLabel => '用户名（可选）';

  @override
  String get authUsernameHint => '输入你的用户名';

  @override
  String get authConfirmPasswordLabel => '确认密码';

  @override
  String get authConfirmPasswordHint => '再次输入密码';

  @override
  String get authPasswordMinLength => '密码至少需要 8 位字符';

  @override
  String get authPasswordHintRegister => '至少 8 位，建议包含字母和数字';

  @override
  String get authPasswordMismatch => '两次输入的密码不一致';

  @override
  String get authRegisterButton => '注册';

  @override
  String get authHasAccount => '已有账号？';

  @override
  String get authLoginNow => '立即登录';

  @override
  String get authRegisterSuccess => '注册成功！请查收验证邮件';

  @override
  String get authRegisterFailed => '注册失败';

  @override
  String get authRegisterTooFrequent => '请求过于频繁，请等待 45 秒后再试';

  @override
  String get authRegisterDbError => '数据库配置错误，请联系管理员';

  @override
  String get authRegisterEmailTaken => '该邮箱已被注册';

  @override
  String get authForgotTitle => '重置密码';

  @override
  String get authForgotCheckEmail => '检查你的邮箱';

  @override
  String get authForgotSubtitleSent => '邮件已经发出。回到邮箱完成密码重置后，再重新登录你的工作区。';

  @override
  String get authForgotSubtitleForm => '输入注册邮箱后，我们会向你发送一封带有重置链接的邮件。';

  @override
  String get authForgotFactEmailStatus => '邮件状态';

  @override
  String get authForgotFactEmailSent => '已发送';

  @override
  String get authForgotFactNextStep => '下一步';

  @override
  String get authForgotFactNextStepValue => '查收并点击链接';

  @override
  String get authForgotFactEmailVerify => '邮箱验证';

  @override
  String get authForgotFactRequired => '必需';

  @override
  String get authForgotFactResetMethod => '重置方式';

  @override
  String get authForgotFactResetViaEmail => '邮件链接';

  @override
  String get authForgotSendLink => '发送重置链接';

  @override
  String get authForgotFormDesc => '输入你的注册邮箱，我们会发送一封带有重置密码链接的邮件。';

  @override
  String get authForgotRemembered => '记起密码了？';

  @override
  String get authForgotBackToLogin => '返回登录';

  @override
  String get authForgotEmailSentTitle => '邮件已发送';

  @override
  String authForgotEmailSentDesc(String email) {
    return '我们已向 $email 发送重置密码的链接，请查收邮件并完成后续操作。';
  }

  @override
  String get authForgotReturnLogin => '返回登录';

  @override
  String get authForgotResend => '重新发送';

  @override
  String get authForgotSendFailed => '发送失败';

  @override
  String authRedeemFailed(String error) {
    return '兑换失败：$error';
  }

  @override
  String authGenerateFailed(String error) {
    return '生成失败：$error';
  }

  @override
  String authQueryFailed(String error) {
    return '查询失败：$error';
  }

  @override
  String get pricingTitle => '会员方案';

  @override
  String get pricingChoosePlan => '选择适合你的套餐';

  @override
  String get pricingHeroDesc => '账户、权益与升级流程统一到同一套工作区界面里。你可以直接升级，也可以先输入兑换码。';

  @override
  String get pricingCrossDeviceSync => '跨设备同步';

  @override
  String get pricingDeviceQuota => '设备额度';

  @override
  String get pricingCloudStorage => '云存储';

  @override
  String get pricingPlanFree => '社区免费版';

  @override
  String get pricingPlanFreePrice => '¥0';

  @override
  String get pricingPlanFreePeriod => '永久免费';

  @override
  String get pricingPlanFreeDesc => '适合轻量使用与本地播放体验，保留最基础的核心能力。';

  @override
  String get pricingPlanFreeCta => '当前套餐';

  @override
  String get pricingPlanFreeFeature1 => '最多 10 个服务器';

  @override
  String get pricingPlanFreeFeature2 => '最多 2 个设备';

  @override
  String get pricingPlanFreeFeature3 => '100 MB 云存储';

  @override
  String get pricingPlanFreeFeature4 => '基础播放功能';

  @override
  String get pricingPlanFreeFeature5 => '社区支持';

  @override
  String get pricingPlanPro => 'Pro 版';

  @override
  String get pricingPlanProPrice => '¥6.9';

  @override
  String get pricingPlanProPeriod => '/ 月';

  @override
  String get pricingPlanProDesc => '给多设备、多媒体库与跨端同步准备的主力方案。';

  @override
  String get pricingPlanProCta => '升级到 Pro';

  @override
  String get pricingPlanProFeature1 => '无限服务器';

  @override
  String get pricingPlanProFeature2 => '最多 5 个设备';

  @override
  String get pricingPlanProFeature3 => '1 GB 云存储';

  @override
  String get pricingPlanProFeature4 => '高级播放功能';

  @override
  String get pricingPlanProFeature5 => '优先支持';

  @override
  String get pricingPlanProFeature6 => 'GitHub 同步';

  @override
  String get pricingPlanLifetime => '永久版';

  @override
  String get pricingPlanLifetimePrice => '¥69';

  @override
  String get pricingPlanLifetimePeriod => '一次性付费';

  @override
  String get pricingPlanLifetimeDesc => '一次购买，长期解锁高级同步、完整配额与后续更新。';

  @override
  String get pricingPlanLifetimeCta => '解锁永久版';

  @override
  String get pricingPlanLifetimeFeature1 => '无限服务器';

  @override
  String get pricingPlanLifetimeFeature2 => '无限设备';

  @override
  String get pricingPlanLifetimeFeature3 => '5 GB 云存储';

  @override
  String get pricingPlanLifetimeFeature4 => '所有高级功能';

  @override
  String get pricingPlanLifetimeFeature5 => '终身更新';

  @override
  String get pricingPlanLifetimeFeature6 => '优先支持';

  @override
  String get pricingPlanLifetimeFeature7 => 'GitHub 同步';

  @override
  String get pricingRecommended => '推荐';

  @override
  String get pricingCurrentPlan => '当前套餐';

  @override
  String get pricingFeatureComparison => '功能对比';

  @override
  String get pricingFeatureComparisonDesc => '用同一张表快速对比不同方案的核心能力。';

  @override
  String get pricingServerCount => '服务器数量';

  @override
  String get pricingDeviceCount => '设备数量';

  @override
  String get pricingGitHubSync => 'GitHub 同步';

  @override
  String get pricingPrioritySupport => '优先支持';

  @override
  String get pricingLifetimeUpdates => '终身更新';

  @override
  String get pricingSupported => '支持';

  @override
  String get pricingUnlimited => '无限';

  @override
  String get pricingFaq => '常见问题';

  @override
  String get pricingFaqDesc => '购买与兑换前最常被问到的几个问题。';

  @override
  String get pricingFaqQ1 => '购买后多久生效？';

  @override
  String get pricingFaqA1 => '支付或兑换成功后会立刻更新账号权益，重新进入账户页即可看到最新状态。';

  @override
  String get pricingFaqQ2 => '可以先输入兑换码吗？';

  @override
  String get pricingFaqA2 => '可以。在购买确认弹窗里直接输入兑换码，系统会优先尝试兑换。';

  @override
  String get pricingFaqQ3 => 'Pro 和永久版区别是什么？';

  @override
  String get pricingFaqA3 => 'Pro 更适合月度订阅与持续使用；永久版更适合长期主力使用，权益一次性解锁。';

  @override
  String get pricingConfirmPurchase => '确认购买';

  @override
  String get pricingHaveRedemptionCode => '有兑换码？';

  @override
  String get pricingRedemptionCode => '兑换码';

  @override
  String get pricingRedeem => '兑换';

  @override
  String get pricingGoPay => '去支付';

  @override
  String get pricingProMonthly => 'Pro 版（月付）';

  @override
  String get pricingProMonthlyPrice => '¥6.9 / 月';

  @override
  String get pricingLifetimeOnce => '¥69（一次性）';

  @override
  String get pricingRedeemSuccess => '兑换成功';

  @override
  String get pricingAccountUpdated => '账号权益已更新。';

  @override
  String get pricingOk => '确定';

  @override
  String get pricingRedeemFailed => '兑换失败';

  @override
  String pricingRedeemError(String error) {
    return '兑换失败: $error';
  }

  @override
  String get danmakuSettings => '弹幕设置';

  @override
  String get danmakuShowDanmaku => '显示弹幕';

  @override
  String get danmakuOpacity => '透明度';

  @override
  String get danmakuFontSize => '字体大小';

  @override
  String get danmakuSpeed => '弹幕速度';

  @override
  String get danmakuDisplayArea => '显示区域';

  @override
  String get danmakuFullScreen => '全屏';

  @override
  String get danmakuThreeQuarters => '3/4屏';

  @override
  String get danmakuHalfScreen => '半屏';

  @override
  String get danmakuQuarterScreen => '1/4屏';

  @override
  String get danmakuUnknownVideo => '未知视频';

  @override
  String danmakuCount(int count) {
    return '共 $count 条弹幕';
  }

  @override
  String get danmakuUpgradeToPro => '升级到 Pro 版';

  @override
  String get danmakuUpgradeDesc =>
      '弹幕功能仅限 Pro 版和永久版用户使用。\n\n升级后可享受：\n• 实时弹幕显示\n• 弹幕自定义设置\n• 云同步功能\n• 更多高级功能';

  @override
  String get danmakuViewPlans => '查看方案';

  @override
  String get danmakuUpgradeUnlock => '升级到 Pro 版解锁弹幕功能';

  @override
  String get danmakuUpgrade => '升级';

  @override
  String get netBrowserTitle => '网络浏览器';

  @override
  String netBrowserLoadConnectionsFailed(String error) {
    return '加载连接失败: $error';
  }

  @override
  String get netBrowserConnectionFailed => '连接失败';

  @override
  String netBrowserConnectionError(String error) {
    return '连接失败: $error';
  }

  @override
  String netBrowserLoadDirFailed(String error) {
    return '加载目录失败: $error';
  }

  @override
  String netBrowserPlayFailed(String error) {
    return '播放失败: $error';
  }

  @override
  String get netBrowserNoConnections => '暂无连接\n点击右下角 + 添加';

  @override
  String get netBrowserDirEmpty => '目录为空';

  @override
  String get netBrowserRetry => '重试';

  @override
  String get netBrowserAddConnection => '添加连接';

  @override
  String get netBrowserProtocol => '协议';

  @override
  String get netBrowserName => '名称';

  @override
  String get netBrowserHost => '主机';

  @override
  String get netBrowserPort => '端口';

  @override
  String get netBrowserUsername => '用户名';

  @override
  String get netBrowserPassword => '密码';

  @override
  String get netBrowserShareName => '共享名';

  @override
  String get netBrowserShareHint => '例如: share, movies';

  @override
  String get netBrowserWorkgroup => '工作组';

  @override
  String get netBrowserWorkgroupHint => '默认: WORKGROUP';

  @override
  String get netBrowserSavePassword => '保存密码';

  @override
  String get netBrowserEnterName => '请输入名称';

  @override
  String get netBrowserEnterHost => '请输入主机';

  @override
  String get netBrowserEnterPort => '请输入端口';

  @override
  String get netBrowserEnterShareName => '请输入共享名';

  @override
  String get redemptionTitle => '兑换码管理';

  @override
  String get redemptionHeroTitle => '管理兑换码与权益发放';

  @override
  String get redemptionHeroDesc => '这里统一展示兑换码状态、类型、过期信息与生成入口。整体风格与账户工作区保持一致。';

  @override
  String get redemptionGenerateTooltip => '生成兑换码';

  @override
  String get redemptionFilterAll => '全部';

  @override
  String get redemptionFilterUnused => '未使用';

  @override
  String get redemptionFilterUsed => '已使用';

  @override
  String get redemptionFilterExpired => '已过期';

  @override
  String get redemptionLoadFailed => '加载失败';

  @override
  String redemptionLoadError(String error) {
    return '加载失败: $error';
  }

  @override
  String get redemptionEmpty => '暂无兑换码';

  @override
  String get redemptionEmptyHint => '点击右上角加号生成新的兑换码。';

  @override
  String get redemptionStatusUsed => '已使用';

  @override
  String get redemptionStatusExpired => '已过期';

  @override
  String get redemptionStatusAvailable => '可用';

  @override
  String get redemptionTypePro => 'Pro 版';

  @override
  String get redemptionTypeLifetime => '永久版';

  @override
  String get redemptionCopyTooltip => '复制兑换码';

  @override
  String get redemptionCopied => '已复制兑换码';

  @override
  String get redemptionCreatedAt => '创建时间';

  @override
  String get redemptionExpiresAt => '过期时间';

  @override
  String get redemptionUsedBy => '使用者';

  @override
  String get redemptionUsedAt => '使用时间';

  @override
  String get redemptionGenerateTitle => '生成兑换码';

  @override
  String get redemptionGenerateDesc => '选择权益类型并填写数量、有效天数与备注信息。';

  @override
  String get redemptionGenerateCount => '生成数量';

  @override
  String get redemptionGenerateCountHint => '1-100';

  @override
  String get redemptionProDuration => 'Pro 有效天数';

  @override
  String get redemptionProDurationHint => '如 30、90、365';

  @override
  String get redemptionCodeExpiry => '兑换码过期天数';

  @override
  String get redemptionCodeExpiryHint => '生成后多少天内有效';

  @override
  String get redemptionNote => '备注（可选）';

  @override
  String get redemptionNoteHint => '如：送给活动用户';

  @override
  String get redemptionGenerate => '生成';

  @override
  String redemptionGenerateSuccess(int count) {
    return '成功生成 $count 个兑换码';
  }

  @override
  String redemptionCopiedCode(String code) {
    return '已复制: $code';
  }

  @override
  String get redemptionGenerateFailed => '生成失败';

  @override
  String redemptionGenerateError(String error) {
    return '生成失败: $error';
  }
}
