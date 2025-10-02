import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingController extends ChangeNotifier {
  static const _key = 'onboarding_done';
  bool _done = false;

  bool get isDone => _done;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _done = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> setDone(bool v) async {
    _done = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, v);
    notifyListeners();
  }
}

