import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/onboarding_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'login_screen.dart';

class _IntroSlide {
  const _IntroSlide({
    required this.image,
    required this.kicker,
    required this.title,
    required this.body,
  });

  final String image;
  final String kicker;
  final String title;
  final String body;
}

const List<_IntroSlide> _slides = [
  _IntroSlide(
    image: 'assets/onboarding/discover.png',
    kicker: 'SWIPE TO DISCOVER',
    title: 'Find your next\nfavourite piece',
    body:
        'Flip through pre-loved finds picked for your style. Swipe right to save, left to pass.',
  ),
  _IntroSlide(
    image: 'assets/onboarding/offer.png',
    kicker: 'MAKE AN OFFER',
    title: 'Negotiate your\nkind of price',
    body:
        'Send a fair offer, chat with the seller and agree on a deal — then check out at that price.',
  ),
  _IntroSlide(
    image: 'assets/onboarding/impact.png',
    kicker: 'THRIFT WITH PURPOSE',
    title: 'Give clothes\na second life',
    body:
        'Buy, sell and rehome pre-loved pieces. One piece at a time, good clothes stay in circulation.',
  ),
];

/// First-launch intro. Shown once, then the app opens on Login (or straight
/// into the session if the user is already signed in).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await OnboardingService.markSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
              child: Row(
                children: [
                  const AppLogo(size: 40),
                  const Spacer(),
                  TextButton(
                    onPressed: _finishing ? null : _finish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _slide(_slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 22 : 7,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? AppColors.forest
                                : AppColors.line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _finishing ? null : _next,
                      child: Text(
                        _page == _slides.length - 1 ? 'Get started' : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slide(_IntroSlide slide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = (constraints.maxWidth - 56).clamp(220.0, 400.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Column(
            children: [
              Container(
                width: imageSize,
                height: imageSize,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.line),
                  boxShadow: AppColors.cardShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(slide.image, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                slide.kicker,
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: AppColors.clay,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                slide.body,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.45),
              ),
            ],
          ),
        );
      },
    );
  }
}
