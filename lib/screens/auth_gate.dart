import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  String? _savedUsername;
  String? _savedPassword;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _savedUsername = prefs.getString('auth_username');
      _savedPassword = prefs.getString('auth_password');
      _isLoading = false;
    });
  }

  Future<void> _onAuthenticated({
    required String username,
    required String password,
    required bool isFirstSetup,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_username', username);
    await prefs.setString('auth_password', password);
    if (!mounted) {
      return;
    }
    setState(() {
      _savedUsername = username;
      _savedPassword = password;
    });
    if (isFirstSetup && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credenciales guardadas correctamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SizedBox.expand(
          child: Image(
            image: AssetImage('assets/img/pantalla-carga-traveling.png'),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final bool isFirstSetup = _savedUsername == null || _savedPassword == null;
    return LoginPage(
      savedUsername: _savedUsername,
      savedPassword: _savedPassword,
      onAuthenticated: _onAuthenticated,
      isFirstSetup: isFirstSetup,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.savedUsername,
    required this.savedPassword,
    required this.isFirstSetup,
    required this.onAuthenticated,
  });

  final String? savedUsername;
  final String? savedPassword;
  final bool isFirstSetup;
  final Future<void> Function({
    required String username,
    required String password,
    required bool isFirstSetup,
  }) onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.savedUsername ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();

    if (widget.isFirstSetup) {
      if (username.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes ingresar usuario y contraseña.')),
        );
        return;
      }
      await widget.onAuthenticated(
        username: username,
        password: password,
        isFirstSetup: true,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MyHomePage(title: 'Traveling App', transportistaName: username),
        ),
      );
      return;
    }

    if (password != widget.savedPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña incorrecta.')),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MyHomePage(
          title: 'Traveling App',
          transportistaName: widget.savedUsername ?? username,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1020), Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 14,
                  shadowColor: Colors.black45,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/img/traveling-logo.png',
                          height: 64,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Bienvenido a Traveling',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.isFirstSetup
                              ? 'Configura tus credenciales para empezar.'
                              : 'Ingresa tu contraseña para continuar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _usernameController,
                          enabled: widget.isFirstSetup,
                          decoration: InputDecoration(
                            labelText: 'Usuario',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _isPasswordVisible ? 'Ocultar contraseña' : 'Mostrar contraseña',
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              ),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _handleLogin,
                          icon: const Icon(Icons.login),
                          label: Text(widget.isFirstSetup ? 'Guardar e ingresar' : 'Ingresar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
