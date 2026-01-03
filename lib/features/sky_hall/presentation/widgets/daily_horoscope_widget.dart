import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/services/device_id_service.dart';
import '../../../../core/utils/mystic_date_utils.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/services/astrology_service.dart';
import '../../data/services/astrology_api_service.dart';

/// Daily Horoscope / Cosmic Pulse widget for the Sky Hall Daily tab.
class DailyHoroscopeWidget extends ConsumerStatefulWidget {
  const DailyHoroscopeWidget({super.key});

  @override
  ConsumerState<DailyHoroscopeWidget> createState() => _DailyHoroscopeWidgetState();
}

class _DailyHoroscopeWidgetState extends ConsumerState<DailyHoroscopeWidget> {
  bool _isLoading = false;
  String? _dailyForecast;
  String? _cosmicVibe;
  List<String> _activePlanets = [];
  String? _overallEnergy;
  List<String> _focusAreas = [];
  bool _isCached = false;

  final AstrologyApiService _apiService = AstrologyApiService();

  @override
  void initState() {
    super.initState();
    _loadDailyForecast();
  }

  /// Get Firestore document reference for today's horoscope (using Mystic Date)
  DocumentReference get _todayHoroscopeRef {
    final deviceId = ref.read(deviceIdProvider);
    final mysticDate = getMysticDateString();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(deviceId)
        .collection('daily_horoscope')
        .doc(mysticDate);
  }

  Future<void> _loadDailyForecast() async {
    final user = ref.read(userProvider);

    // Check if user has birth data for personalized horoscope
    if (user.birthDate == null || user.birthLatitude == null) {
      // Fallback to basic horoscope
      if (user.sunSign != null) {
        _loadBasicForecast(user.sunSign!);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Check Firestore for existing horoscope (Mystic Date = 7 AM rule)
      final existingDoc = await _todayHoroscopeRef.get();

      if (existingDoc.exists) {
        final data = existingDoc.data() as Map<String, dynamic>;
        _applyHoroscopeData(data, isCached: true);
        debugPrint('Daily Horoscope: Loaded from Firestore (${getMysticDateString()})');
        return;
      }

      // Step 2: No cached horoscope - fetch from API
      final deviceId = ref.read(deviceIdProvider);
      final birthDate = user.birthDate!;

      final horoscope = await _apiService.getPersonalHoroscope(
        userId: deviceId,
        birthDate: birthDate,
        birthTime: user.birthTime ?? '12:00',
        birthLatitude: user.birthLatitude!,
        birthLongitude: user.birthLongitude ?? 0.0,
        birthTimezone: user.birthTimezone ?? 'UTC',
        name: user.name,
      );

      // Step 3: Save to Firestore for persistence
      await _todayHoroscopeRef.set({
        ...horoscope,
        'mystic_date': getMysticDateString(),
        'saved_at': FieldValue.serverTimestamp(),
      });

      _applyHoroscopeData(horoscope, isCached: false);
      debugPrint('Daily Horoscope: Fetched from API and saved to Firestore');
    } catch (e) {
      debugPrint('Personal horoscope error: $e');
      // Fallback to basic forecast
      if (user.sunSign != null) {
        _loadBasicForecast(user.sunSign!);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Apply horoscope data to state
  void _applyHoroscopeData(Map<String, dynamic> horoscope, {required bool isCached}) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _cosmicVibe = horoscope['cosmic_vibe'] as String? ?? 'Cosmic Alignment';
      _dailyForecast = horoscope['forecast'] as String? ?? '';
      _overallEnergy = horoscope['overall_energy'] as String?;
      _isCached = isCached;
      _focusAreas = (horoscope['focus_areas'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      // Extract active planets from transits
      final transits = horoscope['active_transits'] as List<dynamic>? ?? [];
      _activePlanets = transits
          .take(5)
          .map((t) => (t as Map<String, dynamic>)['transiting_planet'] as String? ?? '')
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();

      // Default planets if none from transits
      if (_activePlanets.isEmpty) {
        _activePlanets = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars'];
      }
    });
  }

  void _loadBasicForecast(String sunSign) {
    if (!mounted) return;

    final moonPhase = AstrologyService.getMoonPhase(DateTime.now());

    setState(() {
      _isLoading = false;
      _cosmicVibe = _getCosmicVibe(sunSign);
      _dailyForecast = _getDailyForecast(sunSign, moonPhase.name);
      _activePlanets = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars'];
    });
  }

  String _getCosmicVibe(String sunSign) {
    final vibes = {
      'Aries': 'Bold Action',
      'Taurus': 'Grounded Growth',
      'Gemini': 'Mental Clarity',
      'Cancer': 'Emotional Depth',
      'Leo': 'Creative Fire',
      'Virgo': 'Precise Focus',
      'Libra': 'Harmonious Balance',
      'Scorpio': 'Deep Transformation',
      'Sagittarius': 'Expansive Vision',
      'Capricorn': 'Structured Ambition',
      'Aquarius': 'Innovative Thinking',
      'Pisces': 'Intuitive Flow',
    };
    return vibes[sunSign] ?? 'Cosmic Alignment';
  }

  String _getDailyForecast(String sunSign, String moonPhase) {
    return 'The Moon in $moonPhase phase activates your intuition today. '
        'As a $sunSign, you may feel drawn to explore new creative territories. '
        'Mercury\'s current position enhances your communication skills, '
        'making this an excellent day for important conversations. '
        'Trust your instincts and embrace the cosmic flow.';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final today = DateTime.now();
    final moonPhase = AstrologyService.getMoonPhase(today);

    if (user.sunSign == null) {
      return _buildNoBirthDataState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & Moon Phase Header
          _buildDateHeader(today, moonPhase)
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: -0.2, end: 0),

          const SizedBox(height: AppConstants.spacingLarge),

          // Hero Card: Today's Cosmic Vibe
          _buildCosmicVibeCard()
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms)
              .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),

          const SizedBox(height: AppConstants.spacingLarge),

          // Daily Forecast Content
          if (_isLoading)
            _buildLoadingState()
          else
            _buildForecastContent()
                .animate()
                .fadeIn(delay: 400.ms, duration: 400.ms),

          const SizedBox(height: AppConstants.spacingLarge),

          // Active Planets Row
          _buildPlanetaryRow()
              .animate()
              .fadeIn(delay: 600.ms, duration: 400.ms)
              .slideY(begin: 0.2, end: 0),

          const SizedBox(height: AppConstants.spacingLarge),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date, MoonPhaseData moonPhase) {
    final dayName = DateFormat('EEEE').format(date);
    final fullDate = DateFormat('MMMM d, yyyy').format(date);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Date
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dayName.toUpperCase(),
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.mysticTeal,
                letterSpacing: 2,
              ),
            ),
            Text(
              fullDate,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),

