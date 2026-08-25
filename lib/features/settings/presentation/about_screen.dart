import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/audio/sfx.dart';
import '../../../core/audio/sfx_player.dart';
import '../../../core/feedback/haptics.dart';
import '../../../core/settings/settings_controller.dart';

/// ===========================================================================
/// Developer identity, social links and support/payment details.
///
/// This is the single place to edit before shipping — nothing else in this
/// file needs to change when updating a link or payment detail.
/// ===========================================================================
abstract final class DeveloperInfo {
  static const String name = 'MD. Asif-Ur-Rahman Abir';
  static const String role = 'Flutter & Game Developer';
  static const String tagline = 'Building PlayBits, one mini-game at a time.';

  // ---- Social / contact links --------------------------------------------
  static const String whatsappNumber = '8801877348044';
  static String get whatsappUrl =>
      'https://wa.me/$whatsappNumber?text=${Uri.encodeComponent('Hi Abir, I found your app on PlayBits!')}';

  static const String portfolioUrl = 'https://abirdev.com';

  // ---- Buy Me A Coffee (in-app: pick a coffee, then pay via bKash/bank) --
  // Standard prices in BDT (৳). Edit freely — the picker reads this list.
  static const List<CoffeeOption> coffeeOptions = [
    CoffeeOption(label: 'Hot Coffee', icon: Icons.local_cafe_rounded, price: 150),
    CoffeeOption(label: 'Cold Coffee', icon: Icons.icecream_rounded, price: 300),
    CoffeeOption(label: 'Latte', icon: Icons.coffee_rounded, price: 400),
    CoffeeOption(label: 'Cappuccino', icon: Icons.emoji_food_beverage_rounded, price: 500),
    CoffeeOption(label: 'Others', icon: Icons.edit_rounded, price: 0, isCustom: true),
  ];

  // ---- Business / agency (full Web + App + E-commerce + SaaS builds) -----
  static const String agencyName = 'AmiSysX';
  static const String agencyTagline =
      'Need a full app or system built? Web, App, E-Commerce or SaaS — any kind.';
  static const String agencyWebsite = 'https://amisysx.com/';
  static const String agencyFacebook = 'https://fb.com/amisysx';
  static const String agencyLinkedIn = 'https://linkedin.com/company/amisysx';
  static const String agencyWhatsappNumber = '8801920780034';
  static String get agencyWhatsappUrl =>
      'https://wa.me/$agencyWhatsappNumber?text=${Uri.encodeComponent('Hi, I want to discuss a project.')}';

  // ---- Payment details ----------------------------------------------------
  static const String bkashNumber = '01877348044';
  static const String bkashLabel = 'bKash (Send Money)';
  static const String bkashNote = 'Bangladesh only';

  static const String bankAccountNumber = '1060806840001';
  static const String bankAccountName = 'MD.ASIF-UR-RAHMAN ABIR';
  static const String bankName = 'BRAC Bank PLC';
  static const String bankBranch = 'DAKHIN KHAN SUB BRANCH';
  static const String bankRoutingNumber = '060260914';
  static const String bankSwiftCode = 'BRAKBDDH';
  static const String bankNote = 'Bangladesh & international transfers (USD)';
}

/// A single "buy me a coffee" tier. [isCustom] means the person types their
/// own amount instead of picking [price].
class CoffeeOption {
  const CoffeeOption({
    required this.label,
    required this.icon,
    required this.price,
    this.isCustom = false,
  });

  final String label;
  final IconData icon;
  final int price;
  final bool isCustom;
}

