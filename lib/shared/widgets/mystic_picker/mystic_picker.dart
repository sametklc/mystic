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
    this.label = 'Doğum Tarihi',
    this.placeholder = 'Tarih Seç',
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
    this.label = 'Doğum Saati',
    this.placeholder = 'Saat Seç',
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

/// A mystical-themed location picker button
class MysticLocationPicker extends StatelessWidget {
  final String? selectedLocation;
  final ValueChanged<String> onLocationSelected;
  final String label;
  final String placeholder;

  const MysticLocationPicker({
    super.key,
    this.selectedLocation,
    required this.onLocationSelected,
    this.label = 'Doğum Yeri',
    this.placeholder = 'Şehir Seç',
  });

  // Major Turkish cities for the picker
  static const List<String> _turkishCities = [
    'Adana',
    'Ankara',
    'Antalya',
    'Bursa',
    'Denizli',
    'Diyarbakır',
    'Eskişehir',
    'Gaziantep',
    'İstanbul',
    'İzmir',
    'Kayseri',
    'Kocaeli',
    'Konya',
    'Malatya',
    'Manisa',
    'Mersin',
    'Muğla',
    'Samsun',
    'Şanlıurfa',
    'Trabzon',
  ];

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
    int selectedIndex = selectedLocation != null
        ? _turkishCities.indexOf(selectedLocation!)
        : 8; // Default to Istanbul

    if (selectedIndex < 0) selectedIndex = 8;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MysticPickerSheet(
        title: label,
        onDone: () {
          onLocationSelected(_turkishCities[selectedIndex]);
          Navigator.pop(context);
        },
        child: CupertinoPicker(
          scrollController: FixedExtentScrollController(
            initialItem: selectedIndex,
          ),
          itemExtent: 40,
          onSelectedItemChanged: (index) => selectedIndex = index,
          children: _turkishCities
              .map((city) => Center(
                    child: Text(
                      city,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ))
              .toList(),
        ),
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
                    'İptal',
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
                    'Tamam',
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
