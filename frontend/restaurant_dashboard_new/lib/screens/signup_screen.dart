import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/onboarding_service.dart';

class SignUpScreen extends StatefulWidget {
  static const routeName = '/signup';

  const SignUpScreen({super.key});
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _onboardingService = OnboardingService();

  String _name = '';
  String _address = '';
  String _phone = '';
  String _email = '';
    String _password = '';
  String _passwordConfirm = '';
  bool _isLoading = false;

  void _trySubmit() async {
    final isValid = _formKey.currentState?.validate();
    if (isValid != true) {
      return;
    }
    _formKey.currentState?.save();
    setState(() {
      _isLoading = true;
    });

    try {
            await _onboardingService.signUpRestaurant(
        name: _name,
        address: _address,
        phone: _phone,
        email: _email,
        username: _email, // Use email as username
        password: _password,
        password2: _passwordConfirm,
      );
      // Login after successful signup to get the auth token
      await Provider.of<AuthProvider>(context, listen: false).login(_email, _password);

      // Navigate to home screen or show success message
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home'); // Assuming '/home' route exists
    } catch (error) {
      // Show error dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('An Error Occurred!'),
          content: Text(error.toString()),
          actions: <Widget>[
            TextButton(
              child: Text('Okay'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            )
          ],
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Restaurant Signup')),
      body: Center(
        child: Card(
          margin: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      key: ValueKey('name'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(labelText: 'Restaurant Name'),
                      onSaved: (value) {
                        _name = value!;
                      },
                    ),
                    TextFormField(
                      key: ValueKey('address'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an address.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(labelText: 'Address'),
                      onSaved: (value) {
                        _address = value!;
                      },
                    ),
                    TextFormField(
                      key: ValueKey('phone'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a phone number.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                      onSaved: (value) {
                        _phone = value!;
                      },
                    ),
                    TextFormField(
                      key: ValueKey('email'),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Please enter a valid email address.';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: 'Email Address'),
                      onSaved: (value) {
                        _email = value!;
                      },
                    ),
                    TextFormField(
                      key: ValueKey('password'),
                      validator: (value) {
                        if (value == null || value.length < 7) {
                          return 'Password must be at least 7 characters long.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(labelText: 'Password'),
                      obscureText: true,
                                            onSaved: (value) {
                        _password = value!;
                      },
                    ),
                    TextFormField(
                      key: ValueKey('password_confirm'),
                      validator: (value) {
                        if (value != _password) {
                          return 'Passwords do not match!';
                        }
                        return null;
                      },
                      decoration: InputDecoration(labelText: 'Confirm Password'),
                      obscureText: true,
                      onSaved: (value) {
                        _passwordConfirm = value!;
                      },
                    ),
                    SizedBox(height: 12),
                    if (_isLoading)
                      CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: _trySubmit,
                        child: Text('Sign Up'),
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
