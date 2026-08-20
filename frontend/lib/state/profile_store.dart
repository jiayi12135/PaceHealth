import 'package:flutter/foundation.dart';
import '../models/profile.dart';
class ProfileStore extends ChangeNotifier {
  UserProfile profile = UserProfile();
  UserPersonalInfo personalInfo = UserPersonalInfo();
  bool completed = false;
  bool signedIn = false;
  String email = '';
  String? accessToken;

  void signIn(String value, {String? accessToken}) {
    email = value.trim();
    signedIn = true;
    this.accessToken = accessToken;
    notifyListeners();
  }

  void signOut() {
    signedIn = false;
    completed = false;
    email = '';
    accessToken = null;
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

  /// 登录后如果backend已经有这个用户的资料,直接用它填充store并跳过问卷——
  /// 跟save()逻辑一样,单独起个名字只是为了在调用处更清楚这是"从backend读回来的",不是用户刚填的。
  void hydrate({required UserProfile profile, required UserPersonalInfo personalInfo}) {
    save(profile: profile, personalInfo: personalInfo);
  }
}
