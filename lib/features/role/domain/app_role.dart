enum AppRole {
  needHelp('needHelp'),
  rescue('rescue');

  const AppRole(this.wireValue);

  final String wireValue;

  static AppRole? fromWire(String? value) {
    for (final role in values) {
      if (role.wireValue == value) return role;
    }
    return null;
  }
}
