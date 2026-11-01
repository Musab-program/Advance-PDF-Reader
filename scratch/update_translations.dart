import 'dart:io';

void main() {
  final file = File('lib/core/localization/app_translations.dart');
  var content = file.readAsStringSync();

  const enAdditions = '''
          'tool_available': 'Ready',
          'tool_coming_soon_badge': 'Coming Soon',
          'coming_soon_title': 'Feature in Development',
          'coming_soon_dialog_desc': 'This tool is currently in development and will be available in an upcoming update.',
          'got_it': 'Got it',
          'opening_gallery': 'Opening image...',
          'processing_image': 'Processing locally on device...',
          'retry': 'Retry',
          'cancel': 'Cancel',
          'desc_remove_bg': 'Cut logos, icons, and graphics with transparent PNG output',
          'desc_merge_pdf': 'Combine multiple PDF files into a single organized document',
          'desc_split_pdf': 'Extract specific pages or ranges into separate PDF files',
          'desc_img_to_pdf': 'Convert photos and documents into a clean PDF file',
          'desc_pdf_to_img': 'Export document pages as high-resolution images',
          'desc_extract_text': 'Extract text characters and copy directly from documents',
''';

  const arAdditions = '''
          'tool_available': 'متاحة الآن',
          'tool_coming_soon_badge': 'قريبًا',
          'coming_soon_title': 'أداة قيد التطوير',
          'coming_soon_dialog_desc': 'هذه الأداة قيد التطوير البرمجي حاليًا وستكون متاحة في التحديث القادم بدون أي اشتراك.',
          'got_it': 'حسنًا',
          'opening_gallery': 'جاري فتح الصورة...',
          'processing_image': 'جاري المعالجة محليًا على الجهاز...',
          'retry': 'إعادة المحاولة',
          'cancel': 'إلغاء',
          'desc_remove_bg': 'تفريغ خلفيات الشعارات والأيقونات والرسومات بصيغة PNG شفافة',
          'desc_merge_pdf': 'دمج عدة ملفات ومستندات في ملف واحد منظم',
          'desc_split_pdf': 'استخراج صفحات معينة أو تقسيم المستند لملفات مستقلة',
          'desc_img_to_pdf': 'تحويل الصور والوثائق إلى ملف PDF عالي الجودة',
          'desc_pdf_to_img': 'تصدير صفحات المستند كصور بجودة فائقة',
          'desc_extract_text': 'استخراج النصوص من المستندات ونسخها مباشرة',
''';

  content = content.replaceFirst(
    "'tool_coming_soon': 'This tool is coming in an upcoming update',",
    "'tool_coming_soon': 'This tool is coming in an upcoming update',\n$enAdditions",
  );

  content = content.replaceFirst(
    "'tool_coming_soon': 'هذه الأداة قادمة في تحديث قادم',",
    "'tool_coming_soon': 'هذه الأداة قادمة في تحديث قادم',\n$arAdditions",
  );

  file.writeAsStringSync(content);
  print('Translations updated successfully');
}
