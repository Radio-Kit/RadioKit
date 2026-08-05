import 'feature_module.dart';

class ModuleRegistry {
  static final ModuleRegistry _instance = ModuleRegistry._internal();
  factory ModuleRegistry() => _instance;
  ModuleRegistry._internal();

  static ModuleRegistry get instance => _instance;

  final List<FeatureModule> _modules = [];

  void register(FeatureModule module) {
    if (!_modules.any((m) => m.id == module.id)) {
      _modules.add(module);
    }
  }

  List<FeatureModule> get registeredModules => List.unmodifiable(_modules);

  List<FeatureModule> get shellBranchModules =>
      List.unmodifiable(_modules.where((m) => m.isShellBranch));
}
