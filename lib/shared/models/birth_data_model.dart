/// Represents the user's birth data for astrological calculations.
class BirthDataModel {
  /// Date of birth
  final DateTime? birthDate;

  /// Time of birth (stored as DateTime for convenience, only time part matters)
  final DateTime? birthTime;

  /// Location of birth
  final String? birthLocation;

  /// Latitude of birth location
  final double? latitude;

  /// Longitude of birth location
  final double? longitude;

  const BirthDataModel({
    this.birthDate,
    this.birthTime,
    this.birthLocation,
    this.latitude,
    this.longitude,
  });

  const BirthDataModel.empty()
      : birthDate = null,
        birthTime = null,
        birthLocation = null,
        latitude = null,
        longitude = null;

  BirthDataModel copyWith({
    DateTime? birthDate,
    DateTime? birthTime,
    String? birthLocation,
    double? latitude,
    double? longitude,
  }) {
    return BirthDataModel(
      birthDate: birthDate ?? this.birthDate,
      birthTime: birthTime ?? this.birthTime,
      birthLocation: birthLocation ?? this.birthLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  /// Check if all required data is provided
  bool get isComplete =>
      birthDate != null && birthTime != null && birthLocation != null;

  /// Format birth date as readable string
  String get formattedDate {
    if (birthDate == null) return '';
    return '${birthDate!.day}.${birthDate!.month.toString().padLeft(2, '0')}.${birthDate!.year}';
  }

  /// Format birth time as readable string
  String get formattedTime {
    if (birthTime == null) return '';
    return '${birthTime!.hour.toString().padLeft(2, '0')}:${birthTime!.minute.toString().padLeft(2, '0')}';
  }

  @override
  String toString() =>
      'BirthDataModel(date: $formattedDate, time: $formattedTime, location: $birthLocation)';
}
