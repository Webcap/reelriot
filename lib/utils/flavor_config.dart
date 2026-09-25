enum Flavor { dev, prod }

class FlavorConfig {
  final Flavor flavor;
  final String appName;
  final String baseUrl;

  static FlavorConfig? _instance;

  FlavorConfig._internal(this.flavor, this.appName, this.baseUrl);

  static void initialize({
    required Flavor flavor,
    required String appName,
    required String baseUrl,
  }) {
    _instance = FlavorConfig._internal(flavor, appName, baseUrl);
  }

  static FlavorConfig get instance {
    if (_instance == null) {
      throw Exception("FlavorConfig must be initialized with initialize()");
    }
    return _instance!;
  }

  static bool get isDev => instance.flavor == Flavor.dev;
  static bool get isProd => instance.flavor == Flavor.prod;

  /// Environment string expected by the Caffeine API feature flag evaluator.
  static String get envName => isDev ? 'dev' : 'prod';
}
