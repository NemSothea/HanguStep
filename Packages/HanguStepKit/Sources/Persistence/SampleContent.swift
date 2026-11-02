import Domain
import Foundation

/// Development dataset shipped as a `ContentPackage`. Real content arrives through
/// the JSON importer in Phase 7; bump `version` whenever this changes.
public enum SampleContent {
    public static let version = 1

    public static let source = ContentSource(
        origin: .curated,
        name: "HanguStep sample content",
        license: "CC BY 4.0"
    )

    public static var package: ContentPackage {
        ContentPackage(version: version, vocabulary: vocabulary, grammar: grammar, questions: questions)
    }

    private static func word(
        _ number: Int, _ hangul: String, _ romanization: String, hanja: String? = nil,
        _ pos: PartOfSpeech, _ level: TOPIKLevel, _ category: String,
        en: String, km: String, exampleKo: String, exampleEn: String, exampleKm: String
    ) -> VocabularyItem {
        VocabularyItem(
            id: VocabularyID(String(format: "vocab.sample.%04d", number)),
            hangul: hangul, romanization: romanization, hanja: hanja,
            partOfSpeech: pos, level: level, category: category,
            meaning: Gloss(english: en, khmer: km),
            examples: [ExampleSentence(korean: exampleKo, translation: Gloss(english: exampleEn, khmer: exampleKm))],
            source: source, contentVersion: version
        )
    }

    public static let vocabulary: [VocabularyItem] = [
        word(1, "학교", "hakgyo", hanja: "學校", .noun, .level1, "school",
             en: "school", km: "សាលារៀន",
             exampleKo: "저는 학교에 가요.", exampleEn: "I go to school.", exampleKm: "ខ្ញុំទៅសាលារៀន។"),
        word(2, "친구", "chingu", hanja: "親舊", .noun, .level1, "people",
             en: "friend", km: "មិត្តភក្តិ",
             exampleKo: "친구를 만나요.", exampleEn: "I meet a friend.", exampleKm: "ខ្ញុំជួបមិត្តភក្តិ។"),
        word(3, "물", "mul", .noun, .level1, "food",
             en: "water", km: "ទឹក",
             exampleKo: "물을 마셔요.", exampleEn: "I drink water.", exampleKm: "ខ្ញុំផឹកទឹក។"),
        word(4, "책", "chaek", hanja: "冊", .noun, .level1, "school",
             en: "book", km: "សៀវភៅ",
             exampleKo: "책을 읽어요.", exampleEn: "I read a book.", exampleKm: "ខ្ញុំអានសៀវភៅ។"),
        word(5, "선생님", "seonsaengnim", hanja: "先生님", .noun, .level1, "people",
             en: "teacher", km: "គ្រូ",
             exampleKo: "선생님이 친절해요.", exampleEn: "The teacher is kind.", exampleKm: "គ្រូមានចិត្តល្អ។"),
        word(6, "가다", "gada", .verb, .level1, "movement",
             en: "to go", km: "ទៅ",
             exampleKo: "집에 가요.", exampleEn: "I go home.", exampleKm: "ខ្ញុំទៅផ្ទះ។"),
        word(7, "먹다", "meokda", .verb, .level1, "food",
             en: "to eat", km: "ញ៉ាំ",
             exampleKo: "밥을 먹어요.", exampleEn: "I eat rice.", exampleKm: "ខ្ញុំញ៉ាំបាយ។"),
        word(8, "크다", "keuda", .adjective, .level1, "description",
             en: "to be big", km: "ធំ",
             exampleKo: "집이 커요.", exampleEn: "The house is big.", exampleKm: "ផ្ទះធំ។"),
        word(9, "회의", "hoeui", hanja: "會議", .noun, .level3, "work",
             en: "meeting", km: "កិច្ចប្រជុំ",
             exampleKo: "오후에 회의가 있어요.", exampleEn: "There is a meeting in the afternoon.", exampleKm: "មានកិច្ចប្រជុំនៅពេលរសៀល។"),
        word(10, "경험", "gyeongheom", hanja: "經驗", .noun, .level3, "abstract",
             en: "experience", km: "បទពិសោធន៍",
             exampleKo: "좋은 경험이었어요.", exampleEn: "It was a good experience.", exampleKm: "វាជាបទពិសោធន៍ល្អ។"),
    ]

    public static let grammar: [GrammarPattern] = [
        GrammarPattern(
            id: GrammarID("grammar.sample.0001"),
            pattern: "-아/어요",
            level: .level1,
            category: "sentence ending",
            explanation: Gloss(
                english: "Polite informal sentence ending used in everyday speech.",
                khmer: "ចុងប្រយោគគួរសមក្រៅផ្លូវការ ប្រើក្នុងការនិយាយប្រចាំថ្ងៃ។"
            ),
            formation: Gloss(
                english: "Verb stem + 아요 after ㅏ/ㅗ, otherwise + 어요. 하다 becomes 해요.",
                khmer: "ឫសកិរិយាស័ព្ទ + 아요 បន្ទាប់ពី ㅏ/ㅗ បើមិនដូច្នេះ + 어요។ 하다 ក្លាយជា 해요។"
            ),
            examples: [
                ExampleSentence(korean: "먹다 → 먹어요", translation: Gloss(english: "to eat → eat", khmer: "ញ៉ាំ")),
                ExampleSentence(korean: "가다 → 가요", translation: Gloss(english: "to go → go", khmer: "ទៅ")),
            ],
            source: source,
            contentVersion: version
        ),
        GrammarPattern(
            id: GrammarID("grammar.sample.0002"),
            pattern: "-(으)ㄹ 거예요",
            level: .level2,
            category: "tense",
            explanation: Gloss(
                english: "Expresses a future plan or intention, or a guess about the future.",
                khmer: "បង្ហាញពីផែនការ ឬបំណងនាពេលអនាគត ឬការស្មាន។"
            ),
            formation: Gloss(
                english: "Verb stem + ㄹ 거예요 after a vowel, + 을 거예요 after a consonant.",
                khmer: "ឫសកិរិយាស័ព្ទ + ㄹ 거예요 បន្ទាប់ពីស្រៈ + 을 거예요 បន្ទាប់ពីព្យញ្ជនៈ។"
            ),
            examples: [
                ExampleSentence(
                    korean: "내일 학교에 갈 거예요.",
                    translation: Gloss(english: "I will go to school tomorrow.", khmer: "ថ្ងៃស្អែកខ្ញុំនឹងទៅសាលារៀន។")
                ),
            ],
            relatedPatternIDs: [GrammarID("grammar.sample.0001")],
            source: source,
            contentVersion: version
        ),
    ]

