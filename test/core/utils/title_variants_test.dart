import 'package:diegema/core/utils/title_variants.dart';
import 'package:diegema/domain/models/audiobook.dart';
import 'package:flutter_test/flutter_test.dart';

UnifiedAudiobook _b(String id, String title) => UnifiedAudiobook(
      id: id,
      title: title,
      author: 'A',
      description: '',
    );

void main() {
  test('splits the six real titles', () {
    expect(splitTitleVariant('The Happy Prince and Other Tales'), (
      base: 'The Happy Prince and Other Tales',
      label: null,
    ));
    expect(splitTitleVariant('The Happy Prince and Other Tales, Version 2'), (
      base: 'The Happy Prince and Other Tales',
      label: 'Version 2',
    ));
    expect(splitTitleVariant('The Happy Prince and Other Tales (version 5)'), (
      base: 'The Happy Prince and Other Tales',
      label: 'Version 5',
    ));
    expect(splitTitleVariant('Short Science Fiction Collection Vol. 001'), (
      base: 'Short Science Fiction Collection',
      label: 'Vol. 001',
    ));
    expect(splitTitleVariant('Short Science Fiction Collection 032'), (
      base: 'Short Science Fiction Collection',
      label: 'Vol. 032',
    ));
    expect(splitTitleVariant('Short Science Fiction Collection 041'), (
      base: 'Short Science Fiction Collection',
      label: 'Vol. 041',
    ));
  });

  test('other forms, case-insensitively', () {
    expect(splitTitleVariant('Dune VERSION 3').label, 'Version 3');
    expect(splitTitleVariant('Dune, Volume 2'), (
      base: 'Dune',
      label: 'Volume 2',
    ));
    expect(splitTitleVariant('Dune vol 4').label, 'Vol. 4');
  });

  test('non-matching titles are not split', () {
    for (final t in [
      'Twenty Thousand Leagues Under the Sea',
      '1984',
      'Version 2',
      'Revolver 5',
      'Fahrenheit 451',
    ]) {
      expect(splitTitleVariant(t), (base: t, label: null), reason: t);
    }
  });

  test('labels only books that share a base; unique titles are absent', () {
    final m = libraryVariantLabels([
      _b('1', 'The Happy Prince and Other Tales'),
      _b('2', 'the happy prince and other tales, Version 2'),
      _b('3', 'Short Science Fiction Collection 032'),
      _b('4', 'Short Science Fiction Collection 041'),
      _b('5', '1984'),
      _b('6', 'Lonely, Version 2'),
    ]);
    expect(m, {
      '1': 'Original',
      '2': 'Version 2',
      '3': 'Vol. 032',
      '4': 'Vol. 041',
    });
  });

  test('identical unsuffixed copies get no label', () {
    expect(libraryVariantLabels([_b('1', 'Emma'), _b('2', 'Emma')]), isEmpty);
  });
}
