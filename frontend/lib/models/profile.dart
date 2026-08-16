class UserProfile {
  String name, sex, goal, lifestyle, exerciseHabit, exerciseLocation;
  int age, exerciseFrequencyPerWeek, exerciseDurationMinutes;
  double heightCm, startWeightKg, targetWeightKg;
  UserProfile({this.name = '', this.age = 0, this.sex = '', this.heightCm = 0, this.startWeightKg = 0, this.targetWeightKg = 0, this.goal = '', this.lifestyle = '', this.exerciseFrequencyPerWeek = 0, this.exerciseDurationMinutes = 0, this.exerciseHabit = '', this.exerciseLocation = ''});
  Map<String, dynamic> toJson() => {'name': name, 'age': age, 'sex': sex, 'heightCm': heightCm, 'startWeightKg': startWeightKg, 'targetWeightKg': targetWeightKg, 'goal': goal, 'lifestyle': lifestyle, 'exerciseFrequencyPerWeek': exerciseFrequencyPerWeek, 'exerciseDurationMinutes': exerciseDurationMinutes, 'exerciseHabit': exerciseHabit, 'exerciseLocation': exerciseLocation};
}
class UserPersonalInfo {
  List<String> availableEquipment, injuries, surgeryHistory;
  UserPersonalInfo({List<String>? availableEquipment, List<String>? injuries, List<String>? surgeryHistory}) : availableEquipment = availableEquipment ?? [], injuries = injuries ?? [], surgeryHistory = surgeryHistory ?? [];
  Map<String, dynamic> toJson() => {'availableEquipment': availableEquipment, 'injuries': injuries, 'surgeryHistory': surgeryHistory};
}
