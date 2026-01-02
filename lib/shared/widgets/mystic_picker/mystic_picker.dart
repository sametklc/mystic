import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/constants.dart';

/// A mystical-themed date picker button that opens a Cupertino picker
class MysticDatePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final String label;
  final String placeholder;

  const MysticDatePicker({
    super.key,
    this.selectedDate,
    required this.onDateSelected,
    this.label = 'Birth Date',
    this.placeholder = 'Select Date',
  });

  @override
  Widget build(BuildContext context) {
    return _MysticPickerButton(
      label: label,
      value: selectedDate != null
          ? '${selectedDate!.day}.${selectedDate!.month.toString().padLeft(2, '0')}.${selectedDate!.year}'
          : null,
      placeholder: placeholder,
      icon: Icons.calendar_today_outlined,
      onTap: () => _showDatePicker(context),
    );
  }

  void _showDatePicker(BuildContext context) {
    DateTime tempDate = selectedDate ?? DateTime(1995, 1, 1);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MysticPickerSheet(
        title: label,
        onDone: () {
          onDateSelected(tempDate);
          Navigator.pop(context);
        },
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: tempDate,
          minimumDate: DateTime(1900),
          maximumDate: DateTime.now(),
          onDateTimeChanged: (date) => tempDate = date,
          dateOrder: DatePickerDateOrder.dmy,
        ),
      ),
    );
  }
}

/// A mystical-themed time picker button
class MysticTimePicker extends StatelessWidget {
  final DateTime? selectedTime;
  final ValueChanged<DateTime> onTimeSelected;
  final String label;
  final String placeholder;

  const MysticTimePicker({
    super.key,
    this.selectedTime,
    required this.onTimeSelected,
    this.label = 'Birth Time',
    this.placeholder = 'Select Time',
  });

  @override
  Widget build(BuildContext context) {
    return _MysticPickerButton(
      label: label,
      value: selectedTime != null
          ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
          : null,
      placeholder: placeholder,
      icon: Icons.access_time_outlined,
      onTap: () => _showTimePicker(context),
    );
  }

  void _showTimePicker(BuildContext context) {
    DateTime tempTime = selectedTime ?? DateTime(2000, 1, 1, 12, 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MysticPickerSheet(
        title: label,
        onDone: () {
          onTimeSelected(tempTime);
          Navigator.pop(context);
        },
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          initialDateTime: tempTime,
          use24hFormat: true,
          onDateTimeChanged: (time) => tempTime = time,
        ),
      ),
    );
  }
}

/// A mystical-themed location picker button with Country + City
class MysticLocationPicker extends StatelessWidget {
  final String? selectedLocation;
  final ValueChanged<String> onLocationSelected;
  final String label;
  final String placeholder;

  const MysticLocationPicker({
    super.key,
    this.selectedLocation,
    required this.onLocationSelected,
    this.label = 'Birth Place',
    this.placeholder = 'Select Location',
  });

  // Countries with major cities
  static const Map<String, List<String>> _countryCities = {
    'Turkey': ['Istanbul', 'Ankara', 'Izmir', 'Antalya', 'Bursa', 'Adana'],
    'United States': ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Miami', 'San Francisco'],
    'United Kingdom': ['London', 'Manchester', 'Birmingham', 'Liverpool', 'Edinburgh', 'Glasgow'],
    'Germany': ['Berlin', 'Munich', 'Frankfurt', 'Hamburg', 'Cologne', 'Stuttgart'],
    'France': ['Paris', 'Lyon', 'Marseille', 'Nice', 'Bordeaux', 'Toulouse'],
    'Italy': ['Rome', 'Milan', 'Naples', 'Florence', 'Venice', 'Turin'],
    'Spain': ['Madrid', 'Barcelona', 'Valencia', 'Seville', 'Bilbao', 'Malaga'],
    'Netherlands': ['Amsterdam', 'Rotterdam', 'The Hague', 'Utrecht', 'Eindhoven'],
    'Canada': ['Toronto', 'Vancouver', 'Montreal', 'Calgary', 'Ottawa'],
    'Australia': ['Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Adelaide'],
    'Japan': ['Tokyo', 'Osaka', 'Kyoto', 'Yokohama', 'Nagoya'],
    'Brazil': ['São Paulo', 'Rio de Janeiro', 'Brasília', 'Salvador'],
    'India': ['Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Kolkata'],
    'Russia': ['Moscow', 'Saint Petersburg', 'Novosibirsk', 'Kazan'],
    'China': ['Beijing', 'Shanghai', 'Shenzhen', 'Hong Kong', 'Guangzhou'],
  };