        // Moon Phase Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
            color: AppColors.glassFill,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                moonPhase.emoji,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Text(
                moonPhase.name,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCosmicVibeCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppConstants.spacingLarge),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.mysticTeal.withOpacity(0.2),
                AppColors.primary.withOpacity(0.15),
                AppColors.secondary.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: AppColors.mysticTeal.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.mysticTeal.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              // Star decoration
              Icon(
                Icons.auto_awesome,
                color: AppColors.mysticTeal,
                size: 32,
              ),
              const SizedBox(height: AppConstants.spacingSmall),

              // Label
              Text(
                'TODAY\'S COSMIC VIBE',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: AppConstants.spacingSmall),

              // Vibe Text
              Text(
                _cosmicVibe ?? 'Cosmic Alignment',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForecastContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingMedium),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            color: AppColors.glassFill,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.wb_sunny_outlined,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Insight',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingSmall),
              Text(
                _dailyForecast ?? '',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanetaryRow() {
    final planetIcons = {
      'Sun': Icons.wb_sunny,
      'Moon': Icons.nightlight_round,
      'Mercury': Icons.speed,
      'Venus': Icons.favorite,
      'Mars': Icons.local_fire_department,
      'Jupiter': Icons.expand,
      'Saturn': Icons.architecture,
    };

    final planetColors = {
      'Sun': const Color(0xFFFFD700),
      'Moon': const Color(0xFFC0C0C0),
      'Mercury': const Color(0xFF87CEEB),
      'Venus': const Color(0xFFFF69B4),
      'Mars': const Color(0xFFFF4500),
      'Jupiter': const Color(0xFFDDA0DD),
      'Saturn': const Color(0xFF8B7355),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACTIVE TRANSITS',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSmall),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _activePlanets.map((planet) {
            final icon = planetIcons[planet] ?? Icons.circle;
            final color = planetColors[planet] ?? AppColors.textSecondary;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$planet is active in your chart today'),
                    backgroundColor: color.withOpacity(0.9),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.mysticTeal),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMedium),
          Text(
            'Reading the stars...',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBirthDataState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wb_sunny_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Text(
              'Complete Your Profile',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSmall),
            Text(
              'Add your birth data to receive personalized daily forecasts.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
