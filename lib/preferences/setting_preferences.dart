// ignore_for_file: constant_identifier_names
import 'package:reelriot/utils/config.dart';
import 'package:reelriot/utils/globals.dart';
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/video_providers/provider_names.dart';

class SettingsPreferences {
  static const ADULT_MODE_STATUS = "adultStatus-v2";

  Future<void> setAdultMode(bool value) async {
    sharedPrefsSingleton.setBool(ADULT_MODE_STATUS, value);
  }

  Future<bool> getAdultMode() async {
    return sharedPrefsSingleton.getBool(ADULT_MODE_STATUS) ?? false;
  }

  static const COUNTRY_STATUS = 'US';

  Future<void> setCountryName(String countryName) async {
    sharedPrefsSingleton.setString(COUNTRY_STATUS, countryName);
  }

  Future<String> getCountryName() async {
    return sharedPrefsSingleton.getString(COUNTRY_STATUS) ?? 'US';
  }

  static const IMAGE_QUALITY_STATUS = "w500/";
  Future<void> setImageQuality(String imageQuality) async {
    sharedPrefsSingleton.setString(IMAGE_QUALITY_STATUS, imageQuality);
  }

  Future<String> getImageQuality() async {
    return sharedPrefsSingleton.getString(IMAGE_QUALITY_STATUS) ?? "w500/";
  }

// Material 3 removed

  static const THEME_MODE_STATUS = "themeStatusV2";

  Future<void> setThemeMode(String value) async {
    sharedPrefsSingleton.setString(THEME_MODE_STATUS, value);
  }

  Future<String> getThemeMode() async {
    return sharedPrefsSingleton.getString(THEME_MODE_STATUS) ?? "dark";
  }

  static const VIEW_PREFERENCE_STATUS = "list";
  Future<void> setViewType(String viewType) async {
    sharedPrefsSingleton.setString(VIEW_PREFERENCE_STATUS, viewType);
  }

  Future<String> getViewType() async {
    return sharedPrefsSingleton.getString(VIEW_PREFERENCE_STATUS) ?? "grid";
  }

  static const SEEK_PREFERENCE = 'seek';
  Future<void> setSeekDuration(int seekDuration) async {
    sharedPrefsSingleton.setInt(SEEK_PREFERENCE, seekDuration);
  }

  Future<int> getSeekDuraion() async {
    return sharedPrefsSingleton.getInt(SEEK_PREFERENCE) ?? 10;
  }

  // static const MIN_BUFFER_PREFERENCE = 'min_buffer';
  // setMinBufferDuration(int bufferDuration) async {
  //
  //   sharedPrefsSingleton.setInt(MIN_BUFFER_PREFERENCE, bufferDuration);
  // }

  // Future<int> getMinBuffer() async {
  //
  //   return sharedPrefsSingleton.getInt(MIN_BUFFER_PREFERENCE) ?? 120000;
  // }

  static const MAX_BUFFER_PREFERENCE = 'max_buffer';
  Future<void> setMaxBufferDuration(int bufferDuration) async {
    sharedPrefsSingleton.setInt(MAX_BUFFER_PREFERENCE, bufferDuration);
  }

  Future<int> getMaxBuffer() async {
    return sharedPrefsSingleton.getInt(MAX_BUFFER_PREFERENCE) ?? 360000;
  }

  static const DEFAULT_VIDEO_QUALITY = 'video_quality';
  Future<void> setDefaultVideoQuality(int videoQuality) async {
    sharedPrefsSingleton.setInt(DEFAULT_VIDEO_QUALITY, videoQuality);
  }

  Future<int> getDefaultVideoQuality() async {
    return sharedPrefsSingleton.getInt(DEFAULT_VIDEO_QUALITY) ?? 0;
  }


  static const SUBTITLE_FOREGROUND_COLOR = 'subtitle_foreground_color';
  Future<void> setSubtitleForeground(String color) async {
    sharedPrefsSingleton.setString(SUBTITLE_FOREGROUND_COLOR, color);
  }

  Future<String> subtitleForeground() async {
    return sharedPrefsSingleton.getString(SUBTITLE_FOREGROUND_COLOR) ??
        'Color(0xffffffff)';
  }

  static const SUBTITLE_BACKGROUND_COLOR = 'subtitle_background_color';
  Future<void> setSubtitleBackground(String color) async {
    sharedPrefsSingleton.setString(SUBTITLE_BACKGROUND_COLOR, color);
  }

  Future<String> subtitleBackground() async {
    return sharedPrefsSingleton.getString(SUBTITLE_BACKGROUND_COLOR) ??
        'Color(0x73000000)';
  }

  static const SUBTITLE_FONT_SIZE = 'subtitle_font_size';
  Future<void> setSubtitleFont(int size) async {
    sharedPrefsSingleton.setInt(SUBTITLE_FONT_SIZE, size);
  }

  Future<int> subtitleFont() async {
    return sharedPrefsSingleton.getInt(SUBTITLE_FONT_SIZE) ?? 17;
  }


  static const APP_LANGUAGE_CODE = 'en';

  Future<void> setAppLanguage(String lang) async {
    sharedPrefsSingleton.setString(APP_LANGUAGE_CODE, lang);
  }

  Future<String> getAppLang() async {
    return sharedPrefsSingleton.getString(APP_LANGUAGE_CODE) ?? 'en';
  }

  static const PROVIDER_PRECEDENCE = "providerPrecedence-v12";

  Future<void> setProviderPrecedence(String pre) async {
    sharedPrefsSingleton.setString(PROVIDER_PRECEDENCE, pre);
  }

  Future<String> getProviderPrecedence() async {
    return sharedPrefsSingleton.getString(PROVIDER_PRECEDENCE) ??
        ProviderNames.defaultPrecedenceString;
  }

  static const PLAYER_STYLE_INDEX = "playerStyleIndex";

  Future<void> setPlayerStyleIndex(int index) async {
    sharedPrefsSingleton.setInt(PLAYER_STYLE_INDEX, index);
  }

  Future<int> getPlayerStyleIndex() async {
    return sharedPrefsSingleton.getInt(PLAYER_STYLE_INDEX) ?? 1;
  }

  static const USE_PROXY = "use_proxy";

  void setUseProxy(bool useProxy) {
    sharedPrefsSingleton.setBool(USE_PROXY, useProxy);
  }

  Future<bool> getUseProxy() async {
    return sharedPrefsSingleton.getBool(USE_PROXY) ?? false;
  }

  static const SUBTITLE_TEXT_STYLE = "subtitle_text_style";

  void setSubtitleStyle(String value) {
    sharedPrefsSingleton.setString(SUBTITLE_TEXT_STYLE, value);
  }

  Future<String> getSubtitleStyle() async {
    return sharedPrefsSingleton.getString(SUBTITLE_TEXT_STYLE) ?? "regular";
  }

  static const DEFAULT_AUDIO_LANGUAGE = 'default_audio_language';

  Future<void> setDefaultAudioLanguage(String lang) async {
    sharedPrefsSingleton.setString(DEFAULT_AUDIO_LANGUAGE, lang);
  }

  Future<String> getDefaultAudioLanguage() async {
    return sharedPrefsSingleton.getString(DEFAULT_AUDIO_LANGUAGE) ?? 'en';
  }
}
