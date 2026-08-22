import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../models/profile.dart';
class ProfileStore extends ChangeNotifier {
  UserProfile profile = UserProfile();
  UserPersonalInfo personalInfo = UserPersonalInfo();
  bool completed = false;
  bool signedIn = false;
  String email = '';
  String? accessToken;
  // 问卷完成后自动生成的workout plan,先只存内存里(demo阶段够用)。
  // app重启会丢失——如果以后要跨设备/重启都保留,backend需要加一个GET最新plan的接口。
  FitnessPlan? plan;

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
    plan = null;
    notifyListeners();
  }

  void setPlan(FitnessPlan? value) {
    plan = value;
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
