import 'package:flutter/foundation.dart';

import '../models/discover_feed.dart';
import '../models/discover_section.dart';
import '../services/tmdb_service.dart';

class DiscoverController extends ChangeNotifier {
  DiscoverController({TmdbService? service})
      : _service = service ?? TmdbService();

  final TmdbService _service;

  bool _isLoading = false;
  String? _errorMessage;
  DiscoverPayload? _payload;
  DiscoverFeed _currentFeed = DiscoverFeed.home;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DiscoverPayload? get payload => _payload;
  DiscoverFeed get currentFeed => _currentFeed;
  bool get isConfigured => _service.isConfigured;

  String imageUrl(String? path, {String size = 'w780'}) {
    return _service.imageUrl(path, size: size);
  }

  Future<void> load(DiscoverFeed feed, {bool force = false}) async {
    if (_isLoading) return;
    if (!force && _payload != null && _currentFeed == feed) return;

    _isLoading = true;
    _errorMessage = null;
    _currentFeed = feed;
    notifyListeners();

    try {
      _payload = await _service.fetchPayload(feed);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() {
    return load(_currentFeed, force: true);
  }
}
