// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'src/models/convention_violation.dart';
import 'src/models/source.dart';
import 'src/skip_reasons.dart';
import 'src/source_conventions.dart';
import 'src/temporal_words.dart';

/// Source conventions that reviewers enforce, checked across the package.
///
/// Each check runs a detector from `src/` over the package's Dart files.
/// `source_convention_detectors_test.dart`, `skip_reasons_test.dart` and
/// `temporal_words_test.dart` pin what each detector reports on small
/// snippets.
void main() {
  group('repository', () {
    late List<Source> sources;
    late Set<String> styleGuideTemporalWords;

    setUpAll(() {
      sources = parseDirectories(_scannedDirectories);
      styleGuideTemporalWords = temporalWordsFromStyleGuide(File(_styleGuide).readAsStringSync());
    });

    Iterable<Source> under(List<String> directories) =>
        sources.where((source) => directories.any((d) => source.path.startsWith('$d/')));

    test('map keys and indices under lib/src/models/ are not string literals', () {
      final List<ConventionViolation> violations = [];
      for (final Source source in under(const ['lib/src/models'])) {
        violations.addAll(findStringLiteralKeys(source));
      }
      expectNoViolations(violations, fix: _stringLiteralKeyFix);
    });

    test('no operator ==, hashCode, or toString overrides', () {
      final List<ConventionViolation> violations = [];
      for (final source in sources) {
        final Set<String> allowed = _allowedOverrides[source.path] ?? const {};
        violations.addAll(findForbiddenOverrides(source, allowed: allowed));
      }
      expectNoViolations(violations, fix: _forbiddenOverrideFix);
    });

    test('no constant in bin/ or lib/ is declared as an alias of another constant', () {
      expectNoViolations(findConstAliases(under(const ['bin', 'lib'])), fix: _constAliasFix);
    });

    test('every skip: in test/ gives its reason as a string', () {
      final List<ConventionViolation> violations = [
        for (final Source source in under(const ['test'])) ...findSkipsWithoutReason(source),
      ];
      expectNoViolations(violations, fix: _skipFix);
    });

    test('every testOn: in test/ has a comment in the call that names the platform', () {
      final List<ConventionViolation> violations = [
        for (final Source source in under(const ['test'])) ...findTestOnWithoutComment(source),
      ];
      expectNoViolations(violations, fix: _testOnFix);
    });

    test('the style guide lists every enforced temporal word', () {
      final List<String> missing = _enforcedTemporalWords
          .difference(styleGuideTemporalWords)
          .toList();
      expect(missing, isEmpty, reason: _missingTemporalWordFix);
    });

    test('comments in bin/, lib/ and test/ use no enforced temporal word', () {
      final Set<String> words = styleGuideTemporalWords.intersection(_enforcedTemporalWords);
      final List<ConventionViolation> violations = [
        for (final Source source in under(const ['bin', 'lib', 'test']))
          ...findTemporalWords(source, words),
      ];
      expectNoViolations(violations, fix: _temporalWordFix);
    });
  });
}

/// Directories whose Dart files the checks read.
///
/// `evals/test_data/` is left out because its Dart files are fixtures that
/// are written to fail review on purpose.
const List<String> _scannedDirectories = ['benchmark', 'bin', 'example', 'lib', 'test'];

/// Overrides that are allowed, keyed by package-relative path.
///
/// `ConfigSerializer` wraps a `StringBuffer`, and its `toString()` returns
/// the buffer contents in the same way `StringBuffer.toString()` does.
const Map<String, Set<String>> _allowedOverrides = {
  'lib/src/config_serializer.dart': {'toString'},
};

/// The style guide whose Temporal Words section defines the word list.
final String _styleGuide = p.join('documentation', 'knowledge', 'style_guide.md');

/// The temporal words that the comment check enforces.
///
/// A word is enforced only if the style guide's Temporal Words section also
/// lists it, so the style guide stays the one place that defines the list.
/// The guide's other words, such as "now", "new" and "old", are left to
/// review. They have too many false positives in comments, as in "a new
/// file" or "old and new values", and a check that fails on correct text
/// costs more than the wording it catches.
///
/// Add a word here once comments in bin/, lib/ and test/ use it only in its
/// temporal sense.
const Set<String> _enforcedTemporalWords = {
  'currently',
  'no longer',
  'used to',
  'previously',
  'originally',
  'legacy',
};

const String _stringLiteralKeyFix =
    'Declare the key as a `static const String` on the model class that owns '
    "it (for example `static const String keyStartLine = 'startLine';`) and "
    'use that constant wherever the key is read or written.';

/// Built from [_allowedOverrides] so the message and the allowlist agree.
final String _forbiddenOverrideFix = () {
  final List<String> allowed = [
    for (final MapEntry(key: path, value: names) in _allowedOverrides.entries)
      for (final name in names) '`$name()` in $path',
  ];
  return 'Remove the override. The only allowed overrides are ${allowed.join(', ')}.';
}();

const String _constAliasFix =
    'Delete the second constant and reference the original constant directly.';

const String _skipFix =
    'Pass the reason as the `skip:` string, so the test runner prints it next to '
    "the skipped test. For example: `skip: Platform.isWindows ? 'uses the POSIX "
    "chmod command' : null`.";

const String _testOnFix =
    'Add a comment inside the test call that names the excluded platform and says '
    'why the test cannot run there. For example: `// Skipped on Windows: the test '
    'removes permissions with the POSIX chmod command, which Windows does not provide.`';

final String _missingTemporalWordFix =
    'These words in _enforcedTemporalWords are not quoted in the Temporal Words '
    'section of $_styleGuide. Restore each word in the style guide, or, if the '
    'style guide dropped it on purpose, remove it from _enforcedTemporalWords. '
    'If every word is missing, the section heading or its quoting changed; '
    'temporalWordsFromStyleGuide in test/src/temporal_words.dart reads the '
    '"## Temporal Words" heading and the double-quoted terms under it.';

final String _temporalWordFix =
    'Rewrite each comment to describe the code as it is, without comparing it '
    'with another version. For example, write "the deprecated `--fix-apply` '
    'alias" instead of "the legacy `--fix-apply` alias". See the Temporal Words '
    'section of $_styleGuide for the reason.';
