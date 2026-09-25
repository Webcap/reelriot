import 'package:caffeine_core/caffeine_core.dart';

class Profile {
  Profile({required this.index, String? url})
      : url = url ?? AvatarUtils.getAvatarUrl(index);
  final int index;
  final String url;
}

class ProfileImages {
  static List<Profile>? _cachedProfiles;

  List<Profile> profile() {
    if (_cachedProfiles != null && _cachedProfiles!.isNotEmpty) {
      return _cachedProfiles!;
    }
    // Default standard 0-49 roster
    return List.generate(50, (i) => Profile(index: i));
  }

  /// Asynchronously populates the avatar roster from caffeine-api.
  static Future<List<Profile>> loadCentralizedProfiles({String? apiBaseUrl}) async {
    try {
      final items = await AvatarUtils.fetchAvatars(
        apiBaseUrl: apiBaseUrl ?? 'https://caffeine.synqholdings.com',
      );
      _cachedProfiles = items.map((a) => Profile(index: a.id, url: a.url)).toList();
      return _cachedProfiles!;
    } catch (_) {
      return List.generate(50, (i) => Profile(index: i));
    }
  }
}
