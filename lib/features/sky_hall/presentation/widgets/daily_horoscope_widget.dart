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
import '../../../../shared/models/profile_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/services/astrology_service.dart';
import '../../../paywall/paywall.dart';
import '../../data/services/astrology_api_service.dart';

/// Daily Horoscope / Cosmic Pulse widget for the Sky Hall Daily tab.
class DailyHoroscopeWidget extends ConsumerStatefulWidget {
  const DailyHoroscopeWidget({super.key});

  @override
  ConsumerState<DailyHoroscopeWidget> createState() => _DailyHoroscopeWidgetState();
}

class _DailyHoroscopeWidgetState extends ConsumerState<DailyHoroscopeWidget>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  String? _dailyForecast;
  String? _cosmicVibe;
  List<String> _activePlanets = [];
  String? _overallEnergy;
  List<String> _focusAreas = [];
  bool _isCached = false;
  String? _currentLoadedProfileId;

  final AstrologyApiService _apiService = AstrologyApiService();

  @override
  bool get wantKeepAlive => true; // Keep widget alive in TabBarView

  @override
  void initState() {
    super.initState();
    // Initial load after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadForCurrentProfile();
    });
  }

  /// Check if we need to load data for the current profile
  void _checkAndLoadForCurrentProfile() {
    final profile = ref.read(currentProfileProvider);
    if (profile != null && profile.id != _currentLoadedProfileId && !_isLoading) {
      debugPrint('Daily Horoscope: Loading for profile ${profile.name} (${profile.id})');
      _loadDailyForecast(profile.id);
    }
  }

  /// Get Firestore document reference for today's horoscope (using Mystic Date)
  /// Now includes profile ID for multi-profile support
  DocumentReference _getTodayHoroscopeRef(String profileId) {
    final deviceId = ref.read(deviceIdProvider);
    final mysticDate = getMysticDateString();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(deviceId)
        .collection('profiles')
        .doc(profileId)
        .collection('daily_horoscope')
        .doc(mysticDate);
  }

  Future<void> _loadDailyForecast(String profileId) async {
    // Set loading state immediately
    if (mounted) {
      setState(() => _isLoading = true);
    }

    // Use current profile data (changes based on selected profile)
    final profile = ref.read(currentProfileProvider);

    // Safety check - make sure we're loading for the correct profile
    if (profile == null || profile.id != profileId) {
      debugPrint('Daily Horoscope: Profile mismatch (expected $profileId, got ${profile?.id}), skipping load');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final deviceId = ref.read(deviceIdProvider);
    final mysticDate = getMysticDateString();
    final firestorePath = 'users/$deviceId/profiles/${profile.id}/daily_horoscope/$mysticDate';
    debugPrint('======= DAILY HOROSCOPE DEBUG =======');
    debugPrint('Profile: ${profile.name} (${profile.id})');
    debugPrint('Birth: ${profile.birthDate}, ${profile.birthCity}');
    debugPrint('Firestore Path: $firestorePath');
    debugPrint('=====================================');

    // Check if profile has birth data for personalized horoscope
    if (profile.birthDate == null || profile.birthLatitude == null) {
      // Fallback to basic horoscope
      if (profile.sunSign != null) {
        _loadBasicForecast(profile.sunSign!, profileId);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    try {
      // Step 1: Check Firestore for existing horoscope (Mystic Date = 7 AM rule)
      final horoscopeRef = _getTodayHoroscopeRef(profile.id);
      final existingDoc = await horoscopeRef.get();

      if (existingDoc.exists) {
        final data = existingDoc.data() as Map<String, dynamic>;

        // Verify the stored horoscope belongs to this profile
        final storedProfileId = data['profile_id'] as String?;
        final storedName = data['user_name'] as String?;
        final forecast = data['forecast'] as String? ?? '';

        // Check if data is valid for this profile:
        // 1. If no profile_id stored, it's old data - regenerate
        // 2. If profile_id doesn't match - regenerate
        // 3. If name doesn't match (when both exist) - regenerate
        // 4. If forecast contains wrong name (e.g., "Dear OtherName") - regenerate
        bool needsRegenerate = storedProfileId == null || // Old data without profile tracking
                               storedProfileId != profile.id || // Wrong profile
                               (storedName != null && profile.name != null && storedName != profile.name);

        // Also check if forecast content has wrong name
        if (!needsRegenerate && profile.name != null) {
          // Check if forecast starts with "Dear [WrongName]" instead of "Dear [CurrentName]"
          final expectedStart = 'Dear ${profile.name}';
          final forecastLower = forecast.toLowerCase();
          final hasWrongName = forecastLower.startsWith('dear ') &&
                               !forecastLower.startsWith(expectedStart.toLowerCase());
          if (hasWrongName) {
            debugPrint('>>> FORECAST HAS WRONG NAME! Expected: $expectedStart, Got: ${forecast.substring(0, 30)}...');
            needsRegenerate = true;
          }
        }

        if (needsRegenerate) {
          debugPrint('>>> REGENERATING for ${profile.name}');
          // Delete the old/wrong data and regenerate
          await horoscopeRef.delete();
        } else {
          final forecastPreview = forecast.length > 50 ? forecast.substring(0, 50) : forecast;
          debugPrint('>>> USING CACHED: ${profile.name} - "$forecastPreview..."');
          _applyHoroscopeData(data, isCached: true, profileId: profileId);
          return;
        }
      }

      // Step 2: No cached horoscope - fetch from API
      // IMPORTANT: Use deviceId + profileId as user_id for unique cache per profile
      final uniqueUserId = '${deviceId}_${profile.id}';
      debugPrint('>>> Calling API with userId: $uniqueUserId, name: ${profile.name}');

      final horoscope = await _apiService.getPersonalHoroscope(
        userId: uniqueUserId,  // Unique per profile!
        birthDate: profile.birthDate!,
        birthTime: profile.birthTime ?? '12:00',
        birthLatitude: profile.birthLatitude!,
        birthLongitude: profile.birthLongitude ?? 0.0,
        birthTimezone: profile.birthTimezone ?? 'UTC',
        name: profile.name,
      );

      // Step 3: Save to Firestore for persistence
      await horoscopeRef.set({
        ...horoscope,
        'mystic_date': getMysticDateString(),
        'profile_id': profile.id,
        'user_name': profile.name,
        'saved_at': FieldValue.serverTimestamp(),
      });

      final newForecast = horoscope['forecast'] as String? ?? '';
      final newPreview = newForecast.length > 50 ? newForecast.substring(0, 50) : newForecast;
      debugPrint('>>> NEW FROM API: ${profile.name} - "$newPreview..."');
      _applyHoroscopeData(horoscope, isCached: false, profileId: profileId);
    } catch (e) {
      debugPrint('Personal horoscope error: $e');
      // Fallback to basic forecast
      if (profile.sunSign != null) {
        _loadBasicForecast(profile.sunSign!, profileId);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Apply horoscope data to state
  void _applyHoroscopeData(Map<String, dynamic> horoscope, {required bool isCached, required String profileId}) {
    if (!mounted) return;

    final forecast = horoscope['forecast'] as String? ?? '';
    final vibe = horoscope['cosmic_vibe'] as String? ?? 'Cosmic Alignment';
    debugPrint('Daily Horoscope: Applying data for profile $profileId - vibe: $vibe, forecast length: ${forecast.length}');

    setState(() {
      _isLoading = false;
      _currentLoadedProfileId = profileId;
      _cosmicVibe = vibe;
      _dailyForecast = forecast;
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

  void _loadBasicForecast(String sunSign, String profileId) {
    if (!mounted) return;

    final moonPhase = AstrologyService.getMoonPhase(DateTime.now());

    setState(() {
      _isLoading = false;
      _currentLoadedProfileId = profileId;
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final currentProfile = ref.watch(currentProfileProvider);
    final today = DateTime.now();
    final moonPhase = AstrologyService.getMoonPhase(today);

    // Listen for profile changes and reload data
    ref.listen<ProfileModel?>(currentProfileProvider, (previous, next) {
      if (next != null && next.id != _currentLoadedProfileId) {
        debugPrint('Daily Horoscope: Profile switched from ${previous?.name} to ${next.name}');
        // Clear old data and reload for new profile
        setState(() {
          _isLoading = true;
          _dailyForecast = null;
          _cosmicVibe = null;
          _activePlanets = [];
          _overallEnergy = null;
          _focusAreas = [];
          _isCached = false;
        });
        _loadDailyForecast(next.id);
      }
    });

    // Show loading state while data is being fetched
    if (_isLoading) {
      return _buildLoadingState();
    }

    // Check if we need initial load (widget just created or no data yet)
    if (currentProfile != null && _currentLoadedProfileId == null && _dailyForecast == null) {
      // Schedule initial load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isLoading) {
          _checkAndLoadForCurrentProfile();
        }
      });
      return _buildLoadingState();
    }

    if (currentProfile?.sunSign == null) {
      return _buildNoBirthDataState();
    }

    // Debug: Show what we're actually rendering
    final displayPreview = (_dailyForecast ?? '').length > 50
        ? _dailyForecast!.substring(0, 50)
        : (_dailyForecast ?? '');
    debugPrint('>>> RENDERING UI for ${currentProfile?.name}: "$displayPreview..."');
    debugPrint('>>> Current loaded profile ID: $_currentLoadedProfileId');

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
    final isPremium = ref.watch(isPremiumProvider);

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
                  const Spacer(),
                  if (!isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'PREVIEW',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingSmall),
              // Premium: Full text, Free: Limited with fade
              if (isPremium)
                Text(
                  _dailyForecast ?? '',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                )
              else
                _buildFreemiumForecast(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the freemium forecast with fade effect and unlock button
  Widget _buildFreemiumForecast() {
    // Get first 3 lines (approximately 150 characters)
    final fullText = _dailyForecast ?? '';
    final previewText = _getPreviewText(fullText, maxLines: 3);

    return Stack(
      children: [
        // Text with fade effect
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white,
                  Colors.white.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: Text(
                previewText,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                maxLines: 4,
                overflow: TextOverflow.clip,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            // Unlock Button
            _buildUnlockButton(),
          ],
        ),
      ],
    );
  }

  /// Extract preview text (first ~3 lines)
  String _getPreviewText(String text, {int maxLines = 3}) {
    final sentences = text.split('. ');
    if (sentences.length <= 2) {
      // If short text, show first 100 chars
      return text.length > 100 ? '${text.substring(0, 100)}...' : text;
    }
    // Take first 2-3 sentences
    final preview = sentences.take(2).join('. ');
    return '$preview...';
  }

  /// Build the premium unlock button - elegant dark glass style
  Widget _buildUnlockButton() {
    const goldAccent = Color(0xFFFFD700);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaywallView(
              onPurchase: () {
                Navigator.of(context).pop();
              },
              onClose: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          // Dark glass background
          color: const Color(0xFF1A1025),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: goldAccent.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_awesome,
              color: goldAccent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Unlock Full Horoscope',
              style: AppTypography.button.copyWith(
                color: goldAccent,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Transit data model for detailed bottom sheet
  static const Map<String, _TransitData> _transitDetails = {
    'Sun': _TransitData(
      icon: Icons.wb_sunny,
      color: Color(0xFFFFD700),
      title: 'Sun in Transit',
      subtitle: 'Vitality & Self-Expression',
      description: 'The Sun illuminates your path today, bringing clarity to your sense of purpose. '
          'This is an excellent time for self-expression and taking center stage. '
          'Your confidence is heightened, and others are naturally drawn to your radiant energy. '
          'Focus on activities that showcase your unique talents.',
      duration: 'Active for 30 days',
      affectedAreas: ['Identity', 'Creativity', 'Leadership'],
    ),
    'Moon': _TransitData(
      icon: Icons.nightlight_round,
      color: Color(0xFFC0C0C0),
      title: 'Moon in Transit',
      subtitle: 'Emotions & Intuition',
      description: 'The Moon\'s current position heightens your emotional sensitivity and intuition. '
          'Pay attention to your dreams and gut feelings today—they carry important messages. '
          'This is a perfect time for nurturing yourself and those you love. '
          'Your psychic abilities are enhanced.',
      duration: 'Active for 2.5 days',
      affectedAreas: ['Emotions', 'Home', 'Intuition'],
    ),
    'Mercury': _TransitData(
      icon: Icons.speed,
      color: Color(0xFF87CEEB),
      title: 'Mercury in Transit',
      subtitle: 'Communication & Intellect',
      description: 'Mercury sharpens your mind and communication skills today. '
          'Ideas flow freely, making this ideal for important conversations, negotiations, or learning. '
          'Your words carry extra power—use them wisely. '
          'Short trips and new connections are favored.',
      duration: 'Active for 14-21 days',
      affectedAreas: ['Communication', 'Learning', 'Travel'],
    ),
    'Venus': _TransitData(
      icon: Icons.favorite,
      color: Color(0xFFFF69B4),
      title: 'Venus in Transit',
      subtitle: 'Love & Harmony',
      description: 'Venus graces your chart with beauty, love, and harmony today. '
          'Relationships flourish under this influence—express affection freely. '
          'Your appreciation for art, music, and aesthetics is heightened. '
          'Financial matters related to pleasure and luxury are favored.',
      duration: 'Active for 23-25 days',
      affectedAreas: ['Love', 'Beauty', 'Finances'],
    ),
    'Mars': _TransitData(
      icon: Icons.local_fire_department,
      color: Color(0xFFFF4500),
      title: 'Mars in Transit',
      subtitle: 'Energy & Drive',
      description: 'Mars ignites your inner fire, bringing courage, passion, and determination. '
          'Your physical energy is amplified—channel it into productive activities. '
          'This is a powerful time for initiating projects and standing your ground. '
          'Be mindful of impulsive reactions.',
      duration: 'Active for 6-7 weeks',
      affectedAreas: ['Action', 'Courage', 'Competition'],
    ),
    'Jupiter': _TransitData(
      icon: Icons.expand,
      color: Color(0xFFDDA0DD),
      title: 'Jupiter in Transit',
      subtitle: 'Expansion & Wisdom',
      description: 'Jupiter expands your horizons, bringing opportunities for growth and abundance. '
          'This is an auspicious time for education, travel, and philosophical pursuits. '
          'Your optimism attracts good fortune. Trust in the universe\'s abundance. '
          'Legal matters and publishing are favored.',
      duration: 'Active for 12 months',
      affectedAreas: ['Growth', 'Luck', 'Wisdom'],
    ),
    'Saturn': _TransitData(
      icon: Icons.architecture,
      color: Color(0xFF8B7355),
      title: 'Saturn in Transit',
      subtitle: 'Structure & Discipline',
      description: 'Saturn calls for responsibility, patience, and long-term planning. '
          'This transit tests your foundations and rewards dedicated effort. '
          'Focus on building sustainable structures in your life. '
          'Lessons learned now will serve you for years to come.',
      duration: 'Active for 2.5 years',
      affectedAreas: ['Career', 'Discipline', 'Maturity'],
    ),
  };

  Widget _buildPlanetaryRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ACTIVE TRANSITS',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            Text(
              'Tap for details',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary.withOpacity(0.6),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSmall),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _activePlanets.map((planet) {
            final transitData = _transitDetails[planet];
            final icon = transitData?.icon ?? Icons.circle;
            final color = transitData?.color ?? AppColors.textSecondary;

            return _TransitCircle(
              planet: planet,
              icon: icon,
              color: color,
              onTap: () {
                HapticFeedback.lightImpact();
                if (transitData != null) {
                  _showTransitDetails(context, transitData);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Show glassmorphism bottom sheet with transit details
  void _showTransitDetails(BuildContext context, _TransitData transit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _TransitDetailsSheet(transit: transit),
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

// =============================================================================
// TRANSIT DATA MODEL
// =============================================================================

class _TransitData {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String description;
  final String duration;
  final List<String> affectedAreas;

  const _TransitData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.duration,
    required this.affectedAreas,
  });
}

// =============================================================================
// TRANSIT CIRCLE WIDGET (Interactive)
// =============================================================================

class _TransitCircle extends StatefulWidget {
  final String planet;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TransitCircle({
    required this.planet,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_TransitCircle> createState() => _TransitCircleState();
}

class _TransitCircleState extends State<_TransitCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.15),
            border: Border.all(color: widget.color.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TRANSIT DETAILS BOTTOM SHEET (Glassmorphism)
// =============================================================================

class _TransitDetailsSheet extends StatelessWidget {
  final _TransitData transit;

  const _TransitDetailsSheet({required this.transit});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A0A2E).withOpacity(0.98),
            const Color(0xFF0D0620).withOpacity(0.98),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: transit.color.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: transit.color.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ),

                // Header: Icon + Title
                _buildHeader(),

                const SizedBox(height: 24),

                // Description Card
                _buildDescriptionCard(),

                const SizedBox(height: 20),

                // Affected Areas
                _buildAffectedAreas(),

                const SizedBox(height: 20),

                // Duration Footer
                _buildDurationFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Glowing Icon
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                transit.color.withOpacity(0.3),
                transit.color.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: transit.color.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: transit.color.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            transit.icon,
            color: transit.color,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        // Title & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transit.title,
                style: AppTypography.headlineSmall.copyWith(
                  color: transit.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                transit.subtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: transit.color.withOpacity(0.8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Today\'s Energy',
                style: AppTypography.labelMedium.copyWith(
                  color: transit.color,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            transit.description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAffectedAreas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AREAS OF INFLUENCE',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: transit.affectedAreas.map((area) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    transit.color.withOpacity(0.2),
                    transit.color.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: transit.color.withOpacity(0.3),
                ),
              ),
              child: Text(
                area,
                style: AppTypography.labelMedium.copyWith(
                  color: transit.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDurationFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: transit.color.withOpacity(0.1),
        border: Border.all(
          color: transit.color.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule,
            color: transit.color.withOpacity(0.8),
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            transit.duration,
            style: AppTypography.bodyMedium.copyWith(
              color: transit.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
