import 'dart:math';

const List<String> _gracyAlphabet = <String>[
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'J',
  'K',
  'L',
  'M',
  'N',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
];

String generateGracyId({Random? random}) {
  final Random rng = random ?? Random.secure();

  String block() {
    return List<String>.generate(
      4,
      (_) => _gracyAlphabet[rng.nextInt(_gracyAlphabet.length)],
    ).join();
  }

  return 'GR-${block()}-${block()}';
}
