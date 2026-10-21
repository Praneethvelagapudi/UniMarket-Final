import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../config/campus_policy.dart';
import '../services/errors.dart';
import '../widgets/common.dart';
import '../widgets/logout_dialog.dart';
import 'shell_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return StreamBuilder<User?>(
      stream: app.auth.auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(body: ErrorState(error: snapshot.error!));
        }
        final user = snapshot.data;
        if (user == null) return const AuthScreen();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          key: ValueKey('profile-${user.uid}'),
          stream: app.auth.watchProfile(user.uid),
          builder: (context, profile) {
            if (profile.hasError) {
              return Scaffold(
                body: EmptyState(
                  icon: Icons.lock_outline,
                  title: 'Account setup needs attention',
                  body:
                      'Unable to read your campus profile. Check the Firebase rules and your connection.',
                  action: TextButton(
                    onPressed: () => confirmLogout(context),
                    child: const Text('Sign out'),
                  ),
                ),
              );
            }
            if (!profile.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!profile.data!.exists) {
              return const AuthScreen(profileOnly: true);
            }
            // Local writes appear before the server grants campus membership.
            // Wait for their acknowledgement before starting protected queries.
            if (profile.data!.metadata.hasPendingWrites) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Saving your campus profile…'),
                    ],
                  ),
                ),
              );
            }
            return ShellScreen(
              key: ValueKey(user.uid),
              profile: profile.data!.data()!,
            );
          },
        );
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  final bool profileOnly;
  const AuthScreen({super.key, this.profileOnly = false});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _roll = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _repeat = TextEditingController();
  bool _register = false, _busy = false, _obscure = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _register = widget.profileOnly;
  }

  @override
  void dispose() {
    for (final c in [_name, _roll, _email, _password, _repeat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = AppScope.of(context).auth;
      if (widget.profileOnly) {
        await auth.completeProfile(_name.text, _roll.text);
      } else if (_register) {
        await auth.register(
          _name.text,
          _roll.text,
          _email.text,
          _password.text,
        );
      } else {
        await auth.login(_email.text, _password.text);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final app = AppScope.of(context);
    final email = widget.profileOnly
        ? app.auth.auth.currentUser!.email
        : _email.text;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, size) => Row(
          children: [
            if (size.maxWidth >= 900)
              Expanded(
                child: Container(
                  color: const Color(0xFF164D3E),
                  padding: const EdgeInsets.all(60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        color: Color(0xFFDDEFAE),
                        size: 80,
                      ),
                      const SizedBox(height: 36),
                      const Text(
                        'Less spend.\nMore campus.',
                        style: TextStyle(
                          fontSize: 56,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Buy a textbook. Rent a lab kit.\nPass something useful to the next batch.',
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.6,
                          color: Color(0xFFD5E5DD),
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _AuthTag('Campus community'),
                          _AuthTag('Buy or rent'),
                          _AuthTag('Meet on campus'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(size.maxWidth < 500 ? 24 : 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 32,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'UniMarket',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          Text(
                            widget.profileOnly
                                ? 'Complete your profile'
                                : _register
                                ? 'Join your campus'
                                : 'Welcome back',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.profileOnly
                                ? 'Your account exists. Save your campus details to continue.'
                                : _register
                                ? 'A little less buying new. A lot more sharing.'
                                : 'Your next campus essential is waiting.',
                          ),
                          const SizedBox(height: 28),
                          if (_register) ...[
                            TextFormField(
                              controller: _name,
                              enabled: !_busy,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Your name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) =>
                                  v == null ||
                                      v.trim().length < 2 ||
                                      v.trim().length > 60
                                  ? 'Enter a name between 2 and 60 characters.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _roll,
                              enabled: !_busy,
                              decoration: const InputDecoration(
                                labelText: 'Campus roll number',
                                hintText: 'CB.SC.U4CSE24157',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: CampusPolicy.rollError,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (widget.profileOnly)
                            Text(email ?? '')
                          else ...[
                            TextFormField(
                              controller: _email,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Student email',
                                hintText: 'Your roll number @cb.students.edu',
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                              validator: (v) => CampusPolicy.emailError(
                                v,
                                roll: _register ? _roll.text : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _password,
                              enabled: !_busy,
                              obscureText: _obscure,
                              autofillHints: [
                                _register
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Enter your password.'
                                  : _register && v.length < 8
                                  ? 'Use at least 8 characters.'
                                  : null,
                              onFieldSubmitted: (_) => _busy ? null : _submit(),
                            ),
                            if (_register) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _repeat,
                                enabled: !_busy,
                                obscureText: _obscure,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                validator: (v) => v != _password.text
                                    ? 'Passwords do not match.'
                                    : null,
                              ),
                            ],
                          ],
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                _error!,
                                style: TextStyle(color: scheme.error),
                              ),
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: BusyButton(
                              busy: _busy,
                              onPressed: _submit,
                              label: widget.profileOnly
                                  ? 'Save campus profile'
                                  : _register
                                  ? 'Create account'
                                  : 'Enter campus market',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      if (widget.profileOnly) {
                                        confirmLogout(context);
                                      } else {
                                        setState(() {
                                          _register = !_register;
                                          _error = null;
                                          _form.currentState?.reset();
                                        });
                                      }
                                    },
                              child: Text(
                                widget.profileOnly
                                    ? 'Sign out'
                                    : _register
                                    ? 'Already a member? Sign in'
                                    : 'New here? Create an account',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'For CB.SC.U4 students · @cb.students.edu',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthTag extends StatelessWidget {
  final String text;
  const _AuthTag(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF679982)),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}