// ===========================================================================
// Palette — kept local so this screen can be dropped into any project
// without pulling in a game-specific config file.
// ===========================================================================
abstract final class _Palette {
  static const Color navyDeep = Color(0xFF060A11);
  static const Color navy = Color(0xFF0B1220);
  static const Color bg = Color(0xFF0A0E17);
  static const Color coral = Color(0xFFFF6B4A);
  static const Color gold = Color(0xFFFFC94A);
  static const Color teal = Color(0xFF0EC9B0);
  static const Color violet = Color(0xFF9B59F6);
  static const Color whatsapp = Color(0xFF25D366);
  static const Color coffee = Color(0xFFFFDD00);
  static const Color bkash = Color(0xFFE2136E);
  static const Color bank = Color(0xFF1E88E5);
}

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _Palette.bg,
      body: Stack(
        children: [
          const _AboutBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          children: [
                            const _DeveloperHeader(),
                            const SizedBox(height: 30),
                            const _SectionLabel('CONNECT'),
                            _LinkTile(
                              icon: Icons.chat_rounded,
                              iconColor: _Palette.whatsapp,
                              title: 'WhatsApp',
                              subtitle: 'Chat directly with the developer',
                              onTap: () => _openLink(context, ref, DeveloperInfo.whatsappUrl),
                            ),
                            const SizedBox(height: 12),
                            _LinkTile(
                              icon: Icons.public_rounded,
                              iconColor: _Palette.teal,
                              title: 'Portfolio',
                              subtitle: 'See more projects and work',
                              onTap: () => _openLink(context, ref, DeveloperInfo.portfolioUrl),
                            ),
                            const SizedBox(height: 12),
                            _LinkTile(
                              icon: Icons.coffee_rounded,
                              iconColor: _Palette.coffee,
                              title: 'Buy Me A Coffee',
                              subtitle: 'Pick a coffee, pay by bKash or bank',
                              onTap: () => _openCoffeeSheet(context, ref),
                            ),
                            const SizedBox(height: 30),
                            const _SectionLabel('NEED SOMETHING BUILT?'),
                            _AgencyCard(
                              onWebsite: () => _openLink(context, ref, DeveloperInfo.agencyWebsite),
                              onFacebook: () => _openLink(context, ref, DeveloperInfo.agencyFacebook),
                              onLinkedIn: () => _openLink(context, ref, DeveloperInfo.agencyLinkedIn),
                              onWhatsapp: () => _openLink(context, ref, DeveloperInfo.agencyWhatsappUrl),
                            ),
                            const SizedBox(height: 30),
                            const _SectionLabel('SUPPORT THE DEVELOPER'),
                            const _SupportIntro(),
                            const SizedBox(height: 14),
                            _PaymentCard(
                              icon: Icons.payments_rounded,
                              accent: _Palette.bkash,
                              title: DeveloperInfo.bkashLabel,
                              badge: DeveloperInfo.bkashNote,
                              rows: [
                                _PaymentRow(label: 'Number', value: DeveloperInfo.bkashNumber),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _PaymentCard(
                              icon: Icons.account_balance_rounded,
                              accent: _Palette.bank,
                              title: 'Bank Transfer',
                              badge: DeveloperInfo.bankNote,
                              rows: [
                                _PaymentRow(label: 'Account Number', value: DeveloperInfo.bankAccountNumber),
                                _PaymentRow(label: 'Account Name', value: DeveloperInfo.bankAccountName),
                                _PaymentRow(label: 'Bank Name', value: DeveloperInfo.bankName),
                                _PaymentRow(label: 'Branch Name', value: DeveloperInfo.bankBranch),
                                _PaymentRow(label: 'Routing Number', value: DeveloperInfo.bankRoutingNumber),
                                _PaymentRow(label: 'SWIFT Code', value: DeveloperInfo.bankSwiftCode),
                              ],
                            ),
                            const SizedBox(height: 34),
                            const _Footer(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCoffeeSheet(BuildContext context, WidgetRef ref) async {
    final sound = ref.read(settingsControllerProvider).soundEnabled;
    final haptics = ref.read(settingsControllerProvider).hapticsEnabled;
    ref.read(sfxPlayerProvider).play(Sfx.tap, enabled: sound);
    AppHaptics.selection(haptics);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CoffeeSheet(),
    );
  }

  Future<void> _openLink(BuildContext context, WidgetRef ref, String rawUrl) async {
    final sound = ref.read(settingsControllerProvider).soundEnabled;
    final haptics = ref.read(settingsControllerProvider).hapticsEnabled;
    ref.read(sfxPlayerProvider).play(Sfx.tap, enabled: sound);
    AppHaptics.selection(haptics);

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        _showSnack(context, "Couldn't open that link.");
      }
    } catch (_) {
      if (context.mounted) _showSnack(context, "Couldn't open that link.");
    }
  }

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// ===========================================================================
// Background — mirrors the hub's layered gradient + soft color blobs so the
// screen feels native to the rest of PlayBits.
// ===========================================================================

class _AboutBackground extends StatelessWidget {
  const _AboutBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_Palette.navyDeep, Color(0xFF141B2B), _Palette.navy],
            ),
          ),
        ),
        Positioned(top: -70, left: -60, child: _Glow(color: _Palette.coral, size: 220)),
        Positioned(top: 140, right: -80, child: _Glow(color: _Palette.teal, size: 240)),
        Positioned(bottom: -60, left: 20, child: _Glow(color: _Palette.violet, size: 260)),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.24), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

