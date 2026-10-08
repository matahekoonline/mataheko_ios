import 'package:flutter/material.dart';

/// Increase this value whenever the Terms of Use are materially changed.
const String kTermsVersion = '1.0';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _accepted = false;

  void _continue() {
    if (!_accepted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Use'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Mataheko Terms of Use',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Version 1.0',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Please read these terms before creating your account.',
                      style: TextStyle(fontSize: 16, height: 1.5),
                    ),
                    SizedBox(height: 20),
                    Text(
                      '1. Acceptable use',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Use Mataheko lawfully and respectfully. Do not use the app to post, request, or distribute fraudulent, abusive, threatening, unlawful, or misleading content.',
                      style: TextStyle(fontSize: 15, height: 1.55),
                    ),
                    SizedBox(height: 18),
                    Text(
                      '2. Account information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Provide information that is accurate and belongs to you. Keep your account credentials secure and do not impersonate another person or organization.',
                      style: TextStyle(fontSize: 15, height: 1.55),
                    ),
                    SizedBox(height: 18),
                    Text(
                      '3. Listings and services',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Listings, marketplace items, and service information must be genuine and comply with applicable laws. Mataheko may review or remove content that violates these rules.',
                      style: TextStyle(fontSize: 15, height: 1.55),
                    ),
                    SizedBox(height: 18),
                    Text(
                      '4. Community conduct',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Do not harass, threaten, scam, or deliberately mislead other users. Report content or users that appear to violate these rules.',
                      style: TextStyle(fontSize: 15, height: 1.55),
                    ),
                    SizedBox(height: 18),
                    Text(
                      '5. Changes to these terms',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'These terms may be updated when necessary. If a future version requires renewed acceptance, the app will ask you to review the updated terms.',
                      style: TextStyle(fontSize: 15, height: 1.55),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'By selecting “I agree”, you confirm that you have read and agree to these Terms of Use.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    offset: Offset(0, -2),
                    color: Colors.black12,
                  ),
                ],
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _accepted,
                    onChanged: (value) {
                      setState(() => _accepted = value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'I have read and agree to the Terms of Use.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _accepted ? _continue : null,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 13),
                        child: Text('I agree and continue'),
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
}
