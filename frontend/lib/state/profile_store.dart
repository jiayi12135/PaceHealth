import 'package:flutter/foundation.dart';
import '../models/profile.dart';
class ProfileStore extends ChangeNotifier {
  UserProfile profile = UserProfile();
  UserPersonalInfo personalInfo = UserPersonalInfo();
  bool completed = false;
  bool signedIn = false;
  String email = '';

  void signIn(String value) {
    email = value.trim();
    signedIn = true;
    notifyListeners();
  }

  void signOut() {
    signedIn = false;
    completed = false;
    email = '';
    profile = UserProfile();
    personalInfo = UserPersonalInfo();
    notifyListeners();
  }

  void save({required UserProfile profile, required UserPersonalInfo personalInfo}) {
    this.profile = profile;
    this.personalInfo = personalInfo;
    completed = true;
    notifyListeners();
  }
}