// ===========================================================================
// Header — avatar, name, role and tagline
// ===========================================================================

class _DeveloperHeader extends StatefulWidget {
  const _DeveloperHeader();

  @override
  State<_DeveloperHeader> createState() => _DeveloperHeaderState();
}

class _DeveloperHeaderState extends State<_DeveloperHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _bounce,
          builder: (context, child) {
            final lift = math.sin(_bounce.value * math.pi) * 5;
            return Transform.translate(offset: Offset(0, -lift), child: child);
          },
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_Palette.gold, _Palette.coral]),
              boxShadow: [
                BoxShadow(color: _Palette.coral.withValues(alpha: 0.45), blurRadius: 40, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.sports_esports_rounded, size: 50, color: Colors.white),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          DeveloperInfo.name,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.3),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Text(
            DeveloperInfo.role.toUpperCase(),
            style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          DeveloperInfo.tagline,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}

// ===========================================================================
// Shared chrome
// ===========================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 12)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ===========================================================================
// Link tile — WhatsApp / Portfolio / Buy Me A Coffee
// ===========================================================================

class _LinkTile extends StatefulWidget {
  const _LinkTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_LinkTile> createState() => _LinkTileState();
}

class _LinkTileState extends State<_LinkTile> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.98),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: _GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.iconColor.withValues(alpha: 0.16),
                  border: Border.all(color: widget.iconColor.withValues(alpha: 0.4)),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(widget.subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Agency card — AmiSysX (full Web / App / E-commerce / SaaS builds)
// ===========================================================================

class _AgencyCard extends StatelessWidget {
  const _AgencyCard({
    required this.onWebsite,
    required this.onFacebook,
    required this.onLinkedIn,
    required this.onWhatsapp,
  });

  final VoidCallback onWebsite;
  final VoidCallback onFacebook;
  final VoidCallback onLinkedIn;
  final VoidCallback onWhatsapp;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_Palette.violet, _Palette.teal]),
                  boxShadow: [BoxShadow(color: _Palette.violet.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 1)],
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  DeveloperInfo.agencyName,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            DeveloperInfo.agencyTagline,
            style: TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AgencyChip(icon: Icons.language_rounded, label: 'Website', color: _Palette.teal, onTap: onWebsite),
              _AgencyChip(icon: Icons.facebook_rounded, label: 'Facebook', color: const Color(0xFF1877F2), onTap: onFacebook),
              _AgencyChip(icon: Icons.business_center_rounded, label: 'LinkedIn', color: const Color(0xFF0A66C2), onTap: onLinkedIn),
              _AgencyChip(icon: Icons.chat_rounded, label: 'WhatsApp', color: _Palette.whatsapp, onTap: onWhatsapp),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgencyChip extends StatefulWidget {
  const _AgencyChip({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_AgencyChip> createState() => _AgencyChipState();
}

class _AgencyChipState extends State<_AgencyChip> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: widget.color),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Coffee sheet — pick a coffee tier, then pay via bKash or bank
// ===========================================================================

class _CoffeeSheet extends StatefulWidget {
  const _CoffeeSheet();

  @override
  State<_CoffeeSheet> createState() => _CoffeeSheetState();
}

class _CoffeeSheetState extends State<_CoffeeSheet> {
  CoffeeOption? _selected;
  int _amount = 0;
  final TextEditingController _customController = TextEditingController();
  String? _customError;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _pick(CoffeeOption option) {
    HapticFeedback.selectionClick();
    if (option.isCustom) {
      setState(() => _selected = option);
      return;
    }
    setState(() {
      _selected = option;
      _amount = option.price;
    });
  }

  void _confirmCustomAmount() {
    final parsed = int.tryParse(_customController.text.trim());
    if (parsed == null || parsed <= 0) {
      setState(() => _customError = 'Enter a valid amount');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _amount = parsed;
      _customError = null;
    });
  }

  void _reset() {
    setState(() {
      _selected = null;
      _amount = 0;
      _customError = null;
      _customController.clear();
    });
  }

  bool get _showPayment => _selected != null && _amount > 0;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF141B2B), _Palette.navyDeep],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _showPayment
                              ? _CoffeePaymentStep(
                            key: const ValueKey('payment'),
                            coffee: _selected!,
                            amount: _amount,
                            onChangeCoffee: _reset,
                          )
                              : _CoffeePickStep(
                            key: const ValueKey('pick'),
                            selected: _selected,
                            customController: _customController,
                            customError: _customError,
                            onPick: _pick,
                            onConfirmCustom: _confirmCustomAmount,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoffeePickStep extends StatelessWidget {
  const _CoffeePickStep({
    super.key,
    required this.selected,
    required this.customController,
    required this.customError,
    required this.onPick,
    required this.onConfirmCustom,
  });

  final CoffeeOption? selected;
  final TextEditingController customController;
  final String? customError;
  final ValueChanged<CoffeeOption> onPick;
  final VoidCallback onConfirmCustom;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_Palette.coffee, _Palette.coral]),
              ),
              child: const Icon(Icons.coffee_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Buy Me A Coffee', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Pick a size — you\'ll get bKash and bank details for that amount next.',
          style: TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 18),
        ...DeveloperInfo.coffeeOptions.map((option) {
          final isSelected = selected?.label == option.label;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CoffeeOptionTile(option: option, selected: isSelected, onTap: () => onPick(option)),
          );
        }),
        if (selected?.isCustom == true) ...[
          const SizedBox(height: 4),
          _GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Text('৳', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: customController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter amount',
                      hintStyle: TextStyle(color: Colors.white30),
                      isDense: true,
                    ),
                    onSubmitted: (_) => onConfirmCustom(),
                  ),
                ),
                _PrimaryPillButton(label: 'CONTINUE', onTap: onConfirmCustom),
              ],
            ),
          ),
          if (customError != null) ...[
            const SizedBox(height: 8),
            Text(customError!, style: const TextStyle(color: _Palette.coral, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ],
      ],
    );
  }
}

