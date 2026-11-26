/// On-screen text. Narration lives in engine/phrases.dart.
class UiStrings {
  const UiStrings._(this._m);
  final Map<String, String> _m;
  String operator [](String k) => _m[k] ?? k;

  static UiStrings of(String lang) => lang == 'pl' ? pl : en;

  static const en = UiStrings._({
    'app': 'Road Stories',
    'tagline': 'Interactive audiobooks for the drive. The narrator tells the story, you decide out loud.',
    'play': 'Play',
    'continue': 'Continue',
    'replay': 'Play again',
    'restart': 'Start over',
    'caseFile': 'Case file',
    'soon': 'Coming soon',
    'min': 'min',
    'solved': 'Solved',
    'howTo': 'Say "A", "B", "C", or just what you do. Voice commands: "repeat", "clues", "items", "faster", "slower", "pause", "quit". Works with the screen off and next to your navigation app.',
    'tapToStart': 'Tap to start. After that, voice only.',
    'start': 'Start',
    'narrator': 'Narrator',
    'tapToAnswer': 'Tap to skip and answer',
    'listening': 'Listening…',
    'sayOption': 'Say A, B, C, or what you do',
    'thinking': 'Thinking…',
    'paused': 'Paused',
    'tapToResume': 'Tap to resume',
    'pause': 'Pause',
    'end': 'End',
    'captions': 'Captions',
    'typeInstead': 'Type instead (when parked)',
    'send': 'Send',
    'heard': 'Heard',
    'noMic': 'Speech recognition is not available. Use typing when parked.',
    'progress': 'Progress',
    'checkpoints': 'Checkpoints',
    'clues': 'Clues',
    'items': 'Items',
    'noCluesYet': 'No clues. Yet.',
    'emptyPockets': 'Empty pockets.',
    'finished': 'Story complete.',
    'portraitNote': 'Your portrait changes with what you find.',
    'sessions': 'sessions',
    'caseClosed': 'CASE CLOSED',
    'backgroundNote': 'Story in progress. Keeps playing with the screen off.',
  });

  static const pl = UiStrings._({
    'app': 'Opowieści w drodze',
    'tagline': 'Interaktywne słuchowiska do auta. Narrator opowiada, Ty decydujesz głosem.',
    'play': 'Graj',
    'continue': 'Kontynuuj',
    'replay': 'Zagraj ponownie',
    'restart': 'Zacznij od nowa',
    'caseFile': 'Teczka śledztwa',
    'soon': 'Wkrótce',
    'min': 'min',
    'solved': 'Rozwiązana',
    'howTo': 'Mów „A”, „B”, „C” albo po prostu, co robisz. Komendy: „powtórz”, „wskazówki”, „przedmioty”, „szybciej”, „wolniej”, „pauza”, „zakończ”. Działa przy zgaszonym ekranie i obok nawigacji.',
    'tapToStart': 'Dotknij, aby zacząć. Potem już tylko głos.',
    'start': 'Start',
    'narrator': 'Narrator',
    'tapToAnswer': 'Dotknij, aby przerwać i odpowiedzieć',
    'listening': 'Słucham…',
    'sayOption': 'Powiedz A, B, C albo co robisz',
    'thinking': 'Myślę…',
    'paused': 'Pauza',
    'tapToResume': 'Dotknij, aby wznowić',
    'pause': 'Pauza',
    'end': 'Zakończ',
    'captions': 'Napisy',
    'typeInstead': 'Wpisz odpowiedź (na postoju)',
    'send': 'Wyślij',
    'heard': 'Słyszę',
    'noMic': 'Rozpoznawanie mowy niedostępne. Na postoju możesz pisać.',
    'progress': 'Postęp',
    'checkpoints': 'Punkty kontrolne',
    'clues': 'Wskazówki',
    'items': 'Przedmioty',
    'noCluesYet': 'Żadnych wskazówek. Jeszcze.',
    'emptyPockets': 'Puste kieszenie.',
    'finished': 'Historia ukończona.',
    'portraitNote': 'Portret zmienia się z tym, co zdobędziesz.',
    'sessions': 'sesje',
    'caseClosed': 'SPRAWA ZAMKNIĘTA',
    'backgroundNote': 'Opowieść trwa. Gra dalej przy zgaszonym ekranie.',
  });
}

/// Upcoming stories shown as teasers in the library.
const comingSoon = {
  'en': [
    ('Last Fare', 'Thriller', 'A night cab, a passenger who knows your name, and a suitcase you must not open.'),
    ('The Keeper of Gull Point', 'Horror', 'A storm cuts the lighthouse off from shore. Someone knocks from the sea side.'),
    ('Isle of Fog', 'Adventure', 'An old map, a rented fishing boat, and an island no chart admits exists.'),
  ],
  'pl': [
    ('Ostatni kurs', 'Thriller', 'Nocna taksówka, pasażer, który zna twoje imię, i walizka, której nie wolno otworzyć.'),
    ('Latarnik z Rozewia', 'Groza', 'Sztorm odciął latarnię od lądu. Ktoś puka od strony morza.'),
    ('Wyprawa na Wyspę Mgieł', 'Przygoda', 'Stara mapa, wynajęty kuter i wyspa, której nie ma na żadnej mapie.'),
  ],
};
