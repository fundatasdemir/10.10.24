import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:html/parser.dart' as parser;
import 'package:url_launcher/url_launcher.dart';

class Degisiklikler extends StatefulWidget {
  const Degisiklikler({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _DegisikliklerState createState() => _DegisikliklerState();
}

class _DegisikliklerState extends State<Degisiklikler> {
  List<String> degisikliklerInfo = [];
  Map<String, String> pdfLinks = {};

  @override
  void initState() {
    super.initState();
    fetchDegisikliklerInfo();
  }

  Future<void> fetchDegisikliklerInfo() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.kutso.org.tr/wp-json/wp/v2/pages/3655'));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          degisikliklerInfo = parseHtmlString(data['content']['rendered']);
        });
      } else {
        throw Exception(
            'Değişiklikler bilgileri yüklenemedi. HTTP ${response.statusCode}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Hata: $e');
    }
  }

  List<String> parseHtmlString(String htmlString) {
    final document = parser.parse(htmlString);
    document.querySelectorAll('style, script, link').forEach((element) {
      element.remove();
    });

    // PDF bağlantılarını bulma
    pdfLinks = {};
    final links = document.querySelectorAll('a[href]');
    for (var element in links) {
      final href = element.attributes['href'];
      final text = element.text.toLowerCase();
      if (href != null &&
          (href.endsWith('.pdf') ||
              text.contains('dilekçe') ||
              text.contains('genel kurul') ||
              text.contains('şirket genel kurul'))) {
        final fullUrl = Uri.parse(href).isAbsolute
            ? href
            : 'https://www.kutso.org.tr/$href';
        pdfLinks[text] = fullUrl;
      }
    }

    // HTML içeriğini satırlara ayırma
    List<String> lines =
        document.body?.text.split('\n').map((line) => line.trim()).toList() ??
            [];

    return lines
        .where((line) => line.isNotEmpty && !line.contains('reCAPTCHA'))
        .toList();
  }

  TextStyle _getTextStyle(String text) {
    // Başlıkları kırmızı yap
    if (text.length < 20 || text == text.toUpperCase()) {
      return const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color.fromARGB(255, 162, 16, 16),
      );
    }
    // PDF bağlantılarını mavi ve altı çizili yap
    else if (pdfLinks.keys.any((key) => text.toLowerCase().contains(key))) {
      return const TextStyle(
        fontSize: 16,
        color: Color.fromARGB(255, 162, 49, 49),
        decoration: TextDecoration.underline,
      );
    }
    // Diğer metinler için standart stil
    else {
      return const TextStyle(
        fontSize: 16,
        color: Colors.black,
      );
    }
  }

  Future<void> _onTextTap(String text) async {
    final url = pdfLinks.entries
        .firstWhere(
          (entry) => text.toLowerCase().contains(entry.key),
          orElse: () => const MapEntry('', ''),
        )
        .value;

    if (url.isNotEmpty) {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch $url';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Değişiklikler'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: degisikliklerInfo.map((info) {
              final isClickable =
                  pdfLinks.keys.any((key) => info.toLowerCase().contains(key));
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: GestureDetector(
                  onTap: () => isClickable ? _onTextTap(info) : null,
                  child: Text(
                    info,
                    style: _getTextStyle(info),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}