class _CoffeeOptionTile extends StatelessWidget {
  const _CoffeeOptionTile({required this.option, required this.selected, required this.onTap});
  final CoffeeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? _Palette.coffee.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _Palette.coffee.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _Palette.coffee.withValues(alpha: 0.18),
              ),
              child: Icon(option.icon, size: 19, color: _Palette.coffee),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(option.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5)),
            ),
            Text(
              option.isCustom ? 'CUSTOM' : '৳${option.price}',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoffeePaymentStep extends StatelessWidget {
  const _CoffeePaymentStep({
    super.key,
    required this.coffee,
    required this.amount,
    required this.onChangeCoffee,
  });

  final CoffeeOption coffee;
  final int amount;
  final VoidCallback onChangeCoffee;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onChangeCoffee,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sending ৳$amount for a ${coffee.isCustom ? 'coffee' : coffee.label}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.only(left: 42),
          child: Text(
            'Thank you! Tap any field below to copy it.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        const SizedBox(height: 18),
        _PaymentCard(
          icon: Icons.payments_rounded,
          accent: _Palette.bkash,
          title: DeveloperInfo.bkashLabel,
          badge: DeveloperInfo.bkashNote,
          rows: [
            _PaymentRow(label: 'Amount to Send', value: '৳$amount'),
            _PaymentRow(label: 'Number', value: DeveloperInfo.bkashNumber),
          ],
        ),
        const SizedBox(height: 14),
        _PaymentCard(
          icon: Icons.account_balance_rounded,
          accent: _Palette.bank,
          title: 'Bank Transfer',
          badge: DeveloperInfo.bankNote,
          rows: [
            _PaymentRow(label: 'Amount to Send', value: '৳$amount'),
            _PaymentRow(label: 'Account Number', value: DeveloperInfo.bankAccountNumber),
            _PaymentRow(label: 'Account Name', value: DeveloperInfo.bankAccountName),
            _PaymentRow(label: 'Bank Name', value: DeveloperInfo.bankName),
            _PaymentRow(label: 'Branch Name', value: DeveloperInfo.bankBranch),
            _PaymentRow(label: 'Routing Number', value: DeveloperInfo.bankRoutingNumber),
            _PaymentRow(label: 'SWIFT Code', value: DeveloperInfo.bankSwiftCode),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: _PrimaryPillButton(
            label: 'DONE',
            onTap: () => Navigator.of(context).maybePop(),
            expand: true,
          ),
        ),
      ],
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  const _PrimaryPillButton({required this.label, required this.onTap, this.expand = false});
  final String label;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: expand ? 18 : 16, vertical: expand ? 14 : 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_Palette.coral, _Palette.gold]),
          borderRadius: BorderRadius.circular(expand ? 16 : 12),
          boxShadow: [BoxShadow(color: _Palette.coral.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: expand ? 14 : 11, letterSpacing: 0.6),
        ),
      ),
    );
  }
}