  // City coordinates (latitude, longitude)
  static const Map<String, List<double>> cityCoordinates = {
    'Istanbul': [41.0082, 28.9784],
    'Ankara': [39.9334, 32.8597],
    'Izmir': [38.4237, 27.1428],
    'Antalya': [36.8969, 30.7133],
    'Bursa': [40.1885, 29.0610],
    'Adana': [37.0000, 35.3213],
    'New York': [40.7128, -74.0060],
    'Los Angeles': [34.0522, -118.2437],
    'Chicago': [41.8781, -87.6298],
    'Houston': [29.7604, -95.3698],
    'Miami': [25.7617, -80.1918],
    'San Francisco': [37.7749, -122.4194],
    'London': [51.5074, -0.1278],
    'Manchester': [53.4808, -2.2426],
    'Birmingham': [52.4862, -1.8904],
    'Liverpool': [53.4084, -2.9916],
    'Edinburgh': [55.9533, -3.1883],
    'Glasgow': [55.8642, -4.2518],
    'Berlin': [52.5200, 13.4050],
    'Munich': [48.1351, 11.5820],
    'Frankfurt': [50.1109, 8.6821],
    'Hamburg': [53.5511, 9.9937],
    'Cologne': [50.9375, 6.9603],
    'Stuttgart': [48.7758, 9.1829],
    'Paris': [48.8566, 2.3522],
    'Lyon': [45.7640, 4.8357],
    'Marseille': [43.2965, 5.3698],
    'Nice': [43.7102, 7.2620],
    'Bordeaux': [44.8378, -0.5792],
    'Toulouse': [43.6047, 1.4442],
    'Rome': [41.9028, 12.4964],
    'Milan': [45.4642, 9.1900],
    'Naples': [40.8518, 14.2681],
    'Florence': [43.7696, 11.2558],
    'Venice': [45.4408, 12.3155],
    'Turin': [45.0703, 7.6869],
    'Madrid': [40.4168, -3.7038],
    'Barcelona': [41.3851, 2.1734],
    'Valencia': [39.4699, -0.3763],
    'Seville': [37.3891, -5.9845],
    'Bilbao': [43.2630, -2.9350],
    'Malaga': [36.7213, -4.4214],
    'Amsterdam': [52.3676, 4.9041],
    'Rotterdam': [51.9244, 4.4777],
    'The Hague': [52.0705, 4.3007],
    'Utrecht': [52.0907, 5.1214],
    'Eindhoven': [51.4416, 5.4697],
    'Toronto': [43.6532, -79.3832],
    'Vancouver': [49.2827, -123.1207],
    'Montreal': [45.5017, -73.5673],
    'Calgary': [51.0447, -114.0719],
    'Ottawa': [45.4215, -75.6972],
    'Sydney': [-33.8688, 151.2093],
    'Melbourne': [-37.8136, 144.9631],
    'Brisbane': [-27.4698, 153.0251],
    'Perth': [-31.9505, 115.8605],
    'Adelaide': [-34.9285, 138.6007],
    'Tokyo': [35.6762, 139.6503],
    'Osaka': [34.6937, 135.5023],
    'Kyoto': [35.0116, 135.7681],
    'Yokohama': [35.4437, 139.6380],
    'Nagoya': [35.1815, 136.9066],
    'São Paulo': [-23.5505, -46.6333],
    'Rio de Janeiro': [-22.9068, -43.1729],
    'Brasília': [-15.7975, -47.8919],
    'Salvador': [-12.9714, -38.5014],
    'Mumbai': [19.0760, 72.8777],
    'Delhi': [28.7041, 77.1025],
    'Bangalore': [12.9716, 77.5946],
    'Chennai': [13.0827, 80.2707],
    'Kolkata': [22.5726, 88.3639],
    'Moscow': [55.7558, 37.6173],
    'Saint Petersburg': [59.9311, 30.3609],
    'Novosibirsk': [55.0084, 82.9357],
    'Kazan': [55.7887, 49.1221],
    'Beijing': [39.9042, 116.4074],
    'Shanghai': [31.2304, 121.4737],
    'Shenzhen': [22.5431, 114.0579],
    'Hong Kong': [22.3193, 114.1694],
    'Guangzhou': [23.1291, 113.2644],
  };

  /// Get coordinates for a location string (e.g., "Istanbul, Turkey")
  /// Returns [latitude, longitude] or null if not found
  static List<double>? getCoordinates(String? location) {
    if (location == null || !location.contains(', ')) return null;
    final city = location.split(', ')[0];
    return cityCoordinates[city];
  }

  static List<String> get _countries => _countryCities.keys.toList();

  @override
  Widget build(BuildContext context) {
    return _MysticPickerButton(
      label: label,
      value: selectedLocation,
      placeholder: placeholder,
      icon: Icons.location_on_outlined,
      onTap: () => _showLocationPicker(context),
    );
  }

