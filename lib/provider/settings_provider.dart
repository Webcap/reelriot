import 'package:reelriot/preferences/setting_preferences.dart';
import 'package:reelriot/utils/constant.dart';
import 'package:reelriot/video_providers/provider_names.dart';
import 'package:flutter/material.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsPreferences _settingsPreferences = SettingsPreferences();

  bool _isAdult = false;
  bool get isAdult => _isAdult;

// Material 3 removed

  String _appTheme = "dark";
  String get appTheme => _appTheme;

  String _imageQuality = "w500/";
  String get imageQuality => _imageQuality;

  String _defaultCountry = 'US';
  String get defaultCountry => _defaultCountry;

  String _defaultView = 'list';
  String get defaultView => _defaultView;

  int _defaultSeekDuration = 10;
  int get defaultSeekDuration => _defaultSeekDuration;

  int _playerTimeDisplay = 1;
  int get playerTimeDisplay => _playerTimeDisplay;

  // int _defaultMinBufferDuration = 120000;
  // int get defaultMinBufferDuration => _defaultMinBufferDuration;

  int _defaultMaxBufferDuration = 360000;
  int get defaultMaxBufferDuration => _defaultMaxBufferDuration;

  int _defaultVideoResolution = 0;
  int get defaultVideoResolution => _defaultVideoResolution;

  String _subtitleForegroundColor = Colors.white.toString();
  String get subtitleForegroundColor => _subtitleForegroundColor;

  String _subtitleBackgroundColor = Colors.black45.toString();
  String get subtitleBackgroundColor => _subtitleBackgroundColor;

  int _subtitleFontSize = 17;
  int get subtitleFontSize => _subtitleFontSize;

  String _appLanguage = 'en';
  String get appLanguage => _appLanguage;

  String _defaultAudioLanguage = 'en';
  String get defaultAudioLanguage => _defaultAudioLanguage;


  String _proPrecedence = ProviderNames.defaultPrecedenceString;
  String get proPreference => _proPrecedence;

  bool _enableProxy = false;
  bool get enableProxy => _enableProxy;

  String _subtitleTextStyle = "regular";
  String get subtitleTextStyle => _subtitleTextStyle;

  // theme change
  Future<void> getCurrentThemeMode() async {
    appTheme = await _settingsPreferences.getThemeMode();
  }

  set appTheme(String value) {
    _appTheme = value;
    _settingsPreferences.setThemeMode(value);
    notifyListeners();
  }

