import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/tmdb_media_item.dart';
import '../services/tmdb_service.dart';

class DiscoverSearchController extends ChangeNotifier {
  DiscoverSearchController({TmdbService? service})
      : _service = service ?? TmdbService();

  final TmdbService _service;
  Timer? _debounceTimer;

  String _query = '';
  bool _isLoading = false;
  String? _errorMessage;
  List<TmdbMediaItem> _results = const [];

  String get query => _query;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<TmdbMediaItem> get results => _results;
  bool get isConfigured => _service.isConfigured;

  String imageUrl(String? path, {String size = 'w780'}) {
    return _service.imageUrl(path, size: size);
  }

  void updateQuery(String value) {
    _query = value.trim();
    _debounceTimer?.cancel();

    if (_query.isEmpty) {
      _results = const [];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _debounceTimer = Timer(const Duration(milliseconds: 320), () {
      searchNow();
    });
  }

  Future<void> searchNow() async {
    if (_query.isEmpty) {
      _results = const [];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _results = await _service.searchMulti(_query);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
