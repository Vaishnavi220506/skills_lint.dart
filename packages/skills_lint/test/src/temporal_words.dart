// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Finds relative temporal words in Dart comments.
///
/// A comment that describes the code by comparing it with another version
/// stops being true once that version is forgotten. The style guide's
/// Temporal Words section gives the full reasoning and owns the word list.
library;

import 'package:analyzer/dart/ast/token.dart';

import 'models/convention_violation.dart';
import 'models/source.dart';

/// Returns the terms quoted in the `## Temporal Words` section of the style
/// guide [markdown], lowercased.
///
/// The section runs from its heading to the next `## ` heading or `---`
/// line. A term is any text between double quotes. Returns an empty set if
/// the heading is missing.
Set<String> temporalWordsFromStyleGuide(String markdown) {
  final List<String> lines = markdown.split(RegExp(r'\r?\n'));
  final int start = lines.indexWhere((line) => line.trim() == '## Temporal Words');
  if (start == -1) {
    return const {};
  }
  final Iterable<String> section = lines
      .skip(start + 1)
      .takeWhile((line) => !line.startsWith('## ') && line.trim() != '---');
  return {
    for (final line in section)
      for (final Match match in RegExp('"([^"]+)"').allMatches(line)) match[1]!.toLowerCase(),
  };
}

/// Reports each use of one of [words] in a comment in [source].
///
/// A word matches as a whole word, ignoring case. The spaces in a multi-word
/// term match any run of whitespace.
List<ConventionViolation> findTemporalWords(Source source, Set<String> words) {
  if (words.isEmpty) {
    return const [];
  }
  final String alternatives = words
      .map((word) => word.split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s+'))
      .join('|');
  final pattern = RegExp('\\b(?:$alternatives)\\b', caseSensitive: false);
  return [
    for (final Token comment in source.comments)
      for (final Match match in pattern.allMatches(comment.lexeme))
        source.violationAt(comment.offset + match.start, 'comment uses "${match[0]}"'),
  ];
}