// ===========================================================================
// Support intro copy
// ===========================================================================

class _SupportIntro extends StatelessWidget {
  const _SupportIntro();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 4, right: 4, bottom: 4),
      child: Text(
        'If you enjoy PlayBits, sending a small tip helps fund more games, '
            'levels and updates. Tap any field below to copy it.',
        style: TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.5),
      ),
    );
  }
}

// ===========================================================================
// Payment card — bKash / Bank transfer, each field copyable
// ===========================================================================

class _PaymentRow {
  const _PaymentRow({required this.label, required this.value});
  final String label;
  final String value;
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.badge,
    required this.rows,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String badge;
  final List<_PaymentRow> rows;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [accent, Color.lerp(accent, Colors.black, 0.25)!]),
                  boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 16, spreadRadius: 1)],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(rows.length, (i) {
            final row = rows[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 8),
              child: _CopyableField(label: row.label, value: row.value, accent: accent),
            );
          }),
        ],
      ),
    );
  }
}

class _CopyableField extends StatefulWidget {
  const _CopyableField({required this.label, required this.value, required this.accent});
  final String label;
  final String value;
  final Color accent;

  @override
  State<_CopyableField> createState() => _CopyableFieldState();
}

class _CopyableFieldState extends State<_CopyableField> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${widget.label} copied'), duration: const Duration(milliseconds: 1200)));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _copy,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label.toUpperCase(),
                    style: const TextStyle(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.value,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                _copied ? Icons.check_circle_rounded : Icons.copy_rounded,
                key: ValueKey(_copied),
                size: 18,
                color: _copied ? widget.accent : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Footer
// ===========================================================================

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Made with', style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(width: 6),
            const Icon(Icons.favorite_rounded, color: _Palette.coral, size: 14),
            const SizedBox(width: 6),
            Text(
              'using Flutter & Flame',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('Thank you for playing PlayBits!', style: TextStyle(color: Colors.white24, fontSize: 11)),
        const SizedBox(height: 4),
        const Text('abirdev.com  •  amisysx.com', style: TextStyle(color: Colors.white24, fontSize: 10.5)),
      ],
    );
  }
}