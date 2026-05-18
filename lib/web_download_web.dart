import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadImageWeb(List<int> bytes, String fileName) async {
  final base64Data = base64Encode(bytes);
  final dataUrl = 'data:image/png;base64,$base64Data';

  final anchor = html.AnchorElement(href: dataUrl)
    ..setAttribute('download', fileName)
    ..click();
    
  anchor.remove();
}