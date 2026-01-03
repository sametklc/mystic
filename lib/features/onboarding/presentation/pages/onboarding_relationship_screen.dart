import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/widgets/widgets.dart';

/// Relationship status options for onboarding.
enum RelationshipStatus {
  single,
  inRelationship,
  complicated,
  married,
  healing,
  seeking;

  String get label {
    switch (this) {
      case RelationshipStatus.single:
        return 'Single';
      case RelationshipStatus.inRelationship:
        return 'In Relationship';
      case RelationshipStatus.complicated:
        return 'Complicated';
      case RelationshipStatus.married:
        return 'Married';
      case RelationshipStatus.healing:
        return 'Healing';
      case RelationshipStatus.seeking:
        return 'Seeking';
    }
  }

  IconData get icon {
    switch (this) {
      case RelationshipStatus.single:
        return Icons.person;
      case RelationshipStatus.inRelationship:
        return Icons.favorite;
      case RelationshipStatus.complicated:
        return Icons.psychology;
      case RelationshipStatus.married:
        return Icons.favorite_border;
      case RelationshipStatus.healing:
        return Icons.spa;
      case RelationshipStatus.seeking:
        return Icons.search_rounded;
    }
  }

  String get description {
    switch (this) {
      case RelationshipStatus.single:
        return 'On my own path';
      case RelationshipStatus.inRelationship:
        return 'Growing together';
      case RelationshipStatus.complicated:
        return 'Cosmic crossroads';
      case RelationshipStatus.married:
        return 'Bonded by stars';
      case RelationshipStatus.healing:
        return 'Mending my heart';
      case RelationshipStatus.seeking:
        return 'Looking for love';
    }
  }
}

class OnboardingRelationshipScreen extends ConsumerStatefulWidget {
  final void Function(RelationshipStatus status)? onComplete;
  final int currentStep;
  final int totalSteps;

  const OnboardingRelationshipScreen({
    super.key,
    this.onComplete,
    this.currentStep = 2,
    this.totalSteps = 4,
  });

  @override
  ConsumerState<OnboardingRelationshipScreen> createState() =>
      _OnboardingRelationshipScreenState();
}

class _OnboardingRelationshipScreenState
    extends ConsumerState<OnboardingRelationshipScreen> {
  RelationshipStatus? _selectedStatus;
  bool _showQuestion = false;
  bool _showCards = false;
  bool _showButton = false;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _startRitual();
  }

  Future<void> _startRitual() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _showQuestion = true);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _showCards = true);
  }

  void _onStatusSelected(RelationshipStatus status) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedStatus = status;
      if (!_showButton) _showButton = true;
    });
  }

  Future<void> _onContinue() async {
    if (_selectedStatus == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _isExiting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    widget.onComplete?.call(_selectedStatus!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: MysticBackgroundScaffold(
        child: SafeArea(
          // Alt kısımda butonun kendi padding'ini kullanacağız, o yüzden bottom: false
          bottom: false,
          child: Column(
            children: [
              // 1. ÜST KISIM (Header)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingLarge,
                  vertical: 16,
                ),
                child: MysticProgressBar(
                  totalSteps: widget.totalSteps,
                  currentStep: widget.currentStep,
                ),
              ),

              // 2. ORTA KISIM (Scrollable Content)
              // Expanded kullanıyoruz ki kalan tüm alanı kaplasın.
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingLarge,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Soru
                      _buildQuestion(),

                      const SizedBox(height: 32),

                      // Kartlar
                      if (_showCards) _buildStatusCards(),

                      // En altta biraz boşluk bırakalım ki liste bitince hemen kesilmesin
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // 3. ALT KISIM (Sabit Buton Alanı)
              // Burası scrollview'in dışında, en altta çakılı duracak.
              _buildBottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    if (!_showQuestion) return const SizedBox(height: 60);

    Widget question = Column(
      children: [
        Text(
          'What is your\ncurrent chapter?',
          textAlign: TextAlign.center,
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.textPrimary,
            height: 1.2,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'This helps us guide your cosmic journey.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );

    question = question
        .animate()
        .fadeIn(duration: 800.ms, curve: Curves.easeOut)
        .slideY(begin: 0.2, end: 0, duration: 800.ms);

    if (_isExiting) {
      question = question.animate().fadeOut(duration: 400.ms).slideY(
        begin: 0,
        end: -0.2,
        duration: 400.ms,
      );
    }
    return question;
  }

  Widget _buildStatusCards() {
    Widget cards = GridView.count(
      crossAxisCount: 2,
      // 1.05 oranıyla kartlar ne çok uzun ne çok kısa, tam kareye yakın
      childAspectRatio: 1.05,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: RelationshipStatus.values.asMap().entries.map((entry) {
        final index = entry.key;
        final status = entry.value;
        return _StatusCard(
          status: status,
          isSelected: _selectedStatus == status,
          onTap: () => _onStatusSelected(status),
          animationDelay: Duration(milliseconds: index * 60),
        );
      }).toList(),
    );

    if (_isExiting) {
      cards = cards.animate().fadeOut(duration: 400.ms).slideY(
        begin: 0,
        end: 0.1,
        duration: 400.ms,
      );
    }
    return cards;
  }

  // Yeni Sabit Alt Bar
  Widget _buildBottomBar(BuildContext context) {
    // Eğer henüz seçim yapılmadıysa yer tutucu göster (animasyonla gelecek)
    if (!_showButton || _selectedStatus == null) {
      // Yine de alan kaplasın ki layout zıplamasın, ama görünmez olsun
      return Container(height: 100, color: Colors.transparent);
    }

    // Alt güvenli alan (iPhone home bar çubuğu için)
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    Widget bar = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 16),
      decoration: BoxDecoration(
        color: AppColors.background, // Arka plan rengi (şeffaflık yok)
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        boxShadow: [
          // Yukarı doğru hafif gölge
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _onContinue,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Continue Journey',
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                  letterSpacing: 1.0,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );

    bar = bar.animate().fadeIn(duration: 300.ms).slideY(
      begin: 1.0,
      end: 0,
      duration: 400.ms,
      curve: Curves.easeOutBack,
    );

    if (_isExiting) {
      bar = bar.animate().fadeOut(duration: 300.ms).slideY(end: 1.0);
    }

    return bar;
  }
}

/// Compact & Premium Vertical Totem Card
class _StatusCard extends StatelessWidget {
  final RelationshipStatus status;
  final bool isSelected;
  final VoidCallback onTap;
  final Duration animationDelay;

  const _StatusCard({
    required this.status,
    required this.isSelected,
    required this.onTap,
    required this.animationDelay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : Colors.white.withOpacity(0.03),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withOpacity(0.08),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 14,
              spreadRadius: 0,
            ),
          ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon Container
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                    ? RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.4),
                    Colors.transparent,
                  ],
                )
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.05),
              ),
              child: Icon(
                status.icon,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary.withOpacity(0.7),
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            // Title
            Text(
              status.label,
              textAlign: TextAlign.center,
              style: AppTypography.labelLarge.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            // Description
            Text(
              status.description,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.7)
                    : AppColors.textTertiary.withOpacity(0.5),
                fontSize: 10,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: animationDelay, duration: 400.ms)
        .scale(
      begin: const Offset(0.9, 0.9),
      end: const Offset(1.0, 1.0),
      delay: animationDelay,
      duration: 400.ms,
      curve: Curves.easeOutBack,
    );
  }
}