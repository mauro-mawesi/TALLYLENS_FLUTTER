import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('preferred_locale');
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale? l) async {
    _locale = l;
    final prefs = await SharedPreferences.getInstance();
    if (l == null) {
      await prefs.remove('preferred_locale');
    } else {
      await prefs.setString('preferred_locale', l.languageCode);
    }
    notifyListeners();
  }
}
