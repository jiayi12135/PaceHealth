import 'package:flutter/foundation.dart';
import '../models/profile.dart';
class ProfileStore extends ChangeNotifier { UserProfile profile = UserProfile(); UserPersonalInfo personalInfo = UserPersonalInfo(); bool completed = false; void save({required UserProfile profile, required UserPersonalInfo personalInfo}) { this.profile = profile; this.personalInfo = personalInfo; completed = true; notifyListeners(); } }