  void _showLocationPicker(BuildContext context) {
    // Parse existing selection
    String? existingCountry;
    String? existingCity;
    if (selectedLocation != null && selectedLocation!.contains(', ')) {
      final parts = selectedLocation!.split(', ');
      existingCity = parts[0];
      existingCountry = parts[1];
    }

    int countryIndex = existingCountry != null
        ? _countries.indexOf(existingCountry)
        : 0; // Default to Turkey
    if (countryIndex < 0) countryIndex = 0;

    List<String> currentCities = _countryCities[_countries[countryIndex]]!;
    int cityIndex = existingCity != null
        ? currentCities.indexOf(existingCity)
        : 0;
    if (cityIndex < 0) cityIndex = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _LocationPickerSheet(
        initialCountryIndex: countryIndex,
        initialCityIndex: cityIndex,
        countryCities: _countryCities,
        countries: _countries,
        onDone: (country, city) {
          onLocationSelected('$city, $country');
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Custom two-column location picker sheet
class _LocationPickerSheet extends StatefulWidget {
  final int initialCountryIndex;
  final int initialCityIndex;
  final Map<String, List<String>> countryCities;
  final List<String> countries;
  final void Function(String country, String city) onDone;

  const _LocationPickerSheet({
    required this.initialCountryIndex,
    required this.initialCityIndex,
    required this.countryCities,
    required this.countries,
    required this.onDone,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  late int _countryIndex;
  late int _cityIndex;
  late FixedExtentScrollController _cityController;

  @override
  void initState() {
    super.initState();
    _countryIndex = widget.initialCountryIndex;
    _cityIndex = widget.initialCityIndex;
    _cityController = FixedExtentScrollController(initialItem: _cityIndex);
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  List<String> get _currentCities =>
      widget.countryCities[widget.countries[_countryIndex]]!;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.borderRadiusXLarge),
        ),
        border: Border(
          top: BorderSide(color: AppColors.glassBorder, width: 1),
          left: BorderSide(color: AppColors.glassBorder, width: 1),
          right: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: AppConstants.spacingSmall),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMedium),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  'Birth Place',
                  style: AppTypography.headlineSmall,
                ),
                TextButton(
                  onPressed: () {
                    final country = widget.countries[_countryIndex];
                    final city = _currentCities[_cityIndex];
                    widget.onDone(country, city);
                  },
                  child: Text(
                    'Done',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Column labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Country',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'City',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Divider
          Container(
            height: 1,
            color: AppColors.glassBorder,
          ),

          // Two-column picker
          Expanded(
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Brightness.dark,
                primaryColor: AppColors.primary,
                textTheme: CupertinoTextThemeData(
                  pickerTextStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Country picker
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: _countryIndex,
                      ),
                      itemExtent: 36,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _countryIndex = index;
                          _cityIndex = 0;
                          _cityController.jumpToItem(0);
                        });
                      },
                      children: widget.countries
                          .map((country) => Center(
                                child: Text(
                                  country,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  // City picker
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _cityController,
                      itemExtent: 36,
                      onSelectedItemChanged: (index) {
                        _cityIndex = index;
                      },
                      children: _currentCities
                          .map((city) => Center(
                                child: Text(
                                  city,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Base picker button with mystical styling
class _MysticPickerButton extends StatefulWidget {
  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;

  const _MysticPickerButton({
    required this.label,
    this.value,
    required this.placeholder,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_MysticPickerButton> createState() => _MysticPickerButtonState();
}

class _MysticPickerButtonState extends State<_MysticPickerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowOpacity = hasValue ? 0.1 + _glowController.value * 0.1 : 0.0;

        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMedium,
              vertical: AppConstants.spacingMedium,
            ),
            decoration: BoxDecoration(
              color: _isPressed
                  ? AppColors.primarySurface
                  : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
              border: Border.all(
                color: hasValue
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.glassBorder,
                width: hasValue ? 1.5 : 1,
              ),
              boxShadow: hasValue
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(glowOpacity),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: hasValue ? AppColors.primary : AppColors.textTertiary,
                  size: 22,
                ),
                const SizedBox(width: AppConstants.spacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.value ?? widget.placeholder,
                        style: AppTypography.bodyLarge.copyWith(
                          color: hasValue
                              ? AppColors.textPrimary
                              : AppColors.textTertiary.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                  size: 24,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet container for pickers
class _MysticPickerSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onDone;

  const _MysticPickerSheet({
    required this.title,
    required this.child,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.borderRadiusXLarge),
        ),
        border: Border(
          top: BorderSide(color: AppColors.glassBorder, width: 1),
          left: BorderSide(color: AppColors.glassBorder, width: 1),
          right: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: AppConstants.spacingSmall),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMedium),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  title,
                  style: AppTypography.headlineSmall,
                ),
                TextButton(
                  onPressed: onDone,
                  child: Text(
                    'Done',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            color: AppColors.glassBorder,
          ),

          // Picker
          Expanded(
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Brightness.dark,
                primaryColor: AppColors.primary,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  pickerTextStyle: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