// Material 3 removed

  // adult preference change
  Future<void> getCurrentAdultMode() async {
    isAdult = await _settingsPreferences.getAdultMode();
  }

  set isAdult(bool value) {
    _isAdult = value;
    _settingsPreferences.setAdultMode(value);
    notifyListeners();
  }

  // image preference
  Future<void> getCurrentImageQuality() async {
    imageQuality = await _settingsPreferences.getImageQuality();
  }

  set imageQuality(String value) {
    _imageQuality = value;
    _settingsPreferences.setImageQuality(value);
    notifyListeners();
  }

  // watch country
  Future<void> getCurrentWatchCountry() async {
    defaultCountry = await _settingsPreferences.getCountryName();
  }

  set defaultCountry(String value) {
    _defaultCountry = value;
    _settingsPreferences.setCountryName(value);
    notifyListeners();
  }

  // view preference
  Future<void> getCurrentViewType() async {
    defaultView = await _settingsPreferences.getViewType();
  }

  set defaultView(String value) {
    _defaultView = value;
    _settingsPreferences.setViewType(value);
    notifyListeners();
  }

  Future<void> getSeekDuration() async {
    defaultSeekDuration = await _settingsPreferences.getSeekDuraion();
  }

  set defaultSeekDuration(int value) {
    _defaultSeekDuration = value;
    _settingsPreferences.setSeekDuration(value);
    notifyListeners();
  }



  // Future<void> getMinBufferDuration() async {
  //   defaultMinBufferDuration = await videoPlayerPreferences.getMinBuffer();
  // }

  // set defaultMinBufferDuration(int value) {
  //   _defaultMinBufferDuration = value;
  //   videoPlayerPreferences.setMinBufferDuration(value);
  //   notifyListeners();
  // }

  // BUFFER_DURATION
  Future<void> getMaxBufferDuration() async {
    defaultMaxBufferDuration = await _settingsPreferences.getMaxBuffer();
  }

  set defaultMaxBufferDuration(int value) {
    _defaultMaxBufferDuration = value;
    _settingsPreferences.setMaxBufferDuration(value);
    notifyListeners();
  }

  // Video player preferences
  // video Resolution
  Future<void> getVideoResolution() async {
    defaultVideoResolution =
        await _settingsPreferences.getDefaultVideoQuality();
  }

  set defaultVideoResolution(int value) {
    _defaultVideoResolution = value;
    _settingsPreferences.setDefaultVideoQuality(value);
    notifyListeners();
  }


  // subtitle foreground color
  Future<void> getForegroundSubtitleColor() async {
    subtitleForegroundColor = await _settingsPreferences.subtitleForeground();
  }

  set subtitleForegroundColor(String value) {
    _subtitleForegroundColor = value;
    _settingsPreferences.setSubtitleForeground(value);
    notifyListeners();
  }

  Future<void> getBackgroundSubtitleColor() async {
    subtitleBackgroundColor = await _settingsPreferences.subtitleBackground();
  }

  set subtitleBackgroundColor(String value) {
    _subtitleBackgroundColor = value;
    _settingsPreferences.setSubtitleBackground(value);
    notifyListeners();
  }

  Future<void> getSubtitleSize() async {
    subtitleFontSize = await _settingsPreferences.subtitleFont();
  }

  set subtitleFontSize(int value) {
    _subtitleFontSize = value;
    _settingsPreferences.setSubtitleFont(value);
    notifyListeners();
  }

  Future<void> getAppLanguage() async {
    String lang = await _settingsPreferences.getAppLang();
    if (lang == 'ar' || lang == 'hi') lang = 'en';
    appLanguage = lang;
  }

  set appLanguage(String value) {
    _appLanguage = value;
    _settingsPreferences.setAppLanguage(value);
    notifyListeners();
  }


  Future<void> getPlayerTimeStyle() async {
    playerTimeDisplay = await _settingsPreferences.getPlayerStyleIndex();
  }

  set playerTimeDisplay(int value) {
    _playerTimeDisplay = value;
    _settingsPreferences.setPlayerStyleIndex(value);
    notifyListeners();
  }

  // provider precedence
  Future<void> getProviderPrecedence() async {
    proPreference = await _settingsPreferences.getProviderPrecedence();
  }

  set proPreference(String value) {
    _proPrecedence = value;
    _settingsPreferences.setProviderPrecedence(value);
    notifyListeners();
  }

  // getuseProxyMode
  Future<void> getUseProxyMode() async {
    enableProxy = await _settingsPreferences.getUseProxy();
  }

  set enableProxy(bool value) {
    _enableProxy = value;
    _settingsPreferences.setUseProxy(value);
    notifyListeners();
  }

  // getSubtitlestyle
  Future<void> getSubtitleStyle() async {
    subtitleTextStyle = await _settingsPreferences.getSubtitleStyle();
  }

  set subtitleTextStyle(String value) {
    _subtitleTextStyle = value;
    _settingsPreferences.setSubtitleStyle(value);
    notifyListeners();
  }

  Future<void> getDefaultAudioLanguage() async {
    defaultAudioLanguage = await _settingsPreferences.getDefaultAudioLanguage();
  }

  set defaultAudioLanguage(String value) {
    _defaultAudioLanguage = value;
    _settingsPreferences.setDefaultAudioLanguage(value);
    notifyListeners();
  }
}
