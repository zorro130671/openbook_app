// lib/services/giphy_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;

class GiphyItem {
  final String url; // full GIF url (original/downsized)
  final String previewUrl; // smaller GIF for grid previews (fixed_height)
  final int width;
  final int height;
  final bool isSticker;

  const GiphyItem({
    required this.url,
    required this.previewUrl,
    required this.width,
    required this.height,
    required this.isSticker,
  });
}

class GiphyService {
  final String apiKey;
  static const _host = 'api.giphy.com';
  static final _rng = Random();

  const GiphyService(this.apiKey);

  /// Trending endpoint (smaller default limit + safer rating)
  Future<List<GiphyItem>> trending({
    required bool stickers,
    int limit = 24, // ↓ was 48
    String rating = 'g', // ↓ was pg-13
  }) async {
    final path = stickers ? '/v1/stickers/trending' : '/v1/gifs/trending';
    final uri = Uri.https(_host, path, {
      'api_key': apiKey,
      'limit': '$limit',
      'rating': rating,
    });
    return _fetch(uri, stickers, limit: limit, rating: rating);
  }

  /// Search endpoint (smaller default limit + safer rating)
  Future<List<GiphyItem>> search(
    String q, {
    required bool stickers,
    int limit = 24, // ↓ was 48
    String rating = 'g', // ↓ was pg-13
  }) async {
    final path = stickers ? '/v1/stickers/search' : '/v1/gifs/search';
    final uri = Uri.https(_host, path, {
      'api_key': apiKey,
      'q': q,
      'limit': '$limit',
      'lang': 'en',
      'rating': rating,
    });
    return _fetch(uri, stickers, limit: limit, rating: rating, q: q);
  }

  Future<List<GiphyItem>> _fetch(
    Uri uri,
    bool stickers, {
    required int limit,
    required String rating,
    String? q,
  }) async {
    try {
      debugPrint('[GIPHY] GET $uri');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint(
        '[GIPHY] HTTP ${res.statusCode} (${stickers ? "stickers" : "gifs"})',
      );

      if (res.statusCode == 429) {
        // One **quick** retry with lighter params and random offset
        final newLimit = limit > 12
            ? 12
            : max(8, limit); // halve-ish but keep usable
        final offset = _rng.nextInt(200);
        final newQs = Map<String, String>.from(uri.queryParameters)
          ..['limit'] = '$newLimit'
          ..['rating'] = 'g'
          ..['offset'] = '$offset';
        final retryUri = uri.replace(queryParameters: newQs);
        debugPrint('[GIPHY] 429 retry → $retryUri');

        final retry = await http
            .get(retryUri)
            .timeout(const Duration(seconds: 10));
        debugPrint('[GIPHY] RETRY HTTP ${retry.statusCode}');

        if (retry.statusCode != 200) {
          debugPrint('[GIPHY] RETRY FAIL ${retry.statusCode}: ${retry.body}');
          return const [];
        }
        return _parseItems(retry.body, stickers);
      }

      if (res.statusCode != 200) {
        debugPrint('[GIPHY] ERROR ${res.statusCode}: ${res.body}');
        return const [];
      }

      return _parseItems(res.body, stickers);
    } catch (e, st) {
      debugPrint('[GIPHY] EXCEPTION: $e');
      debugPrint('[GIPHY] STACK: $st');
      return const [];
    }
  }

  List<GiphyItem> _parseItems(String body, bool stickers) {
    final jsonMap = jsonDecode(body) as Map<String, dynamic>;
    final data = (jsonMap['data'] as List?) ?? const [];
    debugPrint('[GIPHY] OK: ${data.length} items');

    final items = <GiphyItem>[];
    for (final e in data) {
      final images =
          (e as Map<String, dynamic>)['images'] as Map<String, dynamic>? ??
          const {};
      final fixed = images['fixed_height'] as Map<String, dynamic>? ?? const {};
      final downsized =
          images['downsized_medium'] as Map<String, dynamic>? ?? const {};
      final original = images['original'] as Map<String, dynamic>? ?? const {};

      final url =
          (original['url'] as String?) ??
          (downsized['url'] as String?) ??
          (fixed['url'] as String?) ??
          '';

      if (url.isEmpty) continue;

      final preview = (fixed['url'] as String?) ?? url;
      final w = int.tryParse((fixed['width'] ?? '0').toString()) ?? 0;
      final h = int.tryParse((fixed['height'] ?? '0').toString()) ?? 0;

      items.add(
        GiphyItem(
          url: url,
          previewUrl: preview,
          width: w,
          height: h,
          isSticker: stickers,
        ),
      );
    }
    return items;
  }
}
