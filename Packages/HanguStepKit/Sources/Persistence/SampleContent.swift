import Domain
import Foundation

/// Tiny development dataset. Real content arrives through the JSON importer in Phase 7.
public enum SampleContent {
    public static let source = ContentSource(
        origin: .curated,
        name: "HanguStep sample content",
        license: "CC BY 4.0"
    )

    public static let vocabulary: [VocabularyItem] = [
        VocabularyItem(
            id: VocabularyID("vocab.sample.0001"),
            hangul: "학교",
            romanization: "hakgyo",
            hanja: "學校",
            partOfSpeech: .noun,
            level: .level1,
            category: "school",
            meaning: Gloss(english: "school", khmer: "សាលារៀន"),
            examples: [
                ExampleSentence(
                    korean: "저는 학교에 가요.",
                    translation: Gloss(english: "I go to school.", khmer: "ខ្ញុំទៅសាលារៀន។")
                ),
            ],
            source: source,
            contentVersion: 1
        ),
        VocabularyItem(
            id: VocabularyID("vocab.sample.0002"),
            hangul: "친구",
            romanization: "chingu",
            hanja: "親舊",
            partOfSpeech: .noun,
            level: .level1,
            category: "people",
            meaning: Gloss(english: "friend", khmer: "មិត្តភក្តិ"),
            examples: [
                ExampleSentence(
                    korean: "친구를 만나요.",
                    translation: Gloss(english: "I meet a friend.", khmer: "ខ្ញុំជួបមិត្តភក្តិ។")
                ),
            ],
            source: source,
            contentVersion: 1
        ),
        VocabularyItem(
            id: VocabularyID("vocab.sample.0003"),
            hangul: "물",
            romanization: "mul",
            partOfSpeech: .noun,
            level: .level1,
            category: "food",
            meaning: Gloss(english: "water", khmer: "ទឹក"),
            examples: [
                ExampleSentence(
                    korean: "물을 마셔요.",
                    translation: Gloss(english: "I drink water.", khmer: "ខ្ញុំផឹកទឹក។")
                ),
            ],
            source: source,
            contentVersion: 1
        ),
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
            ],
            source: source,
            contentVersion: 1
        ),
    ]

    public static let questions: [Question] = [
        Question(
            id: QuestionID("question.sample.0001"),
            kind: .vocabularyMeaning,
            level: .level1,
            prompt: "'학교'의 의미는 무엇입니까?",
            options: [
                QuestionOption(id: OptionID("a"), text: "school / សាលារៀន"),
                QuestionOption(id: OptionID("b"), text: "friend / មិត្តភក្តិ"),
                QuestionOption(id: OptionID("c"), text: "water / ទឹក"),
                QuestionOption(id: OptionID("d"), text: "book / សៀវភៅ"),
            ],
            correctOptionID: OptionID("a"),
            explanation: Gloss(english: "학교 means school.", khmer: "학교 មានន័យថា សាលារៀន។"),
            relatedVocabularyID: VocabularyID("vocab.sample.0001"),
            source: source,
            contentVersion: 1
        ),
    ]
}
