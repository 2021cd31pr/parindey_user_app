import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  final List<Map<String, String>> faqs = const [
    {
      'question': 'How do I track my active order?',
      'answer': 'You can track your order live on the Home screen or by tapping "Orders" in your account profile.'
    },
    {
      'question': 'Can I cancel my order after placing it?',
      'answer': 'Orders can be cancelled within 60 seconds of placing. Please contact customer support immediately for assistance.'
    },
    {
      'question': 'What are the available payment methods?',
      'answer': 'We support UPI (GPay, PhonePe, Paytm), Credit/Debit cards, and Cash on Delivery.'
    },
    {
      'question': 'How do I contact customer support?',
      'answer': 'Call our 24/7 hotline at +91 1800-123-4567 or email support@parindey.com.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Support Call Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFfc8019),
                  child: Icon(Icons.headset_mic, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('24/7 Customer Care', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 2),
                      Text('+91 1800-123-4567 • support@parindey.com', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFfc8019),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calling customer support...')),
                    );
                  },
                  child: const Text('CALL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('FREQUENTLY ASKED QUESTIONS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          ...faqs.map((faq) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              color: Colors.white,
              child: ExpansionTile(
                title: Text(faq['question']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(faq['answer']!, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
