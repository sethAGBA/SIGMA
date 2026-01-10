import 'package:afroforma/models/user.dart';
import 'package:afroforma/screen/main_screen.dart';
import 'package:afroforma/services/auth_service.dart';
import 'package:flutter/material.dart';

class Login2faScreen extends StatefulWidget {
  final User user;

  const Login2faScreen({Key? key, required this.user}) : super(key: key);

  @override
  _Login2faScreenState createState() => _Login2faScreenState();
}

class _Login2faScreenState extends State<Login2faScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  void _verifyCode() async {
    setState(() {
      _isLoading = true;
    });

    final isValid = await AuthService.verify2faCode(widget.user.id, _codeController.text);

    setState(() {
      _isLoading = false;
    });

    if (isValid) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code invalide. Veuillez réessayer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Vérification à deux facteurs',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Un code a été envoyé à votre application d\'authentification. Veuillez le saisir ci-dessous.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Code à 6 chiffres',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _verifyCode,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Vérifier'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
