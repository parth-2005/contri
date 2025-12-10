import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

/// Login Screen with Google Sign-In
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signInWithGoogle();
      // Navigation handled by router based on auth state
    } catch (e) {
      if (mounted) {
        // Show detailed error
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _signInWithGoogle,
            ),
          ),
        );
        
        // Also show dialog for more details
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign-In Failed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                const SizedBox(height: 16),
                const Text(
                  'Common issues:\n'
                  '• Google Sign-In not configured in Firebase Console\n'
                  '• SHA-1 fingerprint not added for Android\n'
                  '• Internet connection issues\n'
                  '• Firebase not initialized',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _signInWithGoogle();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo/Icon
              Icon(
                Icons.account_balance_wallet,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // App Name
              Text(
                'Contri',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),

              // Tagline
              Text(
                'Split expenses, not friendships',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
              ),
              const SizedBox(height: 48),

              // Features List
              _buildFeature(
                context,
                Icons.money_off,
                'Zero Cost',
                'No hidden charges or subscriptions',
              ),
              const SizedBox(height: 16),
              _buildFeature(
                context,
                Icons.offline_bolt,
                'Offline First',
                'Works without internet connection',
              ),
              const SizedBox(height: 16),
              _buildFeature(
                context,
                Icons.group,
                'Made for Flatmates',
                'Perfect for Indian roommate expenses',
              ),
              const SizedBox(height: 48),

              // Google Sign-In Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Image.asset(
                        'assets/google_logo.png',
                        height: 24,
                        width: 24,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.login),
                      ),
                label: Text(_isLoading ? 'Signing in...' : 'Continue with Google'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Privacy Note
              Text(
                'By signing in, you agree to our Terms & Privacy Policy',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