    private static func meaningQuestion(_ number: Int, word: Int, prompt: String, options: [String], correct: Int, en: String, km: String) -> Question {
        Question(
            id: QuestionID(String(format: "question.sample.%04d", number)),
            kind: .vocabularyMeaning,
            level: .level1,
            prompt: prompt,
            options: options.enumerated().map { QuestionOption(id: OptionID("o\($0.offset + 1)"), text: $0.element) },
            correctOptionID: OptionID("o\(correct)"),
            explanation: Gloss(english: en, khmer: km),
            relatedVocabularyID: VocabularyID(String(format: "vocab.sample.%04d", word)),
            source: source,
            contentVersion: version
        )
    }

    public static let questions: [Question] = [
        meaningQuestion(1, word: 1, prompt: "'학교'의 의미는 무엇입니까?",
                        options: ["school / សាលារៀន", "friend / មិត្តភក្តិ", "water / ទឹក", "book / សៀវភៅ"], correct: 1,
                        en: "학교 means school.", km: "학교 មានន័យថា សាលារៀន។"),
        meaningQuestion(2, word: 2, prompt: "'친구'의 의미는 무엇입니까?",
                        options: ["teacher / គ្រូ", "friend / មិត្តភក្តិ", "house / ផ្ទះ", "rice / បាយ"], correct: 2,
                        en: "친구 means friend.", km: "친구 មានន័យថា មិត្តភក្តិ។"),
        meaningQuestion(3, word: 3, prompt: "'물'의 의미는 무엇입니까?",
                        options: ["fire / ភ្លើង", "book / សៀវភៅ", "water / ទឹក", "school / សាលារៀន"], correct: 3,
                        en: "물 means water.", km: "물 មានន័យថា ទឹក។"),
        meaningQuestion(4, word: 4, prompt: "'책'의 의미는 무엇입니까?",
                        options: ["desk / តុ", "pen / ប៊ិច", "friend / មិត្តភក្តិ", "book / សៀវភៅ"], correct: 4,
                        en: "책 means book.", km: "책 មានន័យថា សៀវភៅ។"),
        Question(
            id: QuestionID("question.sample.0005"),
            kind: .meaningToWord,
            level: .level1,
            prompt: "Which word means 'teacher' (គ្រូ)?",
            options: [
                QuestionOption(id: OptionID("o1"), text: "선생님"),
                QuestionOption(id: OptionID("o2"), text: "친구"),
                QuestionOption(id: OptionID("o3"), text: "학교"),
                QuestionOption(id: OptionID("o4"), text: "물"),
            ],
            correctOptionID: OptionID("o1"),
            explanation: Gloss(english: "선생님 means teacher.", khmer: "선생님 មានន័យថា គ្រូ។"),
            relatedVocabularyID: VocabularyID("vocab.sample.0005"),
            source: source,
            contentVersion: version
        ),
        Question(
            id: QuestionID("question.sample.0006"),
            kind: .grammarFillIn,
            level: .level2,
            prompt: "내일 학교에 ______.",
            options: [
                QuestionOption(id: OptionID("o1"), text: "갈 거예요"),
                QuestionOption(id: OptionID("o2"), text: "갔어요"),
                QuestionOption(id: OptionID("o3"), text: "가세요"),
                QuestionOption(id: OptionID("o4"), text: "가고 있어요"),
            ],
            correctOptionID: OptionID("o1"),
            explanation: Gloss(
                english: "내일 (tomorrow) calls for the future form -(으)ㄹ 거예요. 갔어요 is past tense.",
                khmer: "내일 (ថ្ងៃស្អែក) ត្រូវការទម្រង់អនាគត -(으)ㄹ 거예요។ 갔어요 ជាអតីតកាល។"
            ),
            relatedGrammarID: GrammarID("grammar.sample.0002"),
            source: source,
            contentVersion: version
        ),
        Question(
            id: QuestionID("question.sample.0007"),
            kind: .sentenceCompletion,
            level: .level1,
            prompt: "집이 아주 ______.",
            options: [
                QuestionOption(id: OptionID("o1"), text: "커요"),
                QuestionOption(id: OptionID("o2"), text: "먹어요"),
                QuestionOption(id: OptionID("o3"), text: "가요"),
                QuestionOption(id: OptionID("o4"), text: "읽어요"),
            ],
            correctOptionID: OptionID("o1"),
            explanation: Gloss(
                english: "크다 (to be big) describes the house; the other options are actions.",
                khmer: "크다 (ធំ) ពណ៌នាអំពីផ្ទះ ជម្រើសផ្សេងទៀតជាសកម្មភាព។"
            ),
            relatedVocabularyID: VocabularyID("vocab.sample.0008"),
            relatedGrammarID: GrammarID("grammar.sample.0001"),
            source: source,
            contentVersion: version
        ),
    ]
}
