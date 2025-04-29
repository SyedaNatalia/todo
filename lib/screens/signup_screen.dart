import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _isPasswordVisible = false;
  String _selectedRole = 'Employee';
  final List<String> _roles = ['Manager', 'Employee', 'Intern', 'Team Lead'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.clearRegisterFields();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF5D6EFF),
              Color(0xFF9DCEFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              _buildBackgroundBubbles(),
              Positioned(
                top: 20,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              _buildRegistrationForm(authProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm(AuthProvider authProvider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: authProvider.signupFormKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create Account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter your details to create a new account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 40),
              _buildNameField(authProvider.firstNameController, 'First Name', Icons.person_outline, authProvider.validateName),
              const SizedBox(height: 16),
              _buildNameField(authProvider.lastNameController, 'Last Name', Icons.person_outline, authProvider.validateName),
              const SizedBox(height: 16),
              _buildEmailField(authProvider),
              const SizedBox(height: 16),
              _buildPasswordField(authProvider),
              const SizedBox(height: 16),
              _buildRoleDropdown(),
              const SizedBox(height: 16),
              _buildErrorMessage(authProvider),
              const SizedBox(height: 16),
              _buildSignUpButton(authProvider),
              const SizedBox(height: 24),
              _buildLoginPrompt(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField(TextEditingController controller, String hintText, IconData prefixIcon, String? Function(String?) validator) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(prefixIcon, color: Colors.white70),
        fillColor: Colors.white.withOpacity(0.2),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildEmailField(AuthProvider authProvider) {
    return TextFormField(
      controller: authProvider.emailController,
      keyboardType: TextInputType.emailAddress,
      validator: authProvider.validateEmail,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Email',
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
        fillColor: Colors.white.withOpacity(0.2),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildPasswordField(AuthProvider authProvider) {
    return TextFormField(
      controller: authProvider.passwordController,
      obscureText: !_isPasswordVisible,
      validator: authProvider.validatePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Password',
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.white54,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        fillColor: Colors.white.withOpacity(0.2),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedRole,
        dropdownColor: const Color(0xFF5D6EFF),
        onChanged: (String? newValue) {
          setState(() {
            _selectedRole = newValue!;
          });
        },
        items: _roles.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        decoration: InputDecoration(
          hintText: 'Select Role',
          hintStyle: const TextStyle(color: Colors.white70),
          prefixIcon: const Icon(Icons.work_outline, color: Colors.white70),
          fillColor: Colors.transparent,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(AuthProvider authProvider) {
    if (authProvider.errorMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        authProvider.errorMessage!,
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSignUpButton(AuthProvider authProvider) {
    return ElevatedButton(
      onPressed: authProvider.isLoading ? null : () => _handleSignUp(authProvider),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: authProvider.isLoading
          ? const CircularProgressIndicator(color: Color(0xFF5D6EFF))
          : const Text(
        'Sign Up',
        style: TextStyle(
          color: Color(0xFF5D6EFF),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Already have an account? ",
          style: TextStyle(color: Colors.white70),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
          child: const Text(
            'Login',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundBubbles() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                top: -50,
                left: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                right: -50,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleSignUp(AuthProvider authProvider) async {
    if (!authProvider.signupFormKey.currentState!.validate()) return;

    final userData = {
      'firstName': authProvider.firstNameController.text.trim(),
      'lastName': authProvider.lastNameController.text.trim(),
      'role': _selectedRole,
    };

    final success = await authProvider.signUp(
      authProvider.emailController.text.trim(),
      authProvider.passwordController.text,
      userData,
    );

    if (success && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }
}
