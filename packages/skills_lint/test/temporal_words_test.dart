// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'src/models/convention_violation.dart';
import 'src/models/source.dart';
import 'src/temporal_words.dart';

/// Runs the temporal-word detector and the style guide reader over small
/// inline inputs, which pins what each reports independently of the
/// package's contents.
void main() {
  group('temporalWordsFromStyleGuide', () {
    test('reads the quoted terms from the Temporal Words section only', () {
      const markdown = '''
# Style

## Temporal Words

Don't use them. Examples: "now", "No Longer", "used to".

What is "new" today won't be tomorrow.

---

## Other

Avoid "ignored".
''';
      expect(temporalWordsFromStyleGuide(markdown), {'now', 'no longer', 'used to', 'new'});
    });

    test('stops at the next heading and reads CRLF line endings', () {
      const markdown = '## Temporal Words\r\nExamples: "legacy".\r\n## Next\r\n"ignored"\r\n';
      expect(temporalWordsFromStyleGuide(markdown), {'legacy'});
    });

    test('returns an empty set without the section', () {
      expect(temporalWordsFromStyleGuide('## Other\n"legacy"\n'), isEmpty);
    });
  });

  group('findTemporalWords', () {
    const words = {'no longer', 'legacy'};

    test('reports whole words in line and doc comments, ignoring case', () {
      final source = Source.snippet('''
/// Handles the Legacy alias.
void main() {
  // This path no  longer exists.
  final int x = 1; // LEGACY value.
}
''');
      final List<ConventionViolation> violations = findTemporalWords(source, words);
      expect([for (final v in violations) v.line], [1, 3, 4]);
      expect(violations.first.problem, 'comment uses "Legacy"');
    });

    test('ignores strings, identifiers, and partial words', () {
      final source = Source.snippet('''
// A legacyish name and a nonlegacy flag.
const String legacy = 'no longer';
''');
      expect(findTemporalWords(source, words), isEmpty);
    });

    test('reports nothing for an empty word list', () {
      expect(findTemporalWords(Source.snippet('// legacy\n'), const {}), isEmpty);
    });
  });
}
