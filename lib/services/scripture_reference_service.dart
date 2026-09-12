/// Offline Bible reference suggestions for Spiritual Growth.
///
/// Christianity topics resolve to 3–5 relevant Bible references (KJV wording,
/// public domain) so the form works without network access. Other faith paths
/// return an empty list — the UI hides the Bible reference helper then.
class ScriptureReference {
  final String reference;
  final String text;

  const ScriptureReference({required this.reference, required this.text});

  String get formatted => '$reference — $text';
}

class ScriptureReferenceService {
  const ScriptureReferenceService();

  /// Returns 3–5 Bible references for [topic] when [faithPath] is Christian.
  /// Returns an empty list for other faith paths.
  List<ScriptureReference> forTopic(String topic, {String? faithPath}) {
    final faith = (faithPath ?? '').toLowerCase();
    final isChristian = faith.contains('christ');
    if (!isChristian) return const <ScriptureReference>[];

    final t = topic.toLowerCase();

    if (_containsAny(t, const ['gratitude', 'thank', 'appreciat'])) {
      return const <ScriptureReference>[
        ScriptureReference(
          reference: '1 Thessalonians 5:18',
          text: 'In every thing give thanks.',
        ),
        ScriptureReference(
          reference: 'Psalm 107:1',
          text: 'O give thanks unto the LORD, for he is good.',
        ),
        ScriptureReference(
          reference: 'Colossians 3:17',
          text: 'Do all in the name of the Lord Jesus, giving thanks.',
        ),
        ScriptureReference(
          reference: 'Psalm 100:4',
          text: 'Enter into his gates with thanksgiving.',
        ),
      ];
    }

    if (_containsAny(t, const ['patience', 'waiting', 'persever', 'endur'])) {
      return const <ScriptureReference>[
        ScriptureReference(
          reference: 'Romans 12:12',
          text: 'Patient in tribulation; continuing instant in prayer.',
        ),
        ScriptureReference(
          reference: 'James 1:4',
          text: 'Let patience have her perfect work.',
        ),
        ScriptureReference(
          reference: 'Galatians 6:9',
          text: 'In due season we shall reap, if we faint not.',
        ),
        ScriptureReference(
          reference: 'Isaiah 40:31',
          text: 'They that wait upon the LORD shall renew their strength.',
        ),
      ];
    }

    if (_containsAny(t, const [
      'anxiet',
      'anxious',
      'worry',
      'fear',
      'afraid',
      'stress',
      'trouble',
    ])) {
      return const <ScriptureReference>[
        ScriptureReference(
          reference: 'Philippians 4:6',
          text: 'Be careful for nothing; but in every thing by prayer.',
        ),
        ScriptureReference(
          reference: '1 Peter 5:7',
          text: 'Casting all your care upon him; for he careth for you.',
        ),
        ScriptureReference(
          reference: 'Isaiah 41:10',
          text: 'Fear thou not; for I am with thee.',
        ),
        ScriptureReference(
          reference: 'John 14:27',
          text: 'Let not your heart be troubled, neither let it be afraid.',
        ),
        ScriptureReference(
          reference: 'Psalm 56:3',
          text: 'What time I am afraid, I will trust in thee.',
        ),
      ];
    }

    if (_containsAny(t, const [
      'strength',
      'courage',
      'brave',
      'weak',
      'tired',
      'weary',
    ])) {
      return const <ScriptureReference>[
        ScriptureReference(
          reference: 'Philippians 4:13',
          text: 'I can do all things through Christ which strengtheneth me.',
        ),
        ScriptureReference(
          reference: 'Isaiah 40:31',
          text: 'They that wait upon the LORD shall renew their strength.',
        ),
        ScriptureReference(
          reference: 'Joshua 1:9',
          text: 'Be strong and of a good courage.',
        ),
        ScriptureReference(
          reference: 'Psalm 46:1',
          text: 'God is our refuge and strength.',
        ),
      ];
    }

    if (_containsAny(t, const ['love', 'kindness', 'compassion'])) {
      return const <ScriptureReference>[
        ScriptureReference(
          reference: '1 Corinthians 13:4',
          text: 'Charity suffereth long, and is kind.',
        ),
        ScriptureReference(
          reference: '1 John 4:8',
          text: 'God is love.',
        ),
        ScriptureReference(
          reference: 'John 15:12',
          text: 'Love one another, as I have loved you.',
        ),
        ScriptureReference(
          reference: 'Colossians 3:14',
          text: 'Above all these things put on charity.',
        ),
      ];
    }

    if (_containsAny(t, const [
      'forgiv',
      'mercy',
      'grace',
      'repent',
      'sorry',
    ])) {
      return const <ScriptureReference>[
        ScriptureReference(
          reference: '1 John 1:9',
          text: 'He is faithful and just to forgive us our sins.',
        ),
        ScriptureReference(
          reference: 'Ephesians 4:32',
          text: 'Forgiving one another, even as God hath forgiven you.',
        ),
        ScriptureReference(
          reference: 'Psalm 103:12',
          text: 'As far as the east is from the west, hath he removed our sins.',
        ),
        ScriptureReference(
          reference: 'Micah 7:18',
          text: 'He delighteth in mercy.',
        ),
      ];
    }

    if (_containsAny(t, const ['hope', 'future', 'despair', 'discourag'])) {
      return const <ScriptureReference>[
        ScriptureReference(
          reference: 'Jeremiah 29:11',
          text: 'Thoughts of peace, and not of evil, to give you an expected end.',
        ),
        ScriptureReference(
          reference: 'Romans 15:13',
          text: 'The God of hope fill you with all joy and peace.',
        ),
        ScriptureReference(
          reference: 'Psalm 42:11',
          text: 'Hope thou in God.',
        ),
        ScriptureReference(
          reference: 'Hebrews 11:1',
          text: 'Faith is the substance of things hoped for.',
        ),
      ];
    }

    if (_containsAny(t, const [
      'peace',
      'rest',
      'calm',
      'still',
      'quiet',
      'sabbath',
    ])) {
      return const <ScriptureReference>[
        ScriptureReference(
          reference: 'John 14:27',
          text: 'Peace I leave with you, my peace I give unto you.',
        ),
        ScriptureReference(
          reference: 'Philippians 4:7',
          text: 'The peace of God, which passeth all understanding.',
        ),
        ScriptureReference(
          reference: 'Matthew 11:28',
          text: 'Come unto me, and I will give you rest.',
        ),
        ScriptureReference(
          reference: 'Psalm 23:2',
          text: 'He leadeth me beside the still waters.',
        ),
      ];
    }

    if (_containsAny(t, const [
      'faith',
      'trust',
      'believe',
      'doubt',
    ])) {
      return const <ScriptureReference>[
        ScriptureReference(
          reference: 'Hebrews 11:1',
          text: 'Faith is the substance of things hoped for.',
        ),
        ScriptureReference(
          reference: 'Proverbs 3:5',
          text: 'Trust in the LORD with all thine heart.',
        ),
        ScriptureReference(
          reference: 'Mark 11:24',
          text: 'What things soever ye desire, when ye pray, believe.',
        ),
        ScriptureReference(
          reference: 'Romans 10:17',
          text: 'Faith cometh by hearing, and hearing by the word of God.',
        ),
      ];
    }

    if (_containsAny(t, const [
      'heal',
      'comfort',
      'grief',
      'loss',
      'mourn',
      'sick',
    ])) {
      return const <ScriptureReference>[
        ScriptureReference(
          reference: 'Psalm 34:18',
          text: 'The LORD is nigh unto them that are of a broken heart.',
        ),
        ScriptureReference(
          reference: 'Matthew 5:4',
          text: 'Blessed are they that mourn: for they shall be comforted.',
        ),
        ScriptureReference(
          reference: '2 Corinthians 1:4',
          text: 'Who comforteth us in all our tribulation.',
        ),
        ScriptureReference(
          reference: 'Psalm 147:3',
          text: 'He healeth the broken in heart, and bindeth up their wounds.',
        ),
      ];
    }

    if (_containsAny(t, const [
      'wisdom',
      'guid',
      'decis',
      'direction',
      'understand',
      'discern',
    ])) {
      return const <ScriptureReference>[
        ScriptureReference(
          reference: 'James 1:5',
          text: 'If any of you lack wisdom, let him ask of God.',
        ),
        ScriptureReference(
          reference: 'Proverbs 3:5-6',
          text: 'Trust in the LORD; and he shall direct thy paths.',
        ),
        ScriptureReference(
          reference: 'Psalm 119:105',
          text: 'Thy word is a lamp unto my feet, and a light unto my path.',
        ),
        ScriptureReference(
          reference: 'Isaiah 30:21',
          text: 'This is the way, walk ye in it.',
        ),
      ];
    }

    if (_containsAny(t, const ['joy', 'rejoic', 'happy', 'glad'])) {
      return const <ScriptureReference>[
        ScriptureReference(
          reference: 'Philippians 4:4',
          text: 'Rejoice in the Lord alway.',
        ),
        ScriptureReference(
          reference: 'Nehemiah 8:10',
          text: 'The joy of the LORD is your strength.',
        ),
        ScriptureReference(
          reference: 'Psalm 118:24',
          text: 'This is the day which the LORD hath made; we will rejoice.',
        ),
        ScriptureReference(
          reference: 'Romans 12:12',
          text: 'Rejoicing in hope; patient in tribulation.',
        ),
      ];
    }

    if (_containsAny(t, const [
      'prayer',
      'pray',
      'meditat',
      'worship',
      'fast',
      'devotion',
    ])) {
      return const <ScriptureReference>[
        ScriptureReference(
          reference: '1 Thessalonians 5:17',
          text: 'Pray without ceasing.',
        ),
        ScriptureReference(
          reference: 'Matthew 6:6',
          text: 'Pray to thy Father which is in secret.',
        ),
        ScriptureReference(
          reference: 'Psalm 1:2',
          text: 'In his law doth he meditate day and night.',
        ),
        ScriptureReference(
          reference: 'John 4:24',
          text: 'Worship him in spirit and in truth.',
        ),
      ];
    }

    // General fallback: well-known encouragements covering daily life.
    return const <ScriptureReference>[
      ScriptureReference(
        reference: 'Jeremiah 29:11',
        text: 'Thoughts of peace, to give you an expected end.',
      ),
      ScriptureReference(
        reference: 'Philippians 4:13',
        text: 'I can do all things through Christ which strengtheneth me.',
      ),
      ScriptureReference(
        reference: 'Romans 8:28',
        text: 'All things work together for good to them that love God.',
      ),
      ScriptureReference(
        reference: 'Psalm 23:1',
        text: 'The LORD is my shepherd; I shall not want.',
      ),
      ScriptureReference(
        reference: 'Proverbs 3:5',
        text: 'Trust in the LORD with all thine heart.',
      ),
    ];
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}
