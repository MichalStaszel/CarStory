/// Everything the narrator and the app say, per language, plus the words the
/// interpreter listens for. Add a language by adding one [Phrases] instance.
class Phrases {
  const Phrases({
    required this.lang,
    required this.speechLocale,
    required this.letters,
    required this.ordinals,
    required this.commands,
    required this.choicePattern,
    required this.whatDoYouDo,
    required this.listeningNudge,
    required this.repeatOptions,
    required this.pausedForSilence,
    required this.paused,
    required this.notUnderstood,
    required this.newClue,
    required this.youGet,
    required this.cluesIntro,
    required this.noClues,
    required this.itemsIntro,
    required this.noItems,
    required this.backToStory,
    required this.resumeIntro,
    required this.endOutro,
    required this.quitOutro,
  });

  final String lang;

  /// Locale id for speech recognition and TTS, e.g. `en-US`.
  final String speechLocale;

  /// Spoken forms of the option letters, as the recognizer tends to write them.
  final Map<String, List<String>> letters;
  final Map<String, RegExp> ordinals;
  final Map<VoiceCommand, RegExp> commands;

  /// Matches "option b", "I choose c" and similar, capturing the letter.
  final RegExp choicePattern;

  final String whatDoYouDo;
  final String listeningNudge;
  final String repeatOptions;
  final String pausedForSilence;
  final String paused;
  final String notUnderstood;
  final String newClue;
  final String youGet;
  final String cluesIntro;
  final String noClues;
  final String itemsIntro;
  final String noItems;
  final String backToStory;
  final String resumeIntro;
  final String endOutro;
  final String quitOutro;

  static Phrases forLang(String lang) => lang == 'pl' ? polish : english;

  static final english = Phrases(
    lang: 'en',
    speechLocale: 'en-US',
    letters: const {
      'A': ['a', 'ay', 'eh', 'hey', 'aye'],
      'B': ['b', 'be', 'bee', 'bea'],
      'C': ['c', 'see', 'sea', 'si', 'cee', 'she'],
    },
    ordinals: {
      'A': RegExp(r'^(first|one|1)$'),
      'B': RegExp(r'^(second|two|2)$'),
      'C': RegExp(r'^(third|three|3)$'),
    },
    commands: {
      VoiceCommand.repeat: RegExp(r'\b(repeat|say (that|it) again|again please|what was that|come again)\b'),
      VoiceCommand.clues: RegExp(r'\b(clues?|notes?|what do i know|evidence)\b'),
      VoiceCommand.items: RegExp(r'\b(items?|inventory|what do i have|my stuff)\b'),
      VoiceCommand.pause: RegExp(r'^(pause|stop|hold on|wait a (minute|second))\b'),
      VoiceCommand.quit: RegExp(r'\b(quit|end (the )?(game|story|session)|exit)\b'),
    },
    choicePattern: RegExp(r'\b(?:option|choice|letter|answer|choose|pick|go with)\s+(a|b|c|be|bee|see|sea|cee)\b'),
    whatDoYouDo: 'What do you do?',
    listeningNudge: "I'm listening. Say A, B, or C, or just tell me what you do.",
    repeatOptions: "Here are your options again.",
    pausedForSilence: "I'll pause the story here. Say something or tap the screen when you're ready.",
    paused: 'Paused. Tap the screen when you want to continue.',
    notUnderstood: "I didn't quite catch that.",
    newClue: 'New clue:',
    youGet: 'You now have:',
    cluesIntro: 'Your clues.',
    noClues: "You don't have any clues yet.",
    itemsIntro: "You're carrying:",
    noItems: "You aren't carrying anything interesting.",
    backToStory: 'Back to the story.',
    resumeIntro: 'Back to {title}. Last time:',
    endOutro: 'Case closed. When you stop, open the case file in the app to see your clues, items, and your character.',
    quitOutro: 'Progress saved. See you on the road.',
  );

  static final polish = Phrases(
    lang: 'pl',
    speechLocale: 'pl-PL',
    letters: const {
      'A': ['a', 'ah', 'aa', 'ha'],
      'B': ['b', 'be', 'bee', 'bi', 'bje'],
      'C': ['c', 'ce', 'cee', 'tse', 'cy', 'ci', 'se', 'sie'],
    },
    ordinals: {
      'A': RegExp(r'^(pierwsz\w*|jeden|jedynk\w*)$'),
      'B': RegExp(r'^(drug\w*|dwa|dwojk\w*)$'),
      'C': RegExp(r'^(trzec\w*|trzy|trojk\w*)$'),
    },
    commands: {
      VoiceCommand.repeat: RegExp(r'(powtorz|jeszcze raz|nie uslysz|nie doslysz)'),
      VoiceCommand.clues: RegExp(r'(wskazowk|notatk|co wiem|poszlak)'),
      VoiceCommand.items: RegExp(r'(przedmiot|ekwipunek|co mam przy sobie|inwentarz)'),
      VoiceCommand.pause: RegExp(r'^(pauza|stop|zatrzymaj|wstrzymaj|przerwa)'),
      VoiceCommand.quit: RegExp(r'(zakoncz|koniec gry|wyjdz z gry|konczymy)'),
    },
    choicePattern: RegExp(r'\b(?:opcj\w*|wybieram|odpowiedz|litera|wariant)\s+(a|b|c|be|ce|cee|tse)\b'),
    whatDoYouDo: 'Co robisz?',
    listeningNudge: 'Słucham. Powiedz A, B albo C, albo po prostu, co robisz.',
    repeatOptions: 'Przypomnę opcje.',
    pausedForSilence: 'Wstrzymuję opowieść. Powiedz coś albo dotknij ekranu, kiedy zechcesz wrócić.',
    paused: 'Pauza. Dotknij ekranu, kiedy zechcesz wrócić.',
    notUnderstood: 'Nie do końca rozumiem.',
    newClue: 'Nowa wskazówka:',
    youGet: 'Zdobywasz:',
    cluesIntro: 'Twoje wskazówki.',
    noClues: 'Nie masz jeszcze żadnych wskazówek.',
    itemsIntro: 'Masz przy sobie:',
    noItems: 'Nie masz przy sobie nic ciekawego.',
    backToStory: 'Wracamy.',
    resumeIntro: 'Wracamy do opowieści {title}. Ostatnio:',
    endOutro: 'Sprawa zamknięta. Kiedy się zatrzymasz, zajrzyj do teczki śledztwa w aplikacji.',
    quitOutro: 'Zapisuję postęp. Do usłyszenia w drodze.',
  );
}

enum VoiceCommand { repeat, clues, items, pause, quit }
