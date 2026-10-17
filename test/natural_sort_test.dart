import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/core/utils/file_utils.dart';

void main() {
  group('Natural Sort Order Tests', () {
    test('numeric names sort naturally', () {
      final list = ['10', '2', '1', '3', '4-5', '6'];
      list.sort((a, b) => FileUtils.naturalCompare(a, b));
      expect(list, ['1', '2', '3', '4-5', '6', '10']);
    });

    test('names with text and numbers sort naturally', () {
      final list = ['file 10', 'file 2', 'file 1', 'file 3', 'file 4-5', 'file 6'];
      list.sort((a, b) => FileUtils.naturalCompare(a, b));
      expect(list, ['file 1', 'file 2', 'file 3', 'file 4-5', 'file 6', 'file 10']);
    });

    test('Arabic names with numbers sort naturally', () {
      final list = ['ملف 10', 'ملف 2', 'ملف 1', 'ملف 3', 'ملف 4_5', 'ملف 6'];
      list.sort((a, b) => FileUtils.naturalCompare(a, b));
      expect(list, ['ملف 1', 'ملف 2', 'ملف 3', 'ملف 4_5', 'ملف 6', 'ملف 10']);
    });

    test('different prefix sort by number first', () {
      final list = ['b 2', 'a 10', 'a 2'];
      list.sort((a, b) => FileUtils.naturalCompare(a, b));
      expect(list, ['a 2', 'b 2', 'a 10']);
    });

    test('real-world complex bracket/metadata cases', () {
      final list = [
        '[@MangaMaster33] 685-687 (2)',
        '[@MangaMaster33]61',
        '62', // represent 62.pdf
        '[@MangaMaster33] 733-735',
        '[@MangaMaster33]659',
        '[@MangaMaster33] 653-654',
        '[@MangaMaster33]  669',
      ];
      list.sort((a, b) => FileUtils.naturalCompare(a, b, folderName: 'MangaMaster33'));
      expect(list, [
        '[@MangaMaster33]61',
        '62',
        '[@MangaMaster33] 653-654',
        '[@MangaMaster33]659',
        '[@MangaMaster33]  669',
        '[@MangaMaster33] 685-687 (2)',
        '[@MangaMaster33] 733-735',
      ]);
    });

    test('folder name number noise filtering', () {
      final list = [
        '[@MangaMaster33] 653-654',
        '@MANGAMASTER33 652',
        '500',
      ];
      list.sort((a, b) => FileUtils.naturalCompare(a, b, folderName: 'MangaMaster33'));
      expect(list, [
        '500',
        '@MANGAMASTER33 652',
        '[@MangaMaster33] 653-654',
      ]);
    });
  });
}